---
title: 'cert-manager OKE: Wildcard TLS via OCI DNS and DNS-01'
author: Victor Silva
date: 2026-04-21T11:34:18+00:00
layout: post
permalink: /cert-manager-oke-oci-dns/
excerpt: "HTTP-01 can't validate wildcards or reach private OKE clusters. This guide configures cert-manager with the OCI DNS webhook solver and DNS-01 on OKE."
categories:
  - OCI
  - DevOps
tags:
  - cert-manager
  - OKE
  - OCI DNS
  - dns-01
  - Kubernetes
---

If you're running workloads on Oracle Kubernetes Engine and need a wildcard certificate — `*.example.com` — the standard HTTP-01 challenge is a dead end. Let's Encrypt can't validate a wildcard by hitting an HTTP endpoint. And if your OKE cluster is private, HTTP-01 doesn't even get off the ground: there's no publicly reachable ingress for Let's Encrypt to call back to.

The solution is the DNS-01 challenge, and on OCI that means plugging cert-manager into OCI DNS via a webhook solver. cert-manager is a CNCF graduated project — it reached graduation status in November 2024, which means the production-readiness question is answered. The architecture is solid, the API is stable, and it's running in production clusters at scale.

By the end of this post you will have cert-manager v1.20.2 installed on OKE, an OCI DNS webhook solver configured, IAM policies in place using either Instance Principal (basic and enhanced clusters) or Workload Identity (enhanced clusters, zero-credential), a `ClusterIssuer` pointed at Let's Encrypt, and an automatically issued and renewed wildcard certificate stored as a Kubernetes Secret. If you are new to cert-manager and want to understand the fundamentals first, start with the [HTTP-01 walkthrough](/cert-manager-tls-kubernetes/) before continuing here.

## Understanding DNS-01 vs HTTP-01

The HTTP-01 challenge works by having cert-manager deploy a temporary pod that serves a token at `http://<your-domain>/.well-known/acme-challenge/<token>`. Let's Encrypt fetches that URL over port 80 and, if the response is correct, considers ownership proven. This works well for single hostnames when your cluster is publicly reachable — but it has two hard blockers.

First, Let's Encrypt cannot use HTTP-01 to validate wildcard certificates. A wildcard like `*.example.com` requires proving ownership of the parent zone, not a specific hostname, and HTTP-01 has no mechanism for that. Second, if your OKE cluster is private — behind a load balancer with no public IP, or in a subnet with no internet ingress — there is no HTTP endpoint reachable from the Let's Encrypt validation network.

DNS-01 sidesteps both constraints. Instead of serving a file, cert-manager adds a `_acme-challenge.example.com` TXT record to your DNS zone with a value that Let's Encrypt checks via a public DNS query. The validator never talks to your cluster at all — it only needs to resolve a DNS name. This works for wildcards, works for private clusters, and works regardless of network topology.

The way cert-manager implements DNS-01 for providers without a built-in solver is through a webhook protocol. cert-manager registers an external process as a Kubernetes `APIService`. When a DNS-01 challenge needs to be solved, cert-manager calls two methods on the webhook: `Present()` to add the TXT record, and `CleanUp()` to remove it after validation completes. The webhook process translates those calls into OCI DNS API operations.

## cert-manager Architecture Recap

Before installing anything it helps to have the full resource chain in mind, because this is what you will be staring at when debugging.

cert-manager adds five custom resources. A **ClusterIssuer** defines how to request certificates and is cluster-scoped — this is what you will use for a shared Let's Encrypt configuration. A **Certificate** is a declaration that you want a specific certificate: which domains it covers, where to store it, and which issuer to use. A **CertificateRequest** is the intermediate object cert-manager creates automatically when it acts on a `Certificate` — you don't create these, but they are essential for debugging. An **Order** represents an ACME order with Let's Encrypt. A **Challenge** represents a single domain validation challenge within that order.

The issuance flow from your perspective looks like this:

