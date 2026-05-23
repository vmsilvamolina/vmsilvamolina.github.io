---
title: 'Kyverno on OKE: Admission Policies Without Rego'
author: Victor Silva
date: 2026-05-22T23:47:22+00:00
layout: post
permalink: /kyverno-oke-admission-policies/
excerpt: "Kyverno on OKE: enforce admission control, auto-generate NetworkPolicies, and mutate resources in plain YAML. A no-Rego alternative to OPA Gatekeeper."
categories:
  - OCI
  - Security
tags:
  - kyverno
  - OKE
  - kubernetes
  - admission-control
  - policy-as-code
  - kyverno-oke
  - oci
  - devsecops
  - cncf
  - kyverno-policy
---

In the [OPA Gatekeeper post](/gatekeeper-opa-oke-admission-policies/) we covered how to enforce admission control policies on Oracle Kubernetes Engine — no privileged containers, OCIR-only images, mandatory resource limits — using Gatekeeper's validating admission webhook and Rego policies. Gatekeeper is solid, production-proven, and broadly adopted. But if you've ever handed a Rego file to a developer who doesn't live in policy land, you know the reaction: a blank stare followed by a Slack message asking what `data.lib.has_field` does.

Rego is expressive and powerful. It is also a distinct programming language that your average cloud practitioner doesn't already know. The learning curve is real, and for many teams it becomes the actual bottleneck to rolling out admission control — not the tooling, not the OKE setup, but the friction of onboarding engineers to a new language just to write a policy that says "images must come from OCIR."

Kyverno solves exactly this problem. Policies are Kubernetes resources written in plain YAML using the same patterns you already use for manifests. There is no separate DSL to learn. And on March 16, 2026, Kyverno became the 35th CNCF graduated project, which settles the maturity question for anyone evaluating it for production workloads.

This post walks through installing Kyverno v1.18.1 on OKE, implementing a set of practical security policies — including one that auto-generates a default-deny `NetworkPolicy` in every namespace — and testing the results. You will also see the new CEL-based policy API that replaces the classic `ClusterPolicy` CRD in upcoming versions, so you know what's coming before it lands.

## Kyverno vs OPA Gatekeeper: Choosing the Right Tool

Before installing anything, here is the honest comparison. Both tools are CNCF-graduated and production-ready. The choice comes down to what your team can own long-term.

| Dimension | Kyverno | OPA Gatekeeper |
|---|---|---|
| Policy language | YAML (Kubernetes manifests) | Rego |
| Learning curve | Low | High |
| Policy types | validate, mutate, generate, verifyImages, cleanup | validate, mutate (beta) |
| Generate resources | Native | Not supported |
| Image verification | Native (Cosign / Notary) | Not native |
| CNCF status | Graduated (March 2026) | Graduated |
| Policy portability | Pure YAML — works on OKE, EKS, AKS, GKE | Rego — portable but requires Rego expertise |
| CEL support | GA in v1.17 | Via ValidatingAdmissionPolicy |

The short version: if your team already knows Rego, Gatekeeper is a perfectly valid choice. If you're starting fresh or want policies that any engineer can read and modify without training, Kyverno is the lower-friction path. The two are not mutually exclusive on the same platform either, but running both on a single cluster adds operational overhead for no clear gain — pick one.

## How Kyverno Works

Kyverno deploys as a set of controllers and registers itself as both a validating and mutating admission webhook. Every resource create or update passes through it before landing in etcd.

```
               kubectl apply / Deployment controller
                              |
                        kube-apiserver
                         /          \
              Mutating Webhook    Validating Webhook   (sync)
                         \          /
                      Kyverno Admission Controller
                              |
                    ClusterPolicy / Policy evaluation
                              |
                 allow / deny / mutate / generate
```

Four controllers run in the background after the initial admission check:

- **Admission Controller** — the synchronous webhook path, handles validate and mutate
- **Background Controller** — reconciles generate and mutate rules against existing resources
- **Reports Controller** — writes `PolicyReport` and `ClusterPolicyReport` resources with pass/fail results for all evaluated resources
- **Cleanup Controller** — handles `cleanup` policies that delete resources on a schedule

The Reports Controller is worth calling out specifically. You get structured, queryable compliance reports without any external tooling — `kubectl get policyreport -A` shows you which resources are failing which rules, namespace by namespace. This is considerably more ergonomic than the Gatekeeper audit controller approach of reading violations out of Constraint `.status` fields.

## Prerequisites

You need:

- An OKE cluster running Kubernetes v1.33 or later (Kyverno v1.18 supports v1.33–v1.35)
- `kubectl` configured and pointing at the cluster
- Helm v3
- `jq` for output parsing in the testing section

Verify your cluster version and Helm:

{% highlight bash %}
kubectl version --short
helm version --short
{% endhighlight %}

OKE GA versions that are fully supported by Kyverno v1.18.1: `1.33.10`, `1.34.2`, `1.35.2`. All three work without any workarounds.

## Installing Kyverno on OKE

### Adding the Helm Repository

{% highlight bash %}
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
{% endhighlight %}

### OKE-Specific Namespace Exclusions

This step matters. OKE runs system components in `kube-system`, `kube-node-lease`, and `kube-public`. If Kyverno's webhook intercepts those namespaces and a policy denies a system pod restart, you can end up with a non-recoverable node. The webhook must be told to skip them.

{% highlight bash %}
helm install kyverno kyverno/kyverno \
  -n kyverno --create-namespace \
  --set "config.webhooks[0].namespaceSelector.matchExpressions[0].key=kubernetes.io/metadata.name" \
  --set "config.webhooks[0].namespaceSelector.matchExpressions[0].operator=NotIn" \
  --set "config.webhooks[0].namespaceSelector.matchExpressions[0].values={kube-system,kyverno,kube-node-lease,kube-public}"
{% endhighlight %}

This configures the webhook's `namespaceSelector` to exclude system namespaces at the webhook registration level — Kyverno never even sees requests originating from those namespaces.

### Verifying the Installation

{% highlight bash %}
kubectl get pods -n kyverno
{% endhighlight %}

Expected output — four controller pods, all `Running`:

```
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-68d7c9fbdc-x9k2p   1/1     Running   0          2m
kyverno-background-controller-7b9c6f8d4-lmn4r   1/1     Running   0          2m
kyverno-cleanup-controller-5f7d9c6b8-pqr7s      1/1     Running   0          2m
kyverno-reports-controller-6c8b9d7f5-vwx3t      1/1     Running   0          2m
```

Confirm the webhook registrations are in place:

{% highlight bash %}
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
{% endhighlight %}

You should see entries for `kyverno-resource-validating-webhook-cfg` and `kyverno-resource-mutating-webhook-cfg`.

### Pod Security Standards Bundle (Optional but Recommended)

Kyverno ships a pre-built policy bundle implementing the Kubernetes Pod Security Standards. Installing it in `Audit` mode first is the fastest way to find out how your existing workloads score against the baseline:

{% highlight bash %}
helm install kyverno-pss kyverno/kyverno-policies \
  -n kyverno \
  --set podSecurityStandard=baseline \
  --set validationFailureAction=Audit
{% endhighlight %}

Leave this running in Audit mode while you work through the custom policies below. After a few minutes you can run `kubectl get policyreport -A` to see what it found.

## Implementing Policies

Now that we have Kyverno installed, let's implement the policies. The approach follows the same progression used in the Gatekeeper post: security baselines first, then operational best practices, then the OKE-specific controls.

A quick note on `validationFailureAction` before we start. `Enforce` blocks the request at admission time — the user gets an error immediately. `Audit` allows the request but records the violation in the PolicyReport. The recommended rollout strategy is always Audit first, review the report, then switch to Enforce. I will call out which mode each policy starts in.

