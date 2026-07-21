---
title: "cert-manager: automating TLS certificates in Kubernetes"
author: Victor Silva
date: 2025-10-13T20:52:21+00:00
layout: post
permalink: /cert-manager-tls-kubernetes/
excerpt: "Manual TLS certificate rotation is the kind of operational work that feels manageable until it isn't — then it causes a 2 AM outage. cert-manager automates the full lifecycle of certificates inside Kubernetes, from issuance through renewal, with nothing more than a YAML manifest and an annotation on your Ingress."
categories:
  - Kubernetes
tags:
  - cert-manager
  - kubernetes
  - tls
  - cncf
  - lets-encrypt
---

Manual TLS certificate management is the kind of operational work that scales badly. You get a certificate, you put it in a Secret, you update your Ingress, and everything works. Then ninety days later it expires. Or your team rotates to a new domain. Or you add a new service behind an Ingress and forget to provision a certificate for it at all. The failure mode is always the same: a browser shows a certificate warning, a client library throws a TLS error, and someone is scrambling at an inconvenient hour.

The root cause is that certificates in Kubernetes are still mostly a manual process for teams that have not automated it. cert-manager fixes this. It is a CNCF incubating project that runs as a controller inside your cluster, watches for `Certificate` resources and Ingress annotations, requests certificates from issuers you configure, and handles renewals automatically before expiry. Once it is set up, the only thing you need to do to get a valid TLS certificate for a new service is add two lines to your Ingress.

This post walks through installing cert-manager via Helm, creating a `ClusterIssuer` for Let's Encrypt, declaring a `Certificate` resource, annotating an Ingress to trigger automatic provisioning, and verifying that the full chain worked.

## How cert-manager Works

Before touching a cluster it is worth understanding the resource model cert-manager introduces and how the issuance flow works.

cert-manager adds four main custom resources to your cluster. An **Issuer** or **ClusterIssuer** defines how to request certificates: which CA to use, which ACME server to hit, which DNS or HTTP challenge solver to use for domain validation. An `Issuer` is namespace-scoped; a `ClusterIssuer` is cluster-wide and is what you want in almost every real setup. A **Certificate** declares that you want a certificate — you specify the domain names, the Secret name where the resulting cert should land, and which issuer to use. cert-manager watches for `Certificate` resources and drives the issuance process. A **CertificateRequest** is the intermediate object cert-manager creates when it talks to an issuer on behalf of a `Certificate` — you rarely interact with it directly, but it is useful for debugging. An **Order** and **Challenge** are created during the ACME flow when Let's Encrypt or another ACME issuer needs to verify domain ownership.

The end-to-end flow for a Let's Encrypt certificate looks like this:

```
You apply a Certificate resource (or annotate an Ingress)
        |
   cert-manager Certificate controller
   creates a CertificateRequest
        |
   ACME issuer creates an Order
        |
   Let's Encrypt returns an HTTP-01 or DNS-01 Challenge
        |
   cert-manager solves the Challenge
   (creates a temporary Ingress or updates DNS)
        |
   Let's Encrypt validates domain ownership
        |
   Certificate issued, stored in the named Secret
        |
   cert-manager schedules renewal at 2/3 of lifetime
```

The default certificate lifetime with Let's Encrypt is 90 days. cert-manager begins the renewal process when roughly 30 days remain, which means in normal operation you will never see a certificate expire.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.25 or higher
- `kubectl` configured with cluster-admin privileges
- Helm 3 installed
- An Ingress controller already deployed (nginx-ingress is used in this post's examples)
- A domain you control, with DNS pointing to your cluster's load balancer (required for Let's Encrypt HTTP-01 validation)

Verify your cluster and Helm are ready:

{% highlight bash %}
kubectl version --short
helm version --short
kubectl get pods -n ingress-nginx
{% endhighlight %}

The Ingress controller pods should be in `Running` state before you proceed. cert-manager uses your Ingress controller to serve the HTTP-01 challenge response that Let's Encrypt requests during domain validation.

## Installing cert-manager

The recommended installation path is the official Helm chart. Add the Jetstack repository and update:

{% highlight bash %}
helm repo add jetstack https://charts.jetstack.io
helm repo update
{% endhighlight %}

Install cert-manager into its own namespace. The `installCRDs=true` flag creates all the custom resource definitions as part of the Helm release, which is the right approach for clusters you manage with Helm:

{% highlight bash %}
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.0 \
  --set installCRDs=true
{% endhighlight %}

Wait for all three cert-manager components to reach `Running` state:

{% highlight bash %}
kubectl rollout status deployment/cert-manager -n cert-manager
kubectl rollout status deployment/cert-manager-webhook -n cert-manager
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager
{% endhighlight %}

The **controller** manages the core certificate lifecycle. The **webhook** validates and defaults cert-manager custom resources at admission time. The **cainjector** injects CA bundles into webhook configurations and API service definitions — it is what keeps the webhook TLS wiring working as certificates rotate.

