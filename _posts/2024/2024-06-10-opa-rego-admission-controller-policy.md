---
title: "OPA and Rego: writing your first admission controller policy"
author: Victor Silva
date: 2024-06-10T21:34:36+00:00
layout: post
permalink: /opa-rego-admission-controller-policy/
excerpt: "Deploying workloads without resource limits is one of the most common ways a noisy neighbor takes down your entire cluster. OPA Gatekeeper lets you enforce policies like this at admission time, before the object ever lands in etcd. This post walks through installing Gatekeeper, writing a Rego policy that blocks pods without resource limits, and testing it against a live cluster."
categories:
  - Kubernetes Security
tags:
  - opa
  - rego
  - kubernetes
  - admission-controller
  - cncf
---

You have cluster resource quotas configured at the namespace level. You have documentation telling developers to set `requests` and `limits` on every container. And then every few weeks a pod gets deployed without them, a memory leak kicks in, and the node starts evicting everything around it. Documentation does not enforce itself, and resource quotas only reject pods when the namespace total is already exceeded. What you actually need is a policy that fires at admission time, before the object ever reaches the API server's storage layer.

That is exactly what Open Policy Agent Gatekeeper is built for. OPA is a CNCF graduated project that provides a general-purpose policy engine. Gatekeeper is its Kubernetes-native integration, implemented as a validating admission webhook. Every time a resource is created or updated, the API server sends the manifest to Gatekeeper, which evaluates it against your policies and returns allow or deny. No object lands in etcd until it passes every policy check.

This post walks through installing Gatekeeper, understanding how Rego policies are structured, writing a policy that blocks pods missing container resource limits, and testing it so you know the policy actually works before you roll it out to production.

## How OPA and Gatekeeper Work

Before writing a single line of Rego, it helps to understand the layers involved.

**Open Policy Agent** is the policy engine. It evaluates queries written in Rego against arbitrary JSON or YAML input data and returns a decision. OPA itself knows nothing about Kubernetes - it is a general-purpose tool used for everything from API authorization to Terraform plan validation.

**Gatekeeper** is the Kubernetes adapter. It runs as a deployment inside your cluster and registers itself as a validating admission webhook with the API server. When a resource event matches the webhook's scope rules, Kubernetes sends the full admission review request to Gatekeeper, which calls OPA to evaluate the policies, then returns the result.

**ConstraintTemplate** and **Constraint** are the two Kubernetes objects you actually work with. A `ConstraintTemplate` defines the Rego logic and declares the schema for its configuration parameters. A `Constraint` is an instance of that template applied to specific resource types and namespaces. This split means the same Rego logic can be reused with different configurations - one policy module, multiple enforcement rules.

The admission flow looks like this:

```
kubectl apply -f pod.yaml
        |
   kube-apiserver
        |
   Validating Admission Webhook
        |
   Gatekeeper (admission-controller pod)
        |
   OPA evaluates Rego against AdmissionReview input
        |
   ALLOW or DENY (with message)
        |
   If ALLOW: object written to etcd
```

Everything happens synchronously within the webhook timeout. If Gatekeeper is unreachable, the API server falls back to the `failurePolicy` you configure on the webhook - either `Fail` (deny all) or `Ignore` (allow all). More on that in the best practices section.

## Prerequisites

To follow along you will need:

- A Kubernetes cluster running version 1.25 or higher
- `kubectl` configured with cluster-admin privileges
- Helm 3 installed

Verify your cluster version and access level before proceeding:

{% highlight bash %}
kubectl version --short
kubectl auth can-i create clusterrolebindings --all-namespaces
{% endhighlight %}

Both commands should return without errors. The second should print `yes`.

## Installing OPA Gatekeeper

The recommended installation method is via the official Helm chart. Add the Gatekeeper repository and update:

{% highlight bash %}
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
{% endhighlight %}

Install Gatekeeper into its own namespace. The configuration below is suitable for a production cluster - it sets three audit interval seconds, enables external data (useful later when you need to query external sources), and explicitly sets `failurePolicy` to `Ignore` during initial rollout so a Gatekeeper outage does not block the entire cluster while you are testing policies:

{% highlight bash %}
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --version 3.16.3 \
  --set auditInterval=60 \
  --set constraintViolationsLimit=100 \
  --set webhook.failurePolicy=Ignore \
  --set audit.logLevel=INFO
{% endhighlight %}

Once you have confidence in your policies and Gatekeeper's availability, you will want to switch `failurePolicy` to `Fail`. Leave it on `Ignore` for now.

Wait for the Gatekeeper pods to be ready:

{% highlight bash %}
kubectl rollout status deployment/gatekeeper-controller-manager -n gatekeeper-system
kubectl rollout status deployment/gatekeeper-audit -n gatekeeper-system
{% endhighlight %}