### Policy 1: Block Privileged Containers (Enforce)

Privileged containers have root-level access to the host. There is no legitimate reason for application workloads on OKE to run privileged — this should be Enforced from day one.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
  annotations:
    policies.kyverno.io/title: Disallow Privileged Containers
    policies.kyverno.io/category: Pod Security
    policies.kyverno.io/severity: high
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Privileged containers have root-level access to the host.
      This policy blocks any Pod requesting privileged mode.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: privileged-containers
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privileged containers are not allowed."
        pattern:
          spec:
            =(initContainers):
              - =(securityContext):
                  =(privileged): "false"
            containers:
              - =(securityContext):
                  =(privileged): "false"
{% endhighlight %}

The `=()` syntax is Kyverno's conditional pattern anchor — the check only applies if the field is present. A container that omits `securityContext` entirely is allowed; one that explicitly sets `privileged: true` is denied. This is the correct behavior: you want to block explicit privilege escalation without penalizing manifests that simply don't set a security context.

`background: true` means the Background Controller will also evaluate existing pods and report violations in PolicyReports — you're not flying blind on resources that predated the policy.

### Policy 2: Require Resource Limits (Audit)

Containers without resource limits can consume all available node memory during a traffic spike. Start this one in Audit mode to see how many of your current workloads are missing limits before you block anything.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-requests-limits
  annotations:
    policies.kyverno.io/title: Require Limits and Requests
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: validate-resources
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "CPU and memory resource requests and memory limits are required for containers."
        pattern:
          spec:
            containers:
              - resources:
                  requests:
                    memory: "?*"
                    cpu: "?*"
                  limits:
                    memory: "?*"
{% endhighlight %}

The `?*` pattern matches any non-empty string. This is how Kyverno expresses "field must be present and non-empty" without you having to enumerate valid values.

### Policy 3: Require Labels on Workloads (Enforce)

Consistent labeling is the foundation of cost attribution, incident response, and access control. Without `app`, `env`, and `owner` labels you cannot reliably filter resources in the OCI Monitoring dashboards or build team-scoped RBAC.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
  annotations:
    policies.kyverno.io/title: Require Labels
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod, Deployment
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-team
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
                - DaemonSet
      validate:
        message: "The labels 'app', 'env', and 'owner' are required on all workload resources."
        pattern:
          metadata:
            labels:
              app: "?*"
              env: "?*"
              owner: "?*"
{% endhighlight %}

Note that this policy matches on `Deployment`, `StatefulSet`, and `DaemonSet` — not on `Pod`. Matching on the parent workload resource is preferable because developers interact with Deployments, not raw Pods. Enforcing labels at the Deployment level catches violations at the point where the developer has control.

### Policy 4: Restrict Images to OCIR (Enforce)

Any image not sourced from your OCIR tenancy is a supply chain risk. This policy blocks pulls from public registries at admission time.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
  annotations:
    policies.kyverno.io/title: Restrict Image Registries to OCIR
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Images must only be pulled from the Oracle Container Registry (OCIR).
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: validate-registries
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Images must be pulled from OCIR (<region>.ocir.io). Public registries are not allowed."
        pattern:
          spec:
            =(ephemeralContainers):
              - image: "*.ocir.io/*"
            =(initContainers):
              - image: "*.ocir.io/*"
            containers:
              - image: "*.ocir.io/*"
{% endhighlight %}

The `*.ocir.io/*` pattern uses a wildcard prefix to match any OCIR region endpoint — `iad.ocir.io`, `fra.ocir.io`, `syd.ocir.io`, etc. — while requiring a repository path after the slash. Images that match `docker.io/*`, `ghcr.io/*`, or anything other than `*.ocir.io/*` will be denied.

If you want to go beyond registry restriction and cryptographically verify that images were built by your pipeline, Kyverno's `verifyImages` rule uses Cosign signatures. See [signing container images with Cosign and Sigstore](/signing-container-images-cosign-sigstore/) for the signing side of that workflow.