{% highlight plaintext %}
You apply a Certificate resource
        |
   cert-manager Certificate controller
   creates a CertificateRequest
        |
   ACME issuer creates an Order with Let's Encrypt
        |
   Let's Encrypt returns a DNS-01 Challenge
        |
   cert-manager calls webhook Present()
        |
   webhook adds _acme-challenge TXT record in OCI DNS
        |
   Let's Encrypt resolves the TXT record and validates
        |
   Certificate issued, stored in the named Kubernetes Secret
        |
   webhook CleanUp() removes the TXT record
        |
   cert-manager schedules renewal at 2/3 of lifetime
{% endhighlight %}

The webhook is registered as a Kubernetes `APIService` — this means the Kubernetes API server routes calls to it, and if the webhook pod is not healthy, challenge presentation will fail. The `groupName` you configure at install time is the key that Kubernetes uses to route those calls to the right webhook. If the `groupName` in your `ClusterIssuer` doesn't match the one the webhook was installed with, cert-manager silently can't route the challenge — the Order sits in a pending state forever with no useful error message. We'll come back to this.

## Prerequisites

Before starting, make sure you have:

- An OKE cluster (basic or enhanced) running Kubernetes 1.30 or higher
- `kubectl` configured and pointing at the cluster with cluster-admin access
- Helm 3.x installed
- OCI CLI installed and configured (`oci setup config`)
- A domain managed in OCI DNS as a **GLOBAL** scope public zone — private zones are not reachable from the Let's Encrypt validation network, so DNS-01 will never succeed with them
- Terraform (optional, but used for the IAM configuration in this post)

Verify the basics:

{% highlight bash %}
kubectl version --short
helm version --short
oci dns zone list --compartment-id $COMPARTMENT_ID --scope GLOBAL
{% endhighlight %}

The last command confirms OCI CLI access and that your domain zone exists with GLOBAL scope.

## Installing cert-manager v1.20.2

Add the Jetstack Helm repository and update:

{% highlight bash %}
helm repo add jetstack https://charts.jetstack.io
helm repo update
{% endhighlight %}

Install cert-manager with two important flags beyond the defaults:

{% highlight bash %}
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.20.2 \
  --set crds.enabled=true \
  --set extraArgs='{--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53,--dns01-recursive-nameservers-only}'
{% endhighlight %}

Two things in this command need explaining.

`crds.enabled=true` is the current way to install cert-manager's custom resource definitions as part of the Helm release. The older `installCRDs=true` flag was deprecated in v1.15 and removed in later releases — if you copy a command from older documentation and use `installCRDs=true`, Helm installs cert-manager without the CRDs, and every custom resource you create will fail with an unknown resource error.

`--dns01-recursive-nameservers-only` is critical for OCI DNS. When cert-manager checks whether a `_acme-challenge` TXT record has propagated before signaling readiness, it by default uses whatever DNS resolver is available — which on a Kubernetes cluster means CoreDNS. CoreDNS may not see changes to your OCI DNS GLOBAL zone immediately, because it may have cached a negative response or may not be configured to reach OCI's authoritative nameservers directly. This flag forces cert-manager to use the specified public resolvers (8.8.8.8 and 1.1.1.1) for its self-check, bypassing CoreDNS entirely.

Wait for all cert-manager pods to reach `Running`:

{% highlight bash %}
kubectl rollout status deployment/cert-manager -n cert-manager
kubectl rollout status deployment/cert-manager-webhook -n cert-manager
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager
{% endhighlight %}

## Installing the OCI DNS Webhook

The webhook we'll use is `streamnsight/cert-manager-webhook-oci`. It's the most complete implementation available — it supports API key authentication, Instance Principal, and Workload Identity, and it correctly handles the two-challenge scenario that occurs when you request both a bare domain and its wildcard in the same certificate.

The image is published at `ghcr.io/giovannicandido/cert-manager-webhook-oci`. Install from the repository's `deploy/` directory so you get the full Helm chart:

{% highlight bash %}
git clone https://github.com/streamnsight/cert-manager-webhook-oci
cd cert-manager-webhook-oci

helm upgrade --install cert-manager-webhook-oci \
  --namespace cert-manager \
  --set groupName=acme.example.com \
  --set image.repository=ghcr.io/giovannicandido/cert-manager-webhook-oci \
  --set image.tag=build-pipeline \
  deploy/cert-manager-webhook-oci
{% endhighlight %}

