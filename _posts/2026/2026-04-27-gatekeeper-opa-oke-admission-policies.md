---
title: 'OPA Gatekeeper on OKE: Enforcing Admission Control Policies'
author: Victor Silva
date: 2026-04-27T22:15:24+00:00
layout: post
permalink: /gatekeeper-opa-oke-admission-policies/
excerpt: "Deploy OPA Gatekeeper on OKE to enforce admission policies at the API server: no privileged containers, OCIR-only images, mandatory resource limits."
categories:
  - OCI
  - Security
tags:
  - OKE
  - gatekeeper
  - OPA
  - kubernetes
  - admission-control
  - oci
  - devsecops
  - cncf
---

When working with Oracle Kubernetes Engine, it's easy to assume that the perimeter controls are enough. You have OCI IAM restricting who can call the OCI API, Network Security Groups controlling pod traffic, and OCIR access policies preventing unauthorized image pulls. What those controls don't give you is any say over what actually runs inside the cluster once a deployment reaches the API server. OPA Gatekeeper fills that gap by acting as a validating admission webhook — every resource create or update passes through it before landing in etcd.

A developer pushes a pod spec with `securityContext.privileged: true`. A CI pipeline accidentally references `docker.io/library/nginx:latest` instead of the internal OCIR image. A Deployment ships without any resource limits, and it silently consumes all available memory on the node during a traffic spike. None of these get blocked by NSGs or IAM policies — they land on your nodes and run.

This is the gap that admission control closes, and OPA Gatekeeper is the CNCF-graduated project purpose-built to fill it. In this post you will install Gatekeeper v3.22.1 on an OKE free-tier cluster, configure the namespace exemptions that OKE specifically requires, and implement three policies that address the scenarios above. By the end, all three will block at admission time with clear error messages, and the audit controller will surface existing violations in resources that predated the policies.

## How OPA Gatekeeper Works as an Admission Webhook

Before installing anything, it helps to understand the mechanics. Gatekeeper operates as a validating admission webhook registered against the Kubernetes API server. Every time a resource is created or updated, the API server synchronously calls the webhook with the full object in the request. Gatekeeper evaluates the object against your policies — written in Rego, the policy language from Open Policy Agent — and returns either an allow or a deny. `enforcementAction: deny` blocks the request before it persists; the user gets an error message directly from `kubectl`.

This is different from runtime security tools like Falco, which detect and alert on things that are already running. Gatekeeper operates at the gate — it prevents the non-compliant configuration from ever existing in your cluster.

There are two components:

```
                        kubectl apply
                              |
                        kube-apiserver
                              |
               Validating Admission Webhook (sync)
                              |
                    Gatekeeper Controller Manager
                    (2 replicas, HA)
                              |
                   ConstraintTemplate + Constraint
                   evaluated against the object
                              |
                    allow / deny with message
```

The **Audit Controller** runs a separate background loop every 60 seconds. It re-evaluates all existing resources against current constraints and writes violations into the `.status` field of each Constraint object. This is how you find out whether resources that were already running at policy installation time are now non-compliant — the audit controller surfaces them without blocking anything.

The two key custom resources are:

- `ConstraintTemplate` — defines a new CRD and the Rego logic that evaluates it. You write one of these per policy type.
- `Constraint` — an instance of a ConstraintTemplate. This is where you set `enforcementAction`, scope the policy to specific namespaces and resource kinds, and pass parameters into the Rego.

Gatekeeper is a CNCF-graduated project, meaning it has met the CNCF's requirements for production readiness, stability, and adoption at scale. If you are evaluating it against rolling your own admission webhook, the graduation status settles the maturity question.

## Prerequisites

For this walkthrough you need:

- An OKE cluster — basic or enhanced, free tier is sufficient. The research for this post used `VM.Standard.A1.Flex` nodes (2 oCPUs, 12 GB RAM each, two nodes), which is the Always Free ARM shape on OCI.
- `kubectl` configured against the cluster with cluster-admin access
- Helm 3.x installed
- OCI CLI installed and configured (used only for the kubeconfig setup below)

