---
title: "Flux CD: GitOps continuous delivery for Kubernetes workloads"
author: Victor Silva
date: 2025-02-10T22:47:08+00:00
layout: post
permalink: /fluxcd-gitops-kubernetes/
excerpt: "If ArgoCD is the GitOps tool with a UI, Flux is the one that lives entirely in the cluster and in your Git history. This post walks through bootstrapping Flux to a GitHub repository, declaring sources and Kustomizations, deploying a sample app by pushing to Git, and setting up image update automation."
categories:
  - IaC & GitOps
tags:
  - fluxcd
  - gitops
  - kubernetes
  - cncf
  - continuous-delivery
  - flux
---

You push a manifest change to your Git repository and then... something has to take it from there. In teams without GitOps tooling, that something is a human running `kubectl apply`, a CI pipeline calling `helm upgrade`, or worse, both — depending on who got to it first. The result is a cluster whose live state exists somewhere between several partial deployments and nobody's sure which commit it reflects.

Flux solves this by turning the cluster itself into the consumer of your Git repository. There is no pipeline step that pushes to the cluster. Instead, Flux runs inside the cluster, watches your repository, and continuously reconciles the live state toward whatever Git says should be there. Every deployment is a Git commit. Every rollback is a `git revert`. No one needs kubectl access to trigger a release.

Flux is a CNCF graduated project, meaning it has the maturity, community, and API stability required for production adoption. This post covers installing the Flux CLI, bootstrapping Flux to a GitHub repository, declaring a `GitRepository` source and a `Kustomization`, deploying a sample application by pushing to Git, watching the reconciliation loop, and introducing image update automation.

## How Flux Differs from ArgoCD

If you have read the ArgoCD post on this blog, the pull-based model is familiar. Flux and ArgoCD both watch Git and reconcile toward desired state. The differences are architectural and in how they expose themselves to operators.

Flux has **no built-in web UI**. Everything is managed through the `flux` CLI and Kubernetes custom resources. This is not a limitation — it is a deliberate design choice that keeps Flux lightweight and fits naturally into a "everything is YAML in Git" workflow. The cluster is the source of truth; you inspect it with `flux get` and `kubectl`.

Flux uses a **source-then-reconcile model**. You declare a `GitRepository` resource that defines where to pull from, and separately declare a `Kustomization` (or `HelmRelease`) that defines what to apply and where. This separation means multiple workloads can share a single source, or one workload can pull from multiple sources. ArgoCD bundles these concepts into a single `Application` resource.

Flux also ships **image update automation** as a first-class feature set. You can configure Flux to watch a container registry for new image tags, update the tag in your Git repository automatically, and then reconcile the cluster from the updated commit. This closes the loop without any external tooling.

The data flow looks like this:

```
Git repository
      |
  source-controller
  (clones repo, serves artifacts)
      |
  kustomize-controller
  (renders and applies manifests)
      |
  Kubernetes API Server
      |
  Running workloads

  image-reflector-controller  <-- watches container registry
      |
  image-automation-controller <-- commits updated image tags to Git
```

Each controller is a separate deployment. This is another architectural difference from ArgoCD: Flux is a set of composable controllers rather than a monolithic server.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.26 or higher (`kubectl version`)
- `kubectl` configured and pointing at the target cluster
- The `flux` CLI installed locally
- A GitHub account and a personal access token (PAT) with `repo` scope
- A GitHub repository where Flux will store its configuration (can be empty to start)

Verify your cluster is reachable:

{% highlight bash %}
kubectl cluster-info
kubectl get nodes
{% endhighlight %}

Install the `flux` CLI on macOS:

{% highlight bash %}
brew install fluxcd/tap/flux
{% endhighlight %}

On Linux, download the binary directly:

{% highlight bash %}
curl -s https://fluxcd.io/install.sh | sudo bash
{% endhighlight %}

Confirm the CLI is available and check what version you have:

{% highlight bash %}
flux --version
{% endhighlight %}

Flux ships a pre-flight check that validates cluster compatibility before you install anything. Run it now and fix any reported issues before proceeding:

{% highlight bash %}
flux check --pre
{% endhighlight %}

The check covers API server version, available CRD support, and namespace limits. It is quick and saves you from debugging a broken bootstrap later.