Replace `acme.example.com` with your own group name — this just needs to be a unique DNS-like identifier for your webhook registration. The requirement is that **it must be identical in this Helm install command and in the `ClusterIssuer` you create later**. If they differ even by a single character, cert-manager registers the ClusterIssuer, creates Challenges, but cannot route them to the webhook. The Challenge stays in a `pending` state with no error in the cert-manager logs that points directly at the mismatch. This is the most common failure mode in this entire setup.

Confirm the webhook pod is running and the APIService is registered:

{% highlight bash %}
kubectl get pods -n cert-manager
kubectl get apiservice | grep acme
{% endhighlight %}

The APIService output should show something like `v1alpha1.acme.example.com` with `AVAILABLE: True`.

## OCI IAM: Dynamic Group and Policy

cert-manager's webhook needs permission to call the OCI DNS API — specifically, to create and delete TXT records in your zone. There are two ways to grant this depending on your cluster type.

### Option A: Instance Principal

Instance Principal works on both basic and enhanced OKE clusters. The OKE node instances are granted an IAM identity based on their compartment membership, and that identity is allowed to manage DNS records. The webhook inherits this permission because it runs on those nodes.

The security tradeoff is worth naming explicitly: with Instance Principal, every pod running on the same node has the same node-level OCI permissions. If you run mixed workloads on the cert-manager nodes, all of them inherit the DNS management permission. For this reason, consider running cert-manager on a dedicated node pool with a taint that prevents other workloads from scheduling there.

{% highlight terraform %}
variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy root"
  type        = string
}

variable "oke_node_pool_compartment_ocid" {
  description = "OCID of the compartment containing OKE node pool instances"
  type        = string
}

variable "dns_compartment_ocid" {
  description = "OCID of the compartment containing the OCI DNS zone"
  type        = string
}

resource "oci_identity_dynamic_group" "oke_cert_manager_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "oke-cert-manager-nodes"
  description    = "OKE nodes that run cert-manager-webhook-oci"
  matching_rule  = "ANY {instance.compartment.id = '${var.oke_node_pool_compartment_ocid}'}"
}

resource "oci_identity_policy" "cert_manager_dns" {
  compartment_id = var.dns_compartment_ocid
  name           = "cert-manager-oci-dns-solver"
  description    = "ACME DNS-01 permissions for cert-manager-webhook-oci"

  statements = [
    "Allow dynamic-group oke-cert-manager-nodes to use dns-zones in compartment id ${var.dns_compartment_ocid}",
    "Allow dynamic-group oke-cert-manager-nodes to manage dns-records in compartment id ${var.dns_compartment_ocid}",
  ]

  depends_on = [oci_identity_dynamic_group.oke_cert_manager_nodes]
}
{% endhighlight %}

Two gotchas in this configuration that trip up almost everyone working with OCI IAM in Terraform.

The `compartment_id` on `oci_identity_dynamic_group` must be `var.tenancy_ocid` — the tenancy root, not a child compartment. Dynamic Groups are a tenancy-level resource. If you use a compartment OCID here, the OCI provider returns an error and your `terraform apply` fails. This is covered in detail in the [OCI IAM Terraform post](/oci-iam-terraform/).

The policy statements use `compartment id <ocid>` not `compartment <name>`. Compartment names are not stable — they can be renamed — and when a policy references a name that changes, it silently stops matching. Always use OCIDs in IAM policy statements. See the [OCI IAM Terraform post](/oci-iam-terraform/) for why this matters at scale.

After `terraform apply` completes, wait up to 60 seconds before testing. OCI IAM propagation is eventually consistent, and it's common to see authorization errors for a short window even after a successful apply. The `depends_on` between the dynamic group and the policy helps sequence the Terraform operations, but it doesn't speed up IAM propagation on the OCI side.

### Option B: Workload Identity (Enhanced Clusters)