If your OKE cluster is newly provisioned, fetch the kubeconfig first:

{% highlight bash %}
oci ce cluster create-kubeconfig \
  --cluster-id <cluster-ocid> \
  --file $HOME/.kube/config \
  --region <region-identifier> \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

export KUBECONFIG=$HOME/.kube/config
kubectl get nodes
{% endhighlight %}

You should see your OKE worker nodes in a `Ready` state. On an A1 Flex free-tier cluster, the architecture column will show `arm64`.

Verify Helm is available:

{% highlight bash %}
helm version --short
kubectl version --short
{% endhighlight %}

One thing you do not need: cert-manager. Gatekeeper generates and manages its own TLS certificates for the admission webhook. This is worth calling out because many admission webhooks require cert-manager as a dependency, and on a fresh cluster that is an entire additional installation step. Gatekeeper handles it internally.

## Installing Gatekeeper on OKE with Helm

Add the Helm repository and update:

{% highlight bash %}
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
{% endhighlight %}

Install into its own namespace with the settings tuned for OKE:

{% highlight bash %}
helm install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --version 3.22.0 \
  --set replicas=2 \
  --set auditInterval=60 \
  --set constraintViolationsLimit=50 \
  --set validatingWebhookFailurePolicy=Ignore \
  --set "controllerManager.exemptNamespaces={kube-system,gatekeeper-system}"
{% endhighlight %}

A few of these flags deserve explanation.

`replicas=2` runs two Controller Manager replicas for high availability. On a two-node free-tier cluster this still gives you failover if one node is cycling. With one replica, if the Gatekeeper pod is restarting exactly when you deploy something, the webhook call either fails open (`Ignore`) or blocks the entire deployment (`Fail`) depending on `validatingWebhookFailurePolicy`.

`validatingWebhookFailurePolicy=Ignore` means that if the Gatekeeper webhook is unreachable, admission proceeds without enforcement. This is the right default for an initial installation — you want time to verify system namespace exemptions are complete before switching to `Fail`. Running `Fail` without complete exemptions causes system components in `kube-system` to break when Gatekeeper restarts.

`constraintViolationsLimit=50` raises the default from 20. For a cluster-wide audit covering all namespaces and multiple constraint types, 20 violations per constraint fills up quickly and you lose visibility into the tail of the violation list.

The `controllerManager.exemptNamespaces` flag seeds the initial exemption at install time for the two namespaces Gatekeeper itself needs: `kube-system` and `gatekeeper-system`. We will extend this with a `Config` resource in the next step.

The Gatekeeper Helm chart publishes multi-arch images. The `linux/arm64` build is included in the manifest list, so the pods schedule on OKE A1 Arm nodes without any image override or node selector change.

Wait for the pods:

{% highlight bash %}
kubectl get pods -n gatekeeper-system
{% endhighlight %}

You should see two `gatekeeper-controller-manager` pods and one `gatekeeper-audit` pod, all `Running`. Also verify that the CRDs and the webhook registration landed:

{% highlight bash %}
kubectl get crd | grep gatekeeper
kubectl get ValidatingWebhookConfiguration gatekeeper-validating-webhook-configuration
{% endhighlight %}

The CRD list should include `constrainttemplatepodstatuses.status.gatekeeper.sh`, `constrainttemplates.templates.gatekeeper.sh`, and `configs.config.gatekeeper.sh` among others. The `ValidatingWebhookConfiguration` being present confirms the API server knows to call Gatekeeper for admission decisions.

## Configuring OKE Namespace Exemptions

This step is specific to OKE and is the one most likely to cause problems if skipped. OKE runs several system components in namespaces that your policies must never evaluate — if a constraint blocks a CoreDNS or `vcn-native-ip-cni` pod from restarting, you have a networking outage.

The namespaces that need exemption on OKE are:

- `kube-system` — CoreDNS, kube-proxy, the VCN-native IP CNI DaemonSet
- `kube-node-lease` — node heartbeat leases
- `kube-public` — public cluster info
- `gatekeeper-system` — Gatekeeper itself
- `native-ingress-controller-system` — if you have the OCI Native Ingress Controller add-on enabled