## Bootstrapping Flux to GitHub

Bootstrapping does three things at once: it installs the Flux controllers into your cluster, creates a Git repository (or uses an existing one) to store the Flux system configuration, and commits the controller manifests to that repository so Flux manages its own installation from that point forward.

Export your GitHub credentials:

{% highlight bash %}
export GITHUB_TOKEN=ghp_your_token_here
export GITHUB_USER=your-github-username
{% endhighlight %}

Run the bootstrap command:

{% highlight bash %}
flux bootstrap github \
  --owner=${GITHUB_USER} \
  --repository=fleet-infra \
  --branch=main \
  --path=clusters/my-cluster \
  --personal
{% endhighlight %}

Breaking down the flags: `--repository` is the name of the GitHub repository Flux will use (it will be created if it does not exist). `--path` is the directory within that repository where Flux will write the controller manifests. `--personal` indicates this is a personal account rather than an organization.

The bootstrap process creates a deploy key on the repository, commits the Flux controller manifests under `clusters/my-cluster/flux-system/`, and installs the controllers in the `flux-system` namespace. When it finishes, the cluster is already reconciling from that path.

Verify the controllers are running:

{% highlight bash %}
kubectl get pods -n flux-system
{% endhighlight %}

You should see pods for `source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`, and `image-reflector-controller`. All should reach Running state within a minute.

Check that Flux itself is healthy:

{% highlight bash %}
flux check
{% endhighlight %}

A clean output with all components reporting ready means Flux is fully operational.

## Declaring a GitRepository Source

Now that Flux is running, you can point it at any Git repository that holds your application manifests. This is separate from the `fleet-infra` bootstrap repository — in a real setup you typically have one bootstrap repo for Flux configuration and separate repos (or paths within the same repo) for each application team.

For this walkthrough, create a directory structure in your `fleet-infra` repository that holds a sample application:

{% highlight bash %}
# Clone the fleet-infra repo Flux created
git clone https://github.com/${GITHUB_USER}/fleet-infra
cd fleet-infra
{% endhighlight %}

Create a `GitRepository` resource that tells Flux where to find your application manifests. Here we point it back at the same `fleet-infra` repository, but at a different path:

{% highlight yaml %}
# clusters/my-cluster/sample-app-source.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: sample-app
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/your-github-username/fleet-infra
  ref:
    branch: main
  secretRef:
    name: flux-system
{% endhighlight %}

`interval: 1m` tells source-controller to poll the repository every minute and fetch new commits. For production workloads you might use `5m` or longer, and complement it with a webhook receiver so pushes trigger an immediate reconciliation. The `secretRef` points to the deploy key secret that bootstrap created.

Add the file, commit, and push:

{% highlight bash %}
git add clusters/my-cluster/sample-app-source.yaml
git commit -m "add sample-app GitRepository source"
git push
{% endhighlight %}

Flux detects the new commit within one minute and applies the `GitRepository` resource. Check it:

{% highlight bash %}
flux get sources git
{% endhighlight %}

The output should show `sample-app` with `READY: True` and the latest commit SHA from your repository. If it shows `False`, `flux describe source git sample-app` gives you the full error including auth failures and unreachable URLs.

## Declaring a Kustomization

A `GitRepository` tells Flux where to pull from. A `Kustomization` tells it what to apply and to which cluster. Create the sample application manifests first:

{% highlight bash %}
mkdir -p apps/sample-app
{% endhighlight %}

{% highlight yaml %}
# apps/sample-app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
        - name: app
          image: nginx:1.25.3
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: sample-app
spec:
  selector:
    app: sample-app
  ports:
    - port: 80
      targetPort: 80
{% endhighlight %}

{% highlight yaml %}
# apps/sample-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
{% endhighlight %}

Now create the Flux `Kustomization` resource that wires the source to these manifests:

{% highlight yaml %}
# clusters/my-cluster/sample-app-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: sample-app
  namespace: flux-system
spec:
  interval: 5m
  path: ./apps/sample-app
  prune: true
  sourceRef:
    kind: GitRepository
    name: sample-app
  targetNamespace: sample-app
  postBuild:
    substituteFrom: []
{% endhighlight %}