Workload Identity is the most secure option and is available on OKE Enhanced clusters. Instead of granting permission to all pods on a node, you grant permission to a specific Kubernetes service account in a specific namespace on a specific cluster. No dynamic group is needed.

{% highlight terraform %}
variable "oke_cluster_ocid" {
  description = "OCID of the OKE Enhanced cluster"
  type        = string
}

resource "oci_identity_policy" "cert_manager_workload_identity" {
  compartment_id = var.dns_compartment_ocid
  name           = "cert-manager-workload-identity-dns"
  description    = "OKE workload identity policy for cert-manager-webhook-oci"

  statements = [
    "Allow any-user to use dns-zones in compartment id ${var.dns_compartment_ocid} where all {request.principal.type='workload', request.principal.namespace='cert-manager', request.principal.service_account='cert-manager-webhook-oci', request.principal.cluster_id='${var.oke_cluster_ocid}'}",
    "Allow any-user to manage dns-records in compartment id ${var.dns_compartment_ocid} where all {request.principal.type='workload', request.principal.namespace='cert-manager', request.principal.service_account='cert-manager-webhook-oci', request.principal.cluster_id='${var.oke_cluster_ocid}'}",
  ]
}
{% endhighlight %}

The `where all {...}` conditions are what make this zero-credential. OCI verifies that the call originates from the `cert-manager-webhook-oci` service account in the `cert-manager` namespace on that specific cluster — any other workload in the cluster cannot use this policy, even if it somehow obtained the same service account token.

When using Workload Identity, the Helm install for the webhook needs two additional flags:

{% highlight bash %}
helm upgrade --install cert-manager-webhook-oci \
  --namespace cert-manager \
  --set groupName=acme.example.com \
  --set image.repository=ghcr.io/giovannicandido/cert-manager-webhook-oci \
  --set image.tag=build-pipeline \
  --set useWorkloadIdentity=true \
  --set region=eu-frankfurt-1 \
  deploy/cert-manager-webhook-oci
{% endhighlight %}

Replace `eu-frankfurt-1` with your OKE cluster's home region.

Workload Identity aligns with CIS OCI Benchmark control 1.14, which recommends scoping cloud credentials to the minimum required principal. If your cluster type supports it, prefer this over Instance Principal.

## ClusterIssuer Configuration

Always start with the Let's Encrypt staging issuer. The staging environment issues certificates that browsers don't trust, but it has no rate limits. The production API enforces 50 certificates per registered domain per week and 5 failed validations per hostname per hour. Exhausting these limits while debugging solver configuration is a real risk.

### Staging ClusterIssuer

{% highlight yaml %}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: you@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.example.com   # must match Helm --set groupName exactly
            solverName: oci
            config:
              compartmentOCID: ocid1.compartment.oc1..aaaaaa...
{% endhighlight %}

The `groupName` here must be exactly what you passed to `--set groupName` when installing the webhook. Copy-paste it — don't retype. The `compartmentOCID` is the OCID of the compartment where your OCI DNS zone lives.

If you are using API key authentication instead of Instance Principal or Workload Identity, add `ociProfileSecretName` under `config`:

{% highlight yaml %}
            config:
              compartmentOCID: ocid1.compartment.oc1..aaaaaa...
              ociProfileSecretName: oci-profile
{% endhighlight %}

The `oci-profile` Secret should contain a valid OCI CLI config file. With Instance Principal or Workload Identity, omit `ociProfileSecretName` entirely and the webhook authenticates automatically using the environment.

### Production ClusterIssuer

{% highlight yaml %}
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: you@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - dns01:
          webhook:
            groupName: acme.example.com
            solverName: oci
            config:
              compartmentOCID: ocid1.compartment.oc1..aaaaaa...
{% endhighlight %}

Apply both issuers:

{% highlight bash %}
kubectl apply -f clusterissuer-staging.yaml
kubectl apply -f clusterissuer-prod.yaml

kubectl get clusterissuer
{% endhighlight %}

Both should show `READY: True`. If a ClusterIssuer shows `READY: False`, `kubectl describe clusterissuer letsencrypt-staging` will show the condition message — usually an ACME account registration failure or a connectivity issue to the staging server.