Gatekeeper runs two components: the `controller-manager` handles real-time admission webhook calls, and the `audit` component periodically re-evaluates existing resources against your policies to surface violations on objects that existed before the policy was created.

## Understanding Rego

Rego is the policy language OPA uses. It looks unusual if you are coming from a procedural background, but it follows a clear model once you understand two things.

First, Rego is declarative. You define what a violation looks like, not a sequence of steps to check for it. A policy is a set of rules that evaluate to true when a condition holds.

Second, Rego policies in Gatekeeper always evaluate the `input` object, which is the full Kubernetes `AdmissionReview` request. The object being admitted lives at `input.review.object`.

Here is the simplest Gatekeeper policy possible - one that denies everything:

{% highlight rego %}
package k8sdenything

violation[{"msg": msg}] {
  msg := "this policy denies everything"
}
{% endhighlight %}

A `violation` rule fires when its body evaluates to true. The body here is an unconditional statement, so it always fires. In practice, the body contains conditions that check the incoming object.

Now let's look at a real policy.

## Writing the Resource Limits Policy

The policy we are writing enforces a simple requirement: every container in a pod must declare both `resources.requests` and `resources.limits`. If any container is missing either, the admission is denied with a clear message telling the developer what is wrong.

### ConstraintTemplate

The `ConstraintTemplate` defines the Rego logic. Create a file called `require-resource-limits-template.yaml`:

{% highlight yaml %}
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequireresourcelimits
  annotations:
    description: >-
      Requires all containers in a Pod to define resource requests and limits
      for CPU and memory.
spec:
  crd:
    spec:
      names:
        kind: K8sRequireResourceLimits
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireresourcelimits

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.memory
          msg := sprintf(
            "container <%v> is missing resources.limits.memory",
            [container.name]
          )
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.limits.cpu
          msg := sprintf(
            "container <%v> is missing resources.limits.cpu",
            [container.name]
          )
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.requests.memory
          msg := sprintf(
            "container <%v> is missing resources.requests.memory",
            [container.name]
          )
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not container.resources.requests.cpu
          msg := sprintf(
            "container <%v> is missing resources.requests.cpu",
            [container.name]
          )
        }
{% endhighlight %}

A few things to call out in this Rego. The `input.review.object.spec.containers[_]` expression iterates over every container using the `_` wildcard. Each violation rule fires independently for each container and each missing field, which means a pod with two containers that are both missing memory limits will produce two separate violation messages - one per container. This makes the denial message specific and actionable.

The `not container.resources.limits.memory` check uses Rego's `not` keyword. In Rego, accessing a path that does not exist evaluates to `undefined`, and `not undefined` evaluates to `true`. This is how you check for missing fields without causing evaluation errors.

### Constraint

The `Constraint` instantiates the template and specifies where it applies. Create `require-resource-limits-constraint.yaml`:

{% highlight yaml %}
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireResourceLimits
metadata:
  name: require-resource-limits
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
      - monitoring
  enforcementAction: deny
{% endhighlight %}

The `match.kinds` block scopes this constraint to `Pod` resources in the core API group. The `excludedNamespaces` list is important - system namespaces like `kube-system` contain DaemonSet pods that may not have resource limits defined, and excluding them from the policy prevents it from interfering with cluster operations. Add any namespace here that contains infrastructure workloads you do not control.

The `enforcementAction: deny` field has two other options worth knowing: `warn` emits the violation as a warning in the API response without blocking the request (useful for dry-run rollouts), and `dryrun` records the violation in the audit log only without affecting admission.

### Applying the Policy

Apply both objects to the cluster:

{% highlight bash %}
kubectl apply -f require-resource-limits-template.yaml
kubectl apply -f require-resource-limits-constraint.yaml
{% endhighlight %}

Verify that the template and constraint were created successfully:

{% highlight bash %}
kubectl get constrainttemplate k8srequireresourcelimits
kubectl get k8srequireresourcelimits require-resource-limits
{% endhighlight %}

The constraint object's status section will show any Rego compilation errors. Check it:

{% highlight bash %}
kubectl describe k8srequireresourcelimits require-resource-limits
{% endhighlight %}

Look for a `byPod` status block that confirms the controller-manager and audit pods have both loaded the constraint. If you see Rego compilation errors, the violation rules in the template have a syntax issue - the output includes the line number and a description of the error.

## Testing and Validation

Testing admission controller policies is where most teams skip a step and end up surprised in production. There are two things to validate: that a compliant pod is allowed, and that a non-compliant pod is denied with the right message.

### Test a Compliant Pod

Create a pod that sets all required fields:

{% highlight yaml %}
# compliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: policy-test-compliant
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "250m"
          memory: "256Mi"
{% endhighlight %}

{% highlight bash %}
kubectl apply -f compliant-pod.yaml
{% endhighlight %}

This should succeed. Verify the pod is running:

{% highlight bash %}
kubectl get pod policy-test-compliant
{% endhighlight %}

### Test a Non-Compliant Pod

Now create a pod missing resource limits entirely:

{% highlight yaml %}
# noncompliant-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: policy-test-noncompliant
  namespace: default
spec:
  containers:
    - name: app
      image: nginx:1.27
{% endhighlight %}

{% highlight bash %}
kubectl apply -f noncompliant-pod.yaml
{% endhighlight %}

You should see a response like this:

```
Error from server (Forbidden): error when creating "noncompliant-pod.yaml": admission webhook
"validation.gatekeeper.sh" denied the request: [require-resource-limits] container <app> is
missing resources.limits.memory; [require-resource-limits] container <app> is missing
resources.limits.cpu; [require-resource-limits] container <app> is missing
resources.requests.memory; [require-resource-limits] container <app> is missing
resources.requests.cpu
```

Four violation messages, one per missing field. The developer knows exactly what to add.

### Checking Audit Violations

Gatekeeper's audit component scans existing resources on a schedule and records violations on the constraint object. To see violations for objects that already existed before the policy was applied:

{% highlight bash %}
kubectl get k8srequireresourcelimits require-resource-limits -o jsonpath='{.status.violations}' | jq .
{% endhighlight %}

Each entry in the violations list includes the resource name, namespace, and the violation message. This gives you visibility into policy drift on existing workloads without having to re-admit every object.

Clean up the test pod after validation:

{% highlight bash %}
kubectl delete pod policy-test-compliant
{% endhighlight %}

## Best Practices

**Roll out new policies with `enforcementAction: warn` first.** Switching directly to `deny` on a new policy in a running cluster will reject legitimate workloads that predate the policy. Use `warn` to surface violations in the API response without blocking anything, let the audit scan identify all affected workloads, fix them, and then change to `deny`. The rollout looks like: `dryrun` (audit only) -> `warn` (visible but non-blocking) -> `deny` (enforcing).

**Exclude system namespaces explicitly.** Always add `kube-system`, `gatekeeper-system`, and any monitoring or logging namespace to `excludedNamespaces`. Infrastructure controllers deployed by your cloud provider or by Helm may not comply with your resource policy by design, and blocking them during an upgrade will cause real problems.

**Set `failurePolicy: Fail` once Gatekeeper is stable.** The `Ignore` setting we used during installation means that if Gatekeeper's pods go down, all admission checks are skipped. For a security policy, that is not acceptable in production. Once you have confirmed Gatekeeper is running reliably with at least two replicas, change the webhook `failurePolicy` to `Fail`. Add Gatekeeper availability to your cluster monitoring.

**Test Rego locally with the OPA CLI before applying to the cluster.** The OPA command-line tool can evaluate Rego against a JSON input file without touching Kubernetes. This makes the development loop much faster than applying a ConstraintTemplate, waiting for it to compile, and testing with `kubectl`:

{% highlight bash %}
# Install OPA CLI
brew install opa

# Evaluate a policy against a test input
opa eval --input test-input.json --data policy.rego "data.k8srequireresourcelimits.violation"
{% endhighlight %}

The `test-input.json` file should contain the same structure as a real `AdmissionReview` request, with the pod manifest nested under `review.object`.

**Pin your Gatekeeper version and review the changelog on upgrades.** Gatekeeper has changed its CRD API versions across releases. Upgrading without reading the migration guide can leave existing constraints in a broken state. The `3.x` release series is stable, but minor version upgrades sometimes introduce new required fields in the `ConstraintTemplate` spec.

## Conclusion

OPA Gatekeeper gives you a policy enforcement layer that operates before objects reach etcd, catching configuration problems at admission time rather than discovering them through runtime incidents or manual audits. The model is straightforward: a `ConstraintTemplate` holds the Rego logic, a `Constraint` applies it to specific resource types and namespaces, and the audit component continuously re-evaluates your existing workloads against the policies you define.

The resource limits policy we built is one of the most impactful policies you can deploy - it eliminates an entire class of noisy neighbor incidents. From here you can extend the same pattern to enforce image pull policies, block privileged containers, require specific labels, or validate that images come only from approved registries. Each new policy follows the same two-file structure: one template, one constraint.

Start with `enforcementAction: warn`, let the audit surface what is out of compliance, fix it, then switch to `deny`. That sequence gets you from zero enforcement to full enforcement without a surprise 2 AM incident.

Happy scripting!