The `controllerManager.exemptNamespaces` Helm flag only configures the webhook-level exemption for `kube-system` and `gatekeeper-system`. The `Config` resource below extends exemption to both the webhook and the audit controller, and adds the remaining OKE namespaces:

{% highlight yaml %}
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: config
  namespace: gatekeeper-system
spec:
  match:
    - excludedNamespaces:
        - kube-system
        - kube-node-lease
        - kube-public
        - gatekeeper-system
        - native-ingress-controller-system
      processes: ["*"]
{% endhighlight %}

Save this as `gatekeeper-config.yaml` and apply it:

{% highlight bash %}
kubectl apply -f gatekeeper-config.yaml
{% endhighlight %}

The `processes: ["*"]` value exempts these namespaces from both webhook (admission) evaluation and audit. Without the `Config` resource, the audit controller will flag CoreDNS pods for whatever constraints you later apply — the violation count fills up with system component noise, and you can't see the real violations in your workload namespaces.

Verify it was accepted:

{% highlight bash %}
kubectl get config -n gatekeeper-system config -o yaml
{% endhighlight %}

## Policy 1 — Block Privileged Containers

Privileged containers have nearly full access to the host kernel. CIS Kubernetes Benchmark v1.9 control 5.2.1 explicitly requires blocking them. If any workload in your cluster legitimately needs privileged access, it should be explicitly approved through an exemption list in the Constraint, not allowed cluster-wide by default.

The ConstraintTemplate defines the Rego logic and registers a new CRD kind `K8sPSPPrivilegedContainer`:

{% highlight yaml %}
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8spspprivilegedcontainer
  annotations:
    metadata.gatekeeper.sh/title: "Privileged Container"
    metadata.gatekeeper.sh/version: 1.1.3
spec:
  crd:
    spec:
      names:
        kind: K8sPSPPrivilegedContainer
      validation:
        openAPIV3Schema:
          type: object
          description: Controls the ability of any container to enable privileged mode.
          properties:
            exemptImages:
              description: Container images exempt from this policy. Supports * prefix wildcard.
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      code:
      - engine: Rego
        source:
          rego: |
            package k8spspprivileged

            import data.lib.exclude_update.is_update
            import data.lib.exempt_container.is_exempt

            violation[{"msg": msg, "details": {}}] {
                not is_update(input.review)
                c := input_containers[_]
                not is_exempt(c)
                c.securityContext.privileged
                msg := sprintf("Privileged container is not allowed: %v, securityContext: %v",
                               [c.name, c.securityContext])
            }

            input_containers[c] {
                c := input.review.object.spec.containers[_]
            }
            input_containers[c] {
                c := input.review.object.spec.initContainers[_]
            }
            input_containers[c] {
                c := input.review.object.spec.ephemeralContainers[_]
            }
          libs:
            - |
              package lib.exclude_update
              is_update(review) {
                  review.operation == "UPDATE"
              }
            - |
              package lib.exempt_container
              is_exempt(container) {
                  exempt_images := object.get(object.get(input, "parameters", {}), "exemptImages", [])
                  img := container.image
                  exemption := exempt_images[_]
                  _matches_exemption(img, exemption)
              }
              _matches_exemption(img, exemption) {
                  not endswith(exemption, "*")
                  exemption == img
              }
              _matches_exemption(img, exemption) {
                  endswith(exemption, "*")
                  prefix := trim_suffix(exemption, "*")
                  startswith(img, prefix)
              }
{% endhighlight %}

Notice that the Rego checks all three container types: `containers`, `initContainers`, and `ephemeralContainers`. The `ephemeralContainers` check is important — `kubectl debug` injects an ephemeral container, and without this check it is a bypass vector. Update operations are excluded via the `is_update` lib; this avoids blocking updates to pods that predate the policy while still catching new privileged containers.

Now apply the Constraint. This is the instance that activates enforcement:

{% highlight yaml %}
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPSPPrivilegedContainer
metadata:
  name: deny-privileged-containers
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - native-ingress-controller-system
  parameters:
    exemptImages: []
{% endhighlight %}

{% highlight bash %}
kubectl apply -f privileged-container-template.yaml
kubectl apply -f deny-privileged-containers.yaml
{% endhighlight %}

## Policy 2 — Restrict Images to OCIR Only

Allowing workloads to pull from arbitrary public registries introduces supply-chain risk. An image pulled from `docker.io` might be outdated, unscanned, or — in a typosquatting scenario — malicious. Aligning with NIST SP 800-190 section 4.4 means images should come from a trusted, scanned registry. On OCI, that registry is OCIR.

This policy checks all container types against an allowlist of image prefixes. The OCIR format is `<region>.ocir.io/<tenancy-namespace>/`. Ending the prefix with `/` after the tenancy namespace is a critical security detail: without it, an attacker could register `malicious-sa-saopaulo-1.ocir.io` and the prefix check would incorrectly match.

{% highlight yaml %}
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sallowedrepos
  annotations:
    metadata.gatekeeper.sh/title: "Allowed Repositories"
    metadata.gatekeeper.sh/version: 1.0.2
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedRepos
      validation:
        openAPIV3Schema:
          type: object
          properties:
            repos:
              description: List of allowed image prefixes.
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedrepos

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not strings.any_prefix_match(container.image, input.parameters.repos)
          msg := sprintf("container <%v> has an invalid image repo <%v>, allowed repos are %v",
                         [container.name, container.image, input.parameters.repos])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          not strings.any_prefix_match(container.image, input.parameters.repos)
          msg := sprintf("initContainer <%v> has an invalid image repo <%v>, allowed repos are %v",
                         [container.name, container.image, input.parameters.repos])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.ephemeralContainers[_]
          not strings.any_prefix_match(container.image, input.parameters.repos)
          msg := sprintf("ephemeralContainer <%v> has an invalid image repo <%v>, allowed repos are %v",
                         [container.name, container.image, input.parameters.repos])
        }
{% endhighlight %}

The Constraint takes your actual OCIR region and tenancy namespace as a parameter. Replace `sa-saopaulo-1` and `mytenancynamespace` with your values:

{% highlight yaml %}
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedRepos
metadata:
  name: require-ocir-images
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - native-ingress-controller-system
  parameters:
    repos:
      - "sa-saopaulo-1.ocir.io/mytenancynamespace/"
{% endhighlight %}

If you pull from multiple OCIR regions (for example, pulling from a home region registry to a remote region cluster), add both prefixes to the `repos` list. Multiple entries are evaluated as OR — any match allows the image.

{% highlight bash %}
kubectl apply -f allowed-repos-template.yaml
kubectl apply -f require-ocir-images.yaml
{% endhighlight %}

## Policy 3 — Require CPU and Memory Resource Limits

Containers without resource limits compete for node resources without any ceiling. On an OKE free-tier cluster where you have a fixed pool of CPU and memory, one container in a tight loop consuming unbounded CPU can push out other workloads. More broadly, missing resource limits make your cluster unpredictable under load and complicate capacity planning.

This ConstraintTemplate enforces that every container declares both `requests` and `limits` for the resource types you specify. An `exemptImages` parameter is available if you have specific infrastructure images (init containers, sidecars) that legitimately can't have limits set.