## Requesting a Wildcard Certificate

With the issuer ready, you can request a wildcard. Start with staging to validate the full DNS-01 flow before touching production rate limits.

{% highlight yaml %}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-example-com
  namespace: default
spec:
  secretName: wildcard-example-com-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - "example.com"
    - "*.example.com"
  renewBefore: 720h
{% endhighlight %}

A few things to note in this manifest.

The `dnsNames` list includes both the bare domain `example.com` and the wildcard `*.example.com`. A wildcard certificate from Let's Encrypt covers `*.example.com` but not `example.com` itself — they are treated as two separate names. If your services include both the root domain and subdomains, you need both entries.

Including both names triggers two ACME challenges. Let's Encrypt creates two `_acme-challenge.example.com` TXT records with different values — one for `example.com` validation and one for the wildcard. cert-manager creates two `Challenge` objects, and the OCI webhook calls `Present()` twice. The webhook handles this with additive patching — it adds both TXT values to the same record name rather than overwriting the first with the second. Both records coexist until `CleanUp()` is called after validation.

`renewBefore: 720h` is 30 days. For a wildcard certificate that potentially covers dozens of services, you want more lead time than the default 2/3-of-lifetime calculation — if renewal fails for any reason, you have a full month to diagnose and fix it before expiry causes an incident.

Apply the Certificate:

{% highlight bash %}
kubectl apply -f certificate-wildcard.yaml
{% endhighlight %}

## Testing and Validation

This is where you spend time if anything went wrong. The validation flow follows the resource chain — Certificate → CertificateRequest → Order → Challenge — and each level has its own status and events.

### Check the Webhook Registration

{% highlight bash %}
kubectl get pods -n cert-manager
kubectl get apiservice | grep acme
{% endhighlight %}

The webhook pod should be `Running` and the APIService should be `AVAILABLE: True`. If the APIService shows `AVAILABLE: False`, the webhook pod is likely not healthy — check its logs with `kubectl logs -n cert-manager -l app=cert-manager-webhook-oci`.

### Watch the Certificate Status

{% highlight bash %}
kubectl get certificate wildcard-example-com -n default --watch
{% endhighlight %}

The `READY` column starts `False` and should flip to `True` once Let's Encrypt has validated both TXT records. This takes one to three minutes when DNS propagation is fast. If it hasn't changed after five minutes, stop watching and inspect.

### Inspect Orders and Challenges

{% highlight bash %}
kubectl get orders -n default
kubectl describe challenge -n default
{% endhighlight %}

The `describe challenge` output is the most informative debugging surface. Look at the `Events` section at the bottom. A successful challenge flow looks like:

{% highlight plaintext %}
Events:
  Normal  Started   Created Challenge resource
  Normal  Presented Presented challenge using dns-01 challenge mechanism
  Normal  DomainVerified  Domain "example.com" verified with "dns-01" validation
{% endhighlight %}

If you see `Presented` but no `DomainVerified` after several minutes, the TXT record propagated to OCI DNS but Let's Encrypt is not seeing it through public resolvers. Verify the record directly:

{% highlight bash %}
dig TXT _acme-challenge.example.com @8.8.8.8
{% endhighlight %}

You should see one or two TXT records with token-like values. If `dig` returns nothing, the webhook didn't add the record — check the webhook pod logs for OCI API errors, and verify IAM propagation if you just applied the Terraform changes.

If Instance Principal is in use and you suspect an auth issue, verify from one of the OKE nodes directly:

{% highlight bash %}
oci iam region list --auth instance_principal
{% endhighlight %}

If that fails, the dynamic group matching rule or the IAM policy has a problem — revisit the Terraform configuration and remember the 60-second propagation window.

### Verify the Issued Certificate

Once `READY: True`, inspect what was actually issued:

{% highlight bash %}
kubectl get secret wildcard-example-com-tls -n default \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -text | grep -A4 "Subject Alternative Name"
{% endhighlight %}

This should print `DNS:example.com, DNS:*.example.com`. If you used the staging issuer, the issuer name will be something like `(STAGING) Let's Encrypt` — that's correct and expected.