### Policy 5: Disallow the `latest` Tag (Enforce)

Mutable image tags make deployments non-reproducible and make rollbacks unreliable. Two rules in a single policy: one requiring that a tag exists at all, one rejecting the `latest` tag specifically.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
  annotations:
    policies.kyverno.io/title: Disallow Latest Tag
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: Pod
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: require-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "An image tag is required."
        pattern:
          spec:
            containers:
              - image: "*:*"
    - name: validate-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Using a mutable image tag e.g. 'latest' is not allowed."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
{% endhighlight %}

### Policy 6: Auto-Generate a Default-Deny NetworkPolicy (Generate)

This is where Kyverno pulls ahead of Gatekeeper in a meaningful way. Gatekeeper can validate and (in beta) mutate, but it cannot generate new resources. Kyverno's `generate` type creates a new Kubernetes resource in response to another resource being created or updated.

The policy below creates a default-deny `NetworkPolicy` automatically in every new namespace, except the system namespaces. You get network isolation by default without requiring every team to remember to create it.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-networkpolicy
  annotations:
    policies.kyverno.io/title: Add Default-Deny Network Policy
    policies.kyverno.io/category: Multi-Tenancy
    policies.kyverno.io/subject: NetworkPolicy
    policies.kyverno.io/description: >-
      Creates a default-deny NetworkPolicy in every new Namespace.
spec:
  rules:
    - name: default-deny
      match:
        any:
          - resources:
              kinds:
                - Namespace
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - kube-public
                - kyverno
                - kube-node-lease
      generate:
        apiVersion: networking.k8s.io/v1
        kind: NetworkPolicy
        name: default-deny
        namespace: "{{request.object.metadata.name}}"
        synchronize: true
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
{% endhighlight %}

`synchronize: true` is important — it means if someone manually deletes the generated `NetworkPolicy`, Kyverno will recreate it. The generate rule stays in sync with reality.

### Policy 7: Mutate — Force OCI Load Balancers to Internal (Mutate)

The mutation policy type automatically modifies resources before they are persisted. This example auto-injects the OCI internal load balancer annotation on any `Service` of type `LoadBalancer`, unless it's explicitly labeled `service-type: external`. This prevents accidental public load balancer creation — a common and expensive mistake on OKE.

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: mutate-oci-lb-internal
  annotations:
    policies.kyverno.io/title: Force OCI Load Balancers to Internal
    policies.kyverno.io/category: OCI Best Practices
    policies.kyverno.io/subject: Service
spec:
  rules:
    - name: set-internal-lb
      match:
        any:
          - resources:
              kinds:
                - Service
              operations:
                - CREATE
                - UPDATE
      exclude:
        any:
          - resources:
              selector:
                matchLabels:
                  service-type: "external"
      preconditions:
        all:
          - key: "{{request.object.spec.type}}"
            operator: Equals
            value: LoadBalancer
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              service.beta.kubernetes.io/oci-load-balancer-internal: "true"
{% endhighlight %}

Any `Service` of type `LoadBalancer` that does not carry the `service-type: external` label will be patched with `oci-load-balancer-internal: "true"` before it is persisted. Services that are intentionally public get the label — a deliberate, auditable override rather than a silent default.

## Testing and Validation

### Verifying Pod Status

{% highlight bash %}
kubectl get pods -n kyverno
{% endhighlight %}

All four controller pods should be in `Running` state. If any are in `CrashLoopBackOff`, check the logs:

{% highlight bash %}
kubectl logs -n kyverno -l app.kubernetes.io/component=admission-controller --tail=50
{% endhighlight %}

### Testing the Privileged Container Block

{% highlight bash %}
kubectl run test-priv --image=nginx \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","securityContext":{"privileged":true}}]}}' \
  --dry-run=server
{% endhighlight %}

Expected output:

```
Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
resource Pod/default/test-priv was blocked due to the following policies

disallow-privileged-containers:
  privileged-containers: Privileged containers are not allowed.
```

### Testing the Generate Policy

{% highlight bash %}
kubectl create namespace test-team
kubectl get networkpolicy -n test-team
{% endhighlight %}

Expected output — the `default-deny` NetworkPolicy created automatically:

```
NAME           POD-SELECTOR   AGE
default-deny   <none>         3s
```

Delete it and watch Kyverno recreate it:

{% highlight bash %}
kubectl delete networkpolicy default-deny -n test-team
kubectl get networkpolicy -n test-team
{% endhighlight %}

Because `synchronize: true` is set, the policy reappears within a few seconds.

### Testing the Mutate Policy (Dry Run)

Create a test service manifest:

{% highlight yaml %}
apiVersion: v1
kind: Service
metadata:
  name: test-lb
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: test
  ports:
    - port: 80
      targetPort: 8080
{% endhighlight %}

Apply it in dry-run mode and inspect the annotations in the response:

{% highlight bash %}
kubectl apply -f service.yaml --dry-run=server -o json | jq ".metadata.annotations"
{% endhighlight %}

Expected output:

{% highlight json %}
{
  "service.beta.kubernetes.io/oci-load-balancer-internal": "true"
}
{% endhighlight %}

The annotation is injected by Kyverno during the mutating admission phase. The manifest you submitted didn't have it; the persisted object does.

### Inspecting PolicyReports

This is where Kyverno's reporting story shines. Every evaluation result is written as a `PolicyReport` (namespace-scoped) or `ClusterPolicyReport` (cluster-scoped) resource:

{% highlight bash %}
# All namespace-scoped reports
kubectl get policyreport -A

# Cluster-scoped report
kubectl get clusterpolicyreport

# See which resources are failing the resource limits policy
kubectl get polr -n default -o yaml | grep -A5 "result: fail"
{% endhighlight %}

Watch the reports update in real time while you deploy test workloads:

{% highlight bash %}
kubectl get polr -A --watch
{% endhighlight %}

### PolicyExceptions for Legitimate Bypasses

Not every rule applies to every workload. `prometheus-node-exporter` genuinely needs privileged access to read host metrics. Rather than disabling the policy or adding a namespace exclusion that's too broad, Kyverno v2 introduced `PolicyException` — a scoped, auditable override:

{% highlight yaml %}
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: monitoring-privileged-exception
  namespace: monitoring
spec:
  exceptions:
    - policyName: disallow-privileged-containers
      ruleNames:
        - privileged-containers
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - monitoring
          names:
            - "prometheus-node-exporter-*"
{% endhighlight %}

The exception is namespace-scoped to `monitoring` and name-scoped to pods matching `prometheus-node-exporter-*`. Restrict who can create `PolicyException` resources in your cluster using RBAC — they should require a deliberate approval process, not be creatable by any developer.

## The Kyverno CLI: Testing Without a Cluster

The Kyverno CLI lets you validate policies against manifests locally, before pushing to the cluster. This belongs in your CI pipeline.

{% highlight bash %}
# Install via Homebrew
brew install kyverno

# Or via krew
kubectl krew install kyverno

# Test a policy against a resource file
kyverno apply disallow-latest-tag.yaml --resource pod.yaml

# Run a structured test suite in a directory
kyverno test ./tests/
{% endhighlight %}

The GitHub Action `kyverno/action-install-cli` installs the CLI in your pipeline. Run `kyverno apply` as part of a PR check to block non-compliant manifests before they ever reach the cluster — this is shift-left admission control without needing a live webhook.

## Looking Ahead: The CEL-Based Policy API

> **Deprecation notice:** In Kyverno v1.17 (February 2026), the `ClusterPolicy` and `Policy` CRDs used throughout this post are deprecated in favor of new CEL-based policy types: `ValidatingPolicy`, `MutatingPolicy`, and `GeneratingPolicy`. Removal is planned for v1.20, approximately October 2026. The classic `ClusterPolicy` CRD still works fully in v1.18, but new policies should use the new API where possible.