`path: ./apps/sample-app` is the directory within the `GitRepository` that Flux will pass through Kustomize and apply. `prune: true` tells Flux to delete cluster resources that are removed from Git — the same semantics as ArgoCD's prune flag. `targetNamespace` overrides the namespace for all resources in the path, which is useful when you want to keep namespace declarations out of the individual manifests.

One thing that is missing: the `sample-app` namespace itself. Flux will fail to apply the Deployment if the namespace does not exist. Add a namespace manifest:

{% highlight yaml %}
# apps/sample-app/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sample-app
{% endhighlight %}

Update `apps/sample-app/kustomization.yaml` to include it:

{% highlight yaml %}
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
{% endhighlight %}

Commit everything and push:

{% highlight bash %}
git add apps/ clusters/my-cluster/sample-app-kustomization.yaml
git commit -m "add sample-app manifests and Kustomization"
git push
{% endhighlight %}

## Watching the Reconciliation Loop

This is where GitOps becomes concrete. Flux picks up the commit and begins reconciling within the next poll interval. You can force an immediate reconciliation without waiting:

{% highlight bash %}
flux reconcile source git sample-app
flux reconcile kustomization sample-app
{% endhighlight %}

Watch the Kustomization status:

{% highlight bash %}
flux get kustomizations --watch
{% endhighlight %}

You will see the status move through `Reconciling` to `Applied revision: main/abc1234`. Once it shows `Ready: True`, the resources are live in the cluster. Confirm:

{% highlight bash %}
kubectl get all -n sample-app
{% endhighlight %}

You should see the Deployment, ReplicaSet, two Pods, and the Service all running.

Now trigger a change the GitOps way. Update the replica count in `apps/sample-app/deployment.yaml`:

{% highlight yaml %}
  replicas: 3
{% endhighlight %}

Commit and push:

{% highlight bash %}
git add apps/sample-app/deployment.yaml
git commit -m "scale sample-app to 3 replicas"
git push
{% endhighlight %}

Force a reconciliation and watch:

{% highlight bash %}
flux reconcile kustomization sample-app --with-source
kubectl get pods -n sample-app -w
{% endhighlight %}

A third pod appears. The Git commit is the deployment. No `kubectl scale`, no pipeline step, no manual `helm upgrade`. Git is the interface.

## Image Update Automation

One operational pattern that Flux handles natively is keeping image tags in Git synchronized with what is available in your container registry. Instead of updating the image tag in your manifests manually and pushing a commit, Flux watches the registry and commits the update for you.

This requires two additional controllers — `image-reflector-controller` and `image-automation-controller` — which bootstrap installs by default.

First, create an `ImageRepository` that tells Flux which registry image to watch:

{% highlight yaml %}
# clusters/my-cluster/sample-app-image.yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageRepository
metadata:
  name: sample-app
  namespace: flux-system
spec:
  image: nginx
  interval: 5m
{% endhighlight %}

Next, create an `ImagePolicy` that defines which tag to select. This policy picks the latest stable semantic version from the `1.25.x` series:

{% highlight yaml %}
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImagePolicy
metadata:
  name: sample-app
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: sample-app
  policy:
    semver:
      range: ">=1.25.0 <1.26.0"
{% endhighlight %}

Add a marker comment to the image field in your Deployment so Flux knows which line to update when the policy selects a new tag:

{% highlight yaml %}
          image: nginx:1.25.3 # {"$imagepolicy": "flux-system:sample-app"}
{% endhighlight %}

Finally, create an `ImageUpdateAutomation` resource that commits the updated tag back to Git:

{% highlight yaml %}
# clusters/my-cluster/sample-app-image-update.yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: sample-app
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: sample-app
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@users.noreply.github.com
      messageTemplate: "chore: update image to {% raw %}{{range .Updated.Images}}{{.}}{{end}}{% endraw %}"
    push:
      branch: main
  update:
    path: ./apps/sample-app
    strategy: Setters
{% endhighlight %}

When Flux detects a new nginx `1.25.x` tag in the registry, it updates the marker comment line in `deployment.yaml`, commits that change to your repository, and the normal reconciliation loop picks it up from there. You get an automated, auditable image promotion with a Git commit as the artifact.

## Testing and Validation