Check the expiry date:

{% highlight bash %}
kubectl get secret wildcard-example-com-tls -n default \
  -o jsonpath='{.data.tls\.crt}' | base64 -d \
  | openssl x509 -noout -enddate
{% endhighlight %}

A 90-day expiry from today confirms the certificate was issued correctly. With `renewBefore: 720h`, cert-manager will initiate renewal 30 days before this date — fully automatic.

Once staging validation passes, switch the `issuerRef` in your `Certificate` manifest to `letsencrypt-prod` and re-apply. cert-manager detects the issuer change and re-issues the certificate through the production API.

## Best Practices

**Always test with staging first.** The Let's Encrypt rate limits are per-domain and per-week, and failed validations count against a separate hourly limit. Exhausting the failed-validation allowance while setting up a new solver is a common mishap that locks you out of issuing for an hour. Staging has none of these limits.

**Use Workload Identity over Instance Principal on Enhanced clusters.** The permission is scoped to a specific service account on a specific cluster — no other workload can abuse it, and there are no static credentials anywhere in the system. This aligns with CIS OCI Benchmark control 1.14 and fits naturally into a broader OCI posture that includes [OCI Security Zones](/oci-security-zones/) to enforce compartment-level guardrails. If your OKE cluster is Enhanced, there is no reason to use Instance Principal for cert-manager.

**Isolate the cert-manager node pool when using Instance Principal.** If you can't use Workload Identity, run cert-manager on a dedicated node pool and apply a taint so user workloads don't schedule there. All pods on a node share the node's Instance Principal permissions — a compromised workload pod on a cert-manager node would have DNS management access to your OCI zone.

**Use `compartment id <ocid>` not compartment name in IAM policies.** Compartment names can change; OCIDs cannot. A policy written with a name continues to match even if the resource it referred to has been renamed or replaced — this is a silent mismatch that takes time to diagnose. See the [OCI IAM Terraform post](/oci-iam-terraform/) for more context on this.

**The DNS zone must be GLOBAL scope.** Let's Encrypt validates TXT records by querying public DNS. A private OCI DNS zone is not reachable from the public internet, so the validation will never succeed. If `oci dns zone list --scope GLOBAL` doesn't show your zone, you're using a private zone and the DNS-01 flow will fail at the Let's Encrypt validation step every time.

**TXT record cleanup after validation is expected.** After Let's Encrypt validates the challenge, cert-manager calls the webhook's `CleanUp()` method, which removes the `_acme-challenge` TXT record from OCI DNS. If you're watching your DNS zone in the console and see a record appear and then disappear, that's the normal flow — not an accidental deletion.

**Store OCI API credentials in OCI Vault if using API key mode.** If your cluster doesn't support Workload Identity and you're using API key authentication, the OCI config file ends up in a Kubernetes Secret in the `cert-manager` namespace. Apply restrictive Kubernetes RBAC so other namespaces can't read it, and consider managing the credential lifecycle through [OCI Vault](/oci-vault-secrets-management-terraform/) rather than manual rotation.

## Conclusion

Wildcard TLS on OKE is now fully automated. cert-manager handles the full certificate lifecycle — initial issuance, renewal 30 days before expiry, and updating the Kubernetes Secret in place — and the OCI DNS webhook handles the DNS-01 challenge without requiring any network path from Let's Encrypt to your cluster. With Instance Principal or Workload Identity, there are no static credentials in the system at all.

cert-manager graduated from CNCF in November 2024. If you were holding off on it for production because of maturity concerns, that question is settled.

From here, the natural next steps are attaching the issued wildcard Secret to an OKE Ingress using the `tls.secretName` field, or exploring cert-manager's `CertificateRequestPolicy` and rotation webhooks for zero-downtime certificate renewals in sensitive workloads. Both build directly on the `ClusterIssuer` and `Certificate` resources you've just set up. For broader cluster observability, pairing cert-manager with [Kubernetes audit logging for kube-apiserver events](/kubernetes-audit-logging/) gives you a full record of every certificate resource change — useful when debugging renewal failures in production.

Happy scripting!