{% highlight yaml %}
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredresources
  annotations:
    metadata.gatekeeper.sh/title: "Required Resources"
    metadata.gatekeeper.sh/version: 1.0.1
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredResources
      validation:
        openAPIV3Schema:
          type: object
          properties:
            exemptImages:
              type: array
              items:
                type: string
            limits:
              type: array
              description: "Resource types that must have limits defined."
              items:
                type: string
                enum: [cpu, memory]
            requests:
              type: array
              description: "Resource types that must have requests defined."
              items:
                type: string
                enum: [cpu, memory]
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredresources

        import data.lib.exempt_container.is_exempt

        violation[{"msg": msg}] {
          general_violation[{"msg": msg, "field": "containers"}]
        }

        violation[{"msg": msg}] {
          general_violation[{"msg": msg, "field": "initContainers"}]
        }

        general_violation[{"msg": msg, "field": field}] {
          container := input.review.object.spec[field][_]
          not is_exempt(container)
          provided := {resource_type | container.resources.limits[resource_type]}
          required := {resource_type | resource_type := input.parameters.limits[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("container <%v> does not have <%v> limits defined", [container.name, missing])
        }

        general_violation[{"msg": msg, "field": field}] {
          container := input.review.object.spec[field][_]
          not is_exempt(container)
          provided := {resource_type | container.resources.requests[resource_type]}
          required := {resource_type | resource_type := input.parameters.requests[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("container <%v> does not have <%v> requests defined", [container.name, missing])
        }
      libs:
        - |
          package lib.exempt_container
          is_exempt(container) {
              exempt_images := object.get(object.get(input, "parameters", {}), "exemptImages", [])
              img := container.image
              exemption := exempt_images[_]
              _matches_exemption(img, exemption)
          }
          _matches_exemption(img, exemption) {
              not endswith(exemption, "*")
              exemption == img
          }
          _matches_exemption(img, exemption) {
              endswith(exemption, "*")
              prefix := trim_suffix(exemption, "*")
              startswith(img, prefix)
          }
{% endhighlight %}

The Constraint requires both `cpu` and `memory` limits and requests on all pods outside the system namespaces:

{% highlight yaml %}
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: require-cpu-memory-limits-and-requests
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - native-ingress-controller-system
  parameters:
    limits:
      - cpu
      - memory
    requests:
      - cpu
      - memory
{% endhighlight %}

{% highlight bash %}
kubectl apply -f required-resources-template.yaml
kubectl apply -f require-cpu-memory-limits-and-requests.yaml
{% endhighlight %}

## Testing Admission Policy Enforcement

Now that all three policies are active, let's confirm they block what they should. Each test below should be rejected at admission time with a message that names the violated constraint.

### Test 1: Privileged container

{% highlight bash %}
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: default
spec:
  containers:
  - name: bad
    image: sa-saopaulo-1.ocir.io/mytenancynamespace/myapp:latest
    securityContext:
      privileged: true
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
EOF
{% endhighlight %}

Expected output:

```
Error from server (Forbidden): error when creating "STDIN": admission webhook
"validation.gatekeeper.sh" denied the request: [deny-privileged-containers]
Privileged container is not allowed: bad, securityContext: {"privileged": true}
```

### Test 2: External image

{% highlight bash %}
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-external
  namespace: default
spec:
  containers:
  - name: nginx
    image: docker.io/library/nginx:latest
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
EOF
{% endhighlight %}

Expected output:

```
Error from server (Forbidden): error when creating "STDIN": admission webhook
"validation.gatekeeper.sh" denied the request: [require-ocir-images]
container <nginx> has an invalid image repo <docker.io/library/nginx:latest>,
allowed repos are ["sa-saopaulo-1.ocir.io/mytenancynamespace/"]
```

### Test 3: No resource limits

{% highlight bash %}
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
  namespace: default
spec:
  containers:
  - name: app
    image: sa-saopaulo-1.ocir.io/mytenancynamespace/myapp:latest
EOF
{% endhighlight %}

Expected output:

```
Error from server (Forbidden): error when creating "STDIN": admission webhook
"validation.gatekeeper.sh" denied the request: [require-cpu-memory-limits-and-requests]
container <app> does not have <{"cpu", "memory"}> limits defined
```

All three policies are working. The error messages include the constraint name, which makes it straightforward for developers to identify what rule they violated and where to look for the fix.

### Checking audit violations

The audit controller runs on its own loop and surfaces existing resources that violate constraints. After the policies have been running for 60 seconds or more, query the violation status across all three constraints:

{% highlight bash %}
kubectl get constraints -o custom-columns=\
"NAME:.metadata.name,VIOLATIONS:.status.totalViolations,TIMESTAMP:.status.auditTimestamp"
{% endhighlight %}

To drill into the specific violations for the privileged container constraint:

{% highlight bash %}
kubectl get k8spspprivilegedcontainer deny-privileged-containers \
  -o jsonpath='{.status.violations}' | python3 -m json.tool
{% endhighlight %}

The output includes the namespace, name, message, and enforcement action for each violation. This is how you get a current inventory of non-compliant resources without blocking anything new — useful for the initial rollout of a policy before switching to `enforcementAction: deny`.

## Best Practices

**Use `dryrun` before `deny` in production clusters.** When applying a policy to an existing cluster for the first time, start with `enforcementAction: dryrun`. The audit controller will surface all existing violations over the next 60 seconds without blocking any new deployments. Review the violations, fix or document the exceptions, and then switch to `deny`. The progression is `dryrun` → `warn` → `deny`, and skipping steps on a live cluster will cause surprise outages.

**Switch `validatingWebhookFailurePolicy` to `Fail` only after verifying exemptions are complete.** The default `Ignore` means Gatekeeper can be restarted without affecting cluster operations. `Fail` means any Gatekeeper outage blocks all admission. Only make this switch in production environments where Gatekeeper is deployed with HA replicas and the namespace exemption `Config` has been verified to cover all system namespaces. Half-applied configurations with `Fail` policy are how teams take down their own cluster operations.

**Always include `ephemeralContainers` in your Rego checks.** `kubectl debug` injects an ephemeral container into a running pod and bypasses the normal pod spec — it's a create operation on `pods/ephemeralcontainers`, not a full pod creation. If your constraint only iterates `spec.containers`, a developer or attacker can use `kubectl debug` to get a privileged container or a non-OCIR image into a running pod without triggering the policy. All three policies above handle this, but custom policies you write yourself need the same coverage.

**End OCIR prefixes with `/` after the tenancy namespace.** This is not cosmetic. A prefix of `sa-saopaulo-1.ocir.io/mytenancynamespace` would also match `sa-saopaulo-1.ocir.io/mytenancynamespace-malicious/`. Adding the trailing slash restricts matches strictly to your tenancy's namespace.

**Set `constraintViolationsLimit` higher than the default 20.** The audit controller writes violations into the `.status` field of the Constraint object, and Kubernetes enforces a size limit on status fields. With the default limit of 20, a constraint that catches 50+ violations on a moderately busy cluster truncates silently — you see 20 violations and have no indication there are more. Setting it to 50 at install time gives you a much cleaner picture of the actual violation landscape.

**Align your exemption strategy with your OCI security posture.** Gatekeeper fills the admission gap, but it is one layer. Pairing it with [OCI Security Zones](/oci-security-zones/) for compartment-level guardrails and [OCI Vault for secrets management](/oci-vault-secrets-management-terraform/) gives you defense in depth across the OCI control plane and the Kubernetes data plane. The Kubernetes audit logging you set up in the [previous post](/kubernetes-audit-logging/) will record every Gatekeeper-denied admission as a `403` response in the audit trail — those events are worth alerting on, because a burst of admission denials may indicate a misconfigured CI pipeline or an active attempt to bypass controls.

## Conclusion

Three policies are now actively enforcing at admission time on your OKE cluster: no privileged containers, images restricted to OCIR, and mandatory CPU and memory resource limits. The audit controller is surfacing existing violations in the background. New workloads that don't meet the policy get a specific, actionable error message pointing to the constraint they violated.

Gatekeeper's ConstraintTemplate and Constraint model scales well beyond these three examples. The policy library at `open-policy-agent.github.io/gatekeeper-library` has ready-to-use templates for host network access, host path mounts, AppArmor and seccomp profiles, and more. Each one follows the same pattern you saw here: apply the template, apply the constraint with your parameters, verify in `dryrun` first.

The CNCF graduation status means the API surface is stable and the production-readiness question is answered. The same policy configuration you deploy today will work on future OKE Kubernetes versions within the Gatekeeper compatibility matrix — you do not need to rebuild your constraints when you upgrade the cluster.

Happy scripting!