Confirm the full chain is healthy with a single command:

{% highlight bash %}
flux get all -n flux-system
{% endhighlight %}

This lists every Flux object — sources, kustomizations, image repositories, and policies — along with their ready status and last applied revision. Everything should show `READY: True`.

To trace a specific reconciliation and see what Flux applied, use:

{% highlight bash %}
flux events --for Kustomization/sample-app
{% endhighlight %}

This shows the event log for the `sample-app` Kustomization including detection timestamps, applied revisions, and any errors. It is the first command to run when a deployment does not appear to have happened.

Check the diff between what Flux applied and what is currently live:

{% highlight bash %}
flux diff kustomization sample-app
{% endhighlight %}

An empty diff means the cluster matches Git exactly. Any drift shows here as a unified diff, which is useful when someone has made a manual change to the cluster outside of Git.

To deliberately test the reconciliation loop, scale the deployment directly and watch Flux undo it:

{% highlight bash %}
kubectl scale deployment sample-app -n sample-app --replicas=1
flux reconcile kustomization sample-app
kubectl get deployment sample-app -n sample-app
{% endhighlight %}

The replica count returns to whatever is declared in Git. That is `prune` and self-healing working together: Git is always right, and Flux enforces it on every reconciliation cycle.

## Best Practices

**Store your Kustomization files in Git alongside the bootstrap config.** The `clusters/my-cluster/` path that bootstrap created is the right place for all Flux `GitRepository`, `Kustomization`, and `HelmRelease` resources. When you point Flux at this path, it picks up all new resources automatically without any imperative commands. Adding a new application becomes a `git push`.

**Use `interval` values that match your release cadence.** A 1-minute poll interval on a busy cluster creates a constant stream of Git API requests. For workloads that deploy multiple times per day, set `interval: 5m` and add a webhook receiver to trigger immediate reconciliation on push. For workloads that release weekly, `interval: 10m` is fine and substantially reduces noise.

**Pin image tags in production and use `ImagePolicy` with a narrow range.** Tracking `latest` is a well-known footgun. With Flux image automation, you can allow Flux to promote patch versions automatically within a semver range like `>=1.25.0 <1.26.0` while requiring a manual Git change to move to a new minor version. This gives you automated patch updates without accidental major version promotions.

**Separate your bootstrap repository from your application repositories.** The `fleet-infra` repository Flux manages contains operational configuration: which clusters exist, which applications each cluster runs, and how they are deployed. Application source manifests belong in the application teams' own repositories. This separation keeps the blast radius of a misconfiguration small and gives teams ownership over their deployment configuration.

**Use `flux suspend` and `flux resume` for maintenance windows.** When you need to make manual cluster changes without Flux immediately reconciling them away, suspend the relevant Kustomization:

{% highlight bash %}
flux suspend kustomization sample-app
# ... make your manual changes ...
flux resume kustomization sample-app
{% endhighlight %}

This is safer than deleting the resource, because the Kustomization state is preserved and reconciliation resumes cleanly. Document any suspended reconciliations so they do not get forgotten.

**Enable Flux notifications for your team.** The `notification-controller` that ships with Flux can send alerts to Slack, Microsoft Teams, PagerDuty, and generic webhooks when a reconciliation succeeds or fails. A simple `Provider` and `Alert` resource in your bootstrap path is enough to get deployment notifications into your team channel, making the GitOps feedback loop visible without anyone polling `flux get kustomizations` manually.

## Conclusion

Flux turns your Kubernetes cluster into a pull-based consumer of Git, which means deployments are auditable by definition, rollbacks are `git revert`, and no individual has the ability to deploy without leaving a trace in version control. The architecture — separate source and reconciliation controllers, no UI, native image automation — makes it a natural fit for teams that already live in the terminal and want their GitOps tooling to stay out of the way.

The setup in this post covers the full operational loop: bootstrap, source declaration, Kustomization, a live deployment triggered by a Git push, and image tag automation. From here, the interesting work is structuring your multi-cluster bootstrap paths, using `HelmRelease` resources to manage Helm-packaged applications, and wiring notification alerts into your incident workflow.

Push one manifest change, watch Flux apply it, and trust that what is in Git is what is running. That confidence compounds over time.

Happy scripting!