Confirm all pods are healthy:

{% highlight bash %}
kubectl get pods -n cert-manager
{% endhighlight %}

## Creating a ClusterIssuer for Let's Encrypt

cert-manager ships with built-in support for ACME issuers, which is how Let's Encrypt works. You will create two `ClusterIssuer` resources: one pointing at the Let's Encrypt staging environment for testing, and one pointing at production. This distinction matters because Let's Encrypt's production API has strict rate limits — you can exhaust your weekly certificate quota quickly if you test against it directly.

### Staging Issuer

Create a file called `clusterissuer-staging.yaml`:

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
      - http01:
          ingress:
            class: nginx
{% endhighlight %}

The `email` field is used by Let's Encrypt to send expiry warnings to you if automated renewal ever fails — use a real address here. The `privateKeySecretRef` is where cert-manager stores your ACME account private key; it will be created automatically on first use.

The `solvers` block tells cert-manager how to prove you control the domain. The `http01` solver with `ingress.class: nginx` instructs cert-manager to create a temporary Ingress resource that serves the ACME challenge token at `http://<your-domain>/.well-known/acme-challenge/<token>`. Let's Encrypt fetches that URL over port 80 and, if it matches, considers domain ownership proven.

### Production Issuer

Create `clusterissuer-prod.yaml`:

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
      - http01:
          ingress:
            class: nginx
{% endhighlight %}

The only differences are the ACME server URL and the private key Secret name. Apply both:

{% highlight bash %}
kubectl apply -f clusterissuer-staging.yaml
kubectl apply -f clusterissuer-prod.yaml
{% endhighlight %}

Verify that both issuers registered their ACME accounts successfully:

{% highlight bash %}
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
{% endhighlight %}

Look for a `Ready` condition with `status: "True"` in the output of `describe`. If the condition is `False`, the `message` field tells you what failed — usually an invalid email address, a network connectivity issue to the ACME server, or an incorrect solver configuration.

## Creating a Certificate Resource

Now that you have issuers in place, you can request a certificate explicitly with a `Certificate` resource. Create `certificate-example.yaml`:

{% highlight yaml %}
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
{% endhighlight %}

The `secretName` field is where cert-manager will store the issued certificate. It creates a Kubernetes `Secret` of type `kubernetes.io/tls` with two keys: `tls.crt` (the certificate chain) and `tls.key` (the private key). This is the standard format that Ingress controllers and most other Kubernetes components expect.

The `issuerRef` points at the `letsencrypt-staging` issuer — we are testing first. The `dnsNames` list is the set of Subject Alternative Names (SANs) the certificate will cover. You can list multiple domains here if your service is reachable under more than one hostname.

Apply it:

{% highlight bash %}
kubectl apply -f certificate-example.yaml
{% endhighlight %}

Watch the certificate status as cert-manager works through the issuance flow:

{% highlight bash %}
kubectl get certificate example-tls -n default --watch
{% endhighlight %}

The `READY` column starts as `False`. cert-manager is creating the `CertificateRequest`, generating an `Order` with Let's Encrypt, and deploying the HTTP-01 challenge solver. When the challenge is validated and the certificate is issued, `READY` flips to `True`. This typically takes 30 to 90 seconds.

## Annotating an Ingress for Automatic Provisioning

The `Certificate` resource approach is explicit and gives you full control. But in most cases you want even less ceremony than that: you just want to annotate an Ingress and have cert-manager do everything automatically. This is the most common pattern in practice.

Here is a complete Ingress manifest that provisions a production-grade TLS certificate automatically:

{% highlight yaml %}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: example-prod-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: example-service
                port:
                  number: 80
{% endhighlight %}

The `cert-manager.io/cluster-issuer` annotation is the trigger. When cert-manager's Ingress shim detects this annotation, it automatically creates a `Certificate` resource targeting the named `ClusterIssuer`, using the `tls` block to determine the domain names and Secret name. You never need to write the `Certificate` resource manually.

The `tls.secretName` field tells cert-manager where to store the issued certificate. The Ingress controller reads from that same Secret to terminate TLS connections.

Apply the Ingress:

{% highlight bash %}
kubectl apply -f example-ingress.yaml
{% endhighlight %}

cert-manager will detect the annotation and start the certificate issuance process immediately. You can watch the generated `Certificate` resource:

{% highlight bash %}
kubectl get certificate -n default
kubectl describe certificate example-prod-tls -n default
{% endhighlight %}

## Testing and Validation

Once the `READY` status on the certificate is `True`, validate the full chain from the issuer through to the Secret.

Inspect the issued certificate stored in the Secret:

{% highlight bash %}
kubectl get secret example-prod-tls -n default -o jsonpath='{.data.tls\.crt}' \
  | base64 -d \
  | openssl x509 -noout -text \
  | grep -A2 "Subject Alternative Name"
{% endhighlight %}

This should print your domain name under the SAN extension, confirming the certificate covers the right hostname.

Check the certificate expiry date:

{% highlight bash %}
kubectl get secret example-prod-tls -n default -o jsonpath='{.data.tls\.crt}' \
  | base64 -d \
  | openssl x509 -noout -enddate
{% endhighlight %}

For a Let's Encrypt certificate you should see an expiry 90 days out from issuance.

Check the `Certificate` resource status conditions directly:

{% highlight bash %}
kubectl get certificate example-prod-tls -n default -o yaml
{% endhighlight %}

Look for a condition with `type: Ready` and `status: "True"`. The `message` field explains the current state — it will tell you if renewal is in progress, if the certificate was recently renewed, or if there was an issuance error.

To check the full event history for an issuance that went wrong, describe the certificate and look at the Events section at the bottom:

{% highlight bash %}
kubectl describe certificate example-prod-tls -n default
{% endhighlight %}

cert-manager emits detailed events at each stage of the issuance flow. If a challenge failed, you will see an event pointing at the `Challenge` resource name. You can then describe the challenge directly to see the exact error from the ACME server:

{% highlight bash %}
kubectl get challenge -n default
kubectl describe challenge <challenge-name> -n default
{% endhighlight %}

The most common challenge failures are: the cluster load balancer is not reachable from the internet on port 80, the temporary challenge Ingress has the wrong `ingressClassName`, or the domain DNS does not yet point to your cluster.

## Renewal Behavior

cert-manager automatically renews certificates before they expire. By default it begins the renewal process when 2/3 of the certificate's lifetime has elapsed. For a 90-day Let's Encrypt certificate, renewal starts at roughly day 60. You can customize this with the `renewBefore` field on a `Certificate` resource:

{% highlight yaml %}
spec:
  secretName: example-prod-tls
  renewBefore: 720h   # renew 30 days before expiry
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - app.example.com
{% endhighlight %}

Renewal is fully automatic — cert-manager goes through the same issuance flow, updates the Secret in place, and your Ingress controller picks up the new certificate without a restart. You do not need to do anything.

## Best Practices

**Always test with the staging issuer first.** The Let's Encrypt staging environment issues certificates that are not trusted by browsers, but it has no rate limits. Use `letsencrypt-staging` until you have confirmed the full flow works — challenge solver reachable, certificate issued, Secret created, Ingress serving TLS — then switch the annotation or `issuerRef` to `letsencrypt-prod`.

**Use a `ClusterIssuer` rather than an `Issuer` for shared infrastructure.** An `Issuer` is namespace-scoped, which means teams in different namespaces cannot use it. For any issuer that represents a shared CA or external service like Let's Encrypt, a `ClusterIssuer` is the right choice — it is available to `Certificate` resources in any namespace.

**Store the ACME account private key in a meaningful Secret name.** cert-manager creates the key automatically the first time an issuer registers with the ACME server. If you delete and recreate the issuer, cert-manager registers a new account. This is harmless, but if you are managing multiple clusters or environments, using explicit, environment-specific names like `letsencrypt-prod-account-key-cluster-a` makes it easier to track what belongs to what.

**Monitor certificate expiry.** cert-manager exposes Prometheus metrics including `certmanager_certificate_expiration_timestamp_seconds`. Alert on certificates with less than 14 days remaining — this catches cases where automatic renewal has been failing silently (for example due to a misconfigured challenge solver after an Ingress controller migration).

**For wildcard certificates, use the DNS-01 solver.** HTTP-01 validation requires Let's Encrypt to reach a URL on the specific hostname being validated, which means it cannot validate wildcard domains like `*.example.com`. The DNS-01 solver proves domain ownership by creating a TXT record in your DNS zone instead, which works for wildcards. cert-manager has built-in solvers for most major DNS providers.

## Conclusion

cert-manager removes the operational burden of TLS certificate management from your Kubernetes workloads entirely. You define a `ClusterIssuer` once, annotate your Ingresses, and the controller handles everything from the ACME challenge flow through to automatic renewal at 2/3 of the certificate lifetime. A service that would have required manual certificate provisioning and a calendar reminder to rotate it every 90 days now just works.

The setup in this post — cert-manager installed via Helm, staging and production Let's Encrypt issuers, and an annotated Ingress — covers the majority of use cases for public-facing services. From here you can extend the pattern to internal CAs using cert-manager's CA issuer for private cluster services, to DNS-01 solvers for wildcard certificates, and to integrations with Vault PKI secrets engine for workloads that need certificates from your own PKI.

Get the staging flow working first, validate the certificate chain, then flip to production. The two-issuer pattern saves you from hitting rate limits while you iron out the solver configuration.

Happy scripting!