The new `ValidatingPolicy` uses the Common Expression Language (CEL), the same language used by Kubernetes' native `ValidatingAdmissionPolicy`. Here is the `require-labels` policy rewritten as a `ValidatingPolicy`:

{% highlight yaml %}
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-labels-cel
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments", "statefulsets", "daemonsets"]
  validations:
    - message: "Labels 'app', 'env', and 'owner' are required."
      expression: |
        has(object.metadata.labels) &&
        has(object.metadata.labels.app) &&
        has(object.metadata.labels.env) &&
        has(object.metadata.labels.owner)
{% endhighlight %}

CEL is not Rego — it is a simpler, more constrained expression language that is already part of the Kubernetes API surface. Most platform engineers will find it approachable. For the policies in this post, the YAML pattern-matching approach is still the most readable option, but keep the new API in mind for new work.

## Best Practices

**1. Always start in Audit, then switch to Enforce.** The one exception to this rule is the privileged containers policy — that one is safe to Enforce from day one. For everything else, let the PolicyReport surface existing violations before you start blocking production workloads.

**2. Exclude system namespaces at the webhook level.** The `namespaceSelector` approach used in the Helm install command above is safer than per-policy `exclude` blocks because it prevents the webhook from even seeing requests from system namespaces. Per-policy exclusions are also valid but need to be maintained in every policy.

**3. Use `background: true` on all validate rules.** Without it, resources that existed before the policy was installed are invisible to the Reports Controller. Background evaluation is what gives you a complete compliance picture, not just coverage of new workloads.

**4. Treat PolicyExceptions like production changes.** Restrict `PolicyException` creation with RBAC — only a specific ServiceAccount or group should be able to create them, and only in designated namespaces. An unrestricted `PolicyException` resource is a policy bypass anyone can create.

**5. Use `synchronize: true` on all generate rules.** Without synchronize, someone can delete the generated resource and Kyverno won't recreate it. With synchronize, the generated resource's lifecycle is managed by the policy — drift is automatically corrected.

**6. Integrate the Kyverno CLI into CI/CD.** The `kyverno apply` command catches violations against static manifests before any cluster interaction. Combine it with `kyverno test` for structured test suites that run in seconds. The `kyverno/action-install-cli` GitHub Action makes the setup trivial.

**7. Plan your migration to the CEL-based API.** The `ClusterPolicy` CRD removal target is v1.20 (~October 2026). Start writing new policies using `ValidatingPolicy`, `MutatingPolicy`, and `GeneratingPolicy` now so you're not doing a bulk migration under pressure.

## Wrapping Up

Kyverno gives you the same admission control capability as OPA Gatekeeper — validate, mutate, and now generate — with a significantly lower barrier to entry. You write policies as plain Kubernetes YAML, use pattern matching rather than a policy language, and get PolicyReports out of the box. The generate type is a genuine differentiator: automatic default-deny NetworkPolicies, auto-created ConfigMaps, resource defaults injected on namespace creation — all without any external tooling.

The OKE-specific setup is minimal. The main thing to get right is the namespace exclusion at the webhook level, and the Helm install command above handles that in a single flag set. From there, the seven policies in this post cover the security baselines that matter most for OCI workloads: privilege escalation, registry control, image tag hygiene, resource limits, label governance, network isolation defaults, and load balancer visibility.

If you're coming from the [OPA Gatekeeper post](/gatekeeper-opa-oke-admission-policies/), the mental model maps directly — ClusterPolicy is your ConstraintTemplate plus Constraint in one resource, Audit mode is your Gatekeeper audit controller, and PolicyReports replace reading violations from Constraint `.status` fields. The concepts are the same; the operational experience is smoother.

Happy scripting!
