---
title: "GitOps with ArgoCD: deploying to Kubernetes from a Git repo"
author: Victor Silva
date: 2024-08-12T22:15:53+00:00
layout: post
permalink: /gitops-argocd-kubernetes/
excerpt: "Manually applying kubectl manifests to a cluster is a change management problem waiting to happen. ArgoCD turns your Git repository into the single source of truth for cluster state, giving you auditable, automated deployments without writing a single CI pipeline step. This post walks through installing ArgoCD, connecting a repo, and syncing your first Application."
categories:
  - IaC & GitOps
tags:
  - argocd
  - gitops
  - kubernetes
  - cncf
  - continuous-delivery
---

You have Kubernetes manifests in a Git repository. Deploying them looks like this: someone runs `kubectl apply -f ./manifests`, watches for errors, and hopes the cluster reflects what is in Git. Then a colleague makes a hotfix directly against the cluster with `kubectl edit`. Then someone else applies an older version of the manifests from their local machine. Three days later, nobody agrees on what is actually running, and the Git history is only one version of the truth.

This is the drift problem that GitOps solves, and ArgoCD is the tool that makes GitOps concrete. ArgoCD continuously compares the desired state in your Git repository against the live state in your cluster. When they diverge, it either alerts you or reconciles automatically. Every change to the cluster is traceable to a Git commit, every rollback is a `git revert`, and no one needs cluster credentials to trigger a deployment.

ArgoCD is a CNCF graduated project, which means it has passed the maturity requirements for production adoption, has a large adopter community, and has a stable, maintained API. This post walks through installing it, connecting a Git repository, declaring an Application resource, and validating the sync loop end to end.

## How ArgoCD Works

Before touching a cluster, it is worth understanding the three things ArgoCD does and which component does each.

**Desired state** lives in Git. ArgoCD supports plain Kubernetes manifests, Helm charts, Kustomize overlays, and a few other config management tools. You point ArgoCD at a repo path and a target revision (a branch, tag, or commit SHA), and that becomes the definition of what should exist in the cluster.

**Live state** is what ArgoCD reads from the Kubernetes API server. It tracks every resource that belongs to an Application and knows their current spec and status.

**Reconciliation** is the sync loop. ArgoCD's Application Controller runs inside the cluster and polls both sources. When the desired and live states differ, the Application moves to an `OutOfSync` status. You can configure ArgoCD to sync automatically or leave it manual. Either way, the delta is always visible in the UI and CLI.

The data flow looks like this:

```
Git repository (desired state)
         |
  ArgoCD repo-server
  (clones repo, renders manifests)
         |
  Application Controller
  (compares desired vs. live state)
         |
  Kubernetes API Server
  (apply or report OutOfSync)
         |
  Running workloads
```

One component worth knowing separately is the **API Server**. This is the ArgoCD gRPC/REST API that both the web UI and the `argocd` CLI talk to. When you trigger a sync manually, create an Application, or manage RBAC, you are going through the API Server. The Application Controller is the one that actually calls `kubectl` internally.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.25 or higher (`kubectl version --short`)
- `kubectl` configured and pointing at the target cluster
- The `argocd` CLI installed locally
- A Git repository (public or private) containing Kubernetes manifests

Verify your cluster is reachable before proceeding:

{% highlight bash %}
kubectl cluster-info
kubectl get nodes
{% endhighlight %}

Install the `argocd` CLI on macOS:

{% highlight bash %}
brew install argocd
{% endhighlight %}

On Linux, download the binary directly:

{% highlight bash %}
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
{% endhighlight %}

Confirm the CLI is available:

{% highlight bash %}
argocd version --client
{% endhighlight %}

## Installing ArgoCD

ArgoCD ships as a set of Kubernetes manifests maintained in its own repository. The recommended approach for anything beyond a quick demo is to manage the install declaratively with a Kustomize overlay or Helm chart, but for this walkthrough the upstream install manifest gets us running quickly.

Create the namespace and apply the install manifest:

{% highlight bash %}
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/install.yaml
{% endhighlight %}

Wait for all components to reach Running state:

{% highlight bash %}
kubectl rollout status deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-repo-server -n argocd
kubectl rollout status deployment/argocd-application-controller -n argocd
{% endhighlight %}

This typically takes under a minute on a cluster with a fast node. Once all three rollouts report success, the API Server is ready.

### Accessing the Web UI

The ArgoCD server service is a `ClusterIP` by default. For local access, use a port-forward:

{% highlight bash %}
kubectl port-forward svc/argocd-server -n argocd 8080:443
{% endhighlight %}

Open `https://localhost:8080` in your browser. You will see a self-signed certificate warning — accept it for now. In production you would configure a proper Ingress with a valid certificate.

### Initial Login

The initial admin password is stored as a Kubernetes Secret. Retrieve it:

{% highlight bash %}
argocd admin initial-password -n argocd
{% endhighlight %}

Log in with the CLI (this also authenticates your `argocd` session for all subsequent commands in this post):

{% highlight bash %}
argocd login localhost:8080 \
  --username admin \
  --password $(argocd admin initial-password -n argocd | head -1) \
  --insecure
{% endhighlight %}

The `--insecure` flag skips TLS verification against the self-signed cert. Remove it once you have a valid certificate. After logging in, change the default password immediately:

{% highlight bash %}
argocd account update-password
{% endhighlight %}

## Connecting a Git Repository

If your repository is public, ArgoCD can clone it without any additional configuration. If it is private, you need to register credentials.

For a private repository using an SSH key, add the repo with:

{% highlight bash %}
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/id_ed25519
{% endhighlight %}

For HTTPS with a personal access token:

{% highlight bash %}
argocd repo add https://github.com/your-org/your-repo.git \
  --username your-github-username \
  --password your-personal-access-token
{% endhighlight %}

Verify the repository was added and is reachable:

{% highlight bash %}
argocd repo list
{% endhighlight %}

The output should show `CONNECTION STATUS: Successful` next to your repository URL. If it shows `Failed`, the most common causes are an incorrect URL, an expired token, or the key not being added to the repository's deploy keys.

## Creating an Application Resource

This is where GitOps starts. An `Application` is the ArgoCD custom resource that links a Git source to a Kubernetes destination. You can create one imperatively with the CLI or declaratively with a YAML manifest. Use the YAML approach — it means your ArgoCD configuration is itself tracked in Git.

Here is a complete Application manifest for a sample deployment:

{% highlight yaml %}
# argocd-app-sample.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sample-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo.git
    targetRevision: main
    path: manifests/sample-app
  destination:
    server: https://kubernetes.default.svc
    namespace: sample-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
{% endhighlight %}

A few fields to understand here.

`targetRevision: main` tells ArgoCD to track the `main` branch. You can also pin to a specific tag or commit SHA, which is worth doing for production Applications where you do not want HEAD to deploy automatically.

`path: manifests/sample-app` is the directory within the repository that ArgoCD will render. Everything under this path that produces valid Kubernetes YAML will be applied.

`destination.server: https://kubernetes.default.svc` targets the same cluster where ArgoCD is installed. For multi-cluster setups you register external clusters and use their API server URL here.

`syncPolicy.automated` enables the automatic sync loop. `prune: true` means ArgoCD will delete resources from the cluster that no longer exist in Git. `selfHeal: true` means manual changes made directly to the cluster — via `kubectl edit` or a hotfix — will be overwritten by the next sync. This is the enforcement mechanism that makes GitOps meaningful: Git is always right.

`CreateNamespace=true` under `syncOptions` lets ArgoCD create the destination namespace if it does not already exist, so you do not need to pre-create it.

Apply the Application:

{% highlight bash %}
kubectl apply -f argocd-app-sample.yaml
{% endhighlight %}

## Syncing and Observing

Once the Application is created, ArgoCD begins its reconciliation loop. Check the initial status:

{% highlight bash %}
argocd app get sample-app
{% endhighlight %}

The output shows the sync status, health status, and a list of resources the Application manages. If everything in the cluster matches Git, you will see:

```
Sync Status:   Synced to main (abc1234)
Health Status: Healthy
```

If resources are missing or differ from Git, the sync status will be `OutOfSync`. Trigger a manual sync with:

{% highlight bash %}
argocd app sync sample-app
{% endhighlight %}

Watch the sync progress in real time:

{% highlight bash %}
argocd app wait sample-app --sync --health --timeout 120
{% endhighlight %}

This command blocks until the Application reaches `Synced` and `Healthy` or the timeout expires. It is the right command to use at the end of a CI pipeline that pushes a manifest change and needs to confirm the deployment completed.

To see the full list of resources ArgoCD is managing and their individual health:

{% highlight bash %}
argocd app resources sample-app
{% endhighlight %}

In the web UI at `https://localhost:8080`, the Application appears as a graph showing every Kubernetes resource (Deployments, Services, ReplicaSets, Pods) and their sync and health status. This visualization is one of the most immediately useful things about ArgoCD for operators who need to understand what changed and when.

To simulate the drift scenario from the introduction, make a direct change to a resource ArgoCD manages:

{% highlight bash %}
kubectl scale deployment sample-app -n sample-app --replicas=5
{% endhighlight %}

With `selfHeal: true`, ArgoCD will detect the drift within a few seconds and reconcile the replica count back to whatever is declared in Git. Watch it happen:

{% highlight bash %}
argocd app get sample-app --watch
{% endhighlight %}

## Basic RBAC

By default, ArgoCD ships with two roles: `role:readonly` for viewing Applications and `role:admin` for full control. You assign users or groups to these roles via a `ConfigMap` in the `argocd` namespace.

Here is a practical RBAC configuration that gives a `developers` group read access and the ability to trigger syncs, while restricting application creation and deletion to admins:

{% highlight yaml %}
# argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, list, */*, allow
    p, role:developer, logs, get, */*, allow
    g, your-org:developers, role:developer
  scopes: '[groups]'
{% endhighlight %}

`policy.default: role:readonly` sets the fallback role for any authenticated user who does not match a more specific rule. This is the safe default: you can see everything but change nothing.

The `policy.csv` block uses ArgoCD's Casbin policy format. Each `p` line is a permission grant: `p, <role>, <resource>, <action>, <scope>, allow`. The `g` line assigns the `your-org:developers` group (coming from your SSO provider) to the `role:developer` role.

Apply it:

{% highlight bash %}
kubectl apply -f argocd-rbac-cm.yaml
{% endhighlight %}

RBAC changes take effect immediately — no pod restarts required. Verify by logging in as a user in the developers group and confirming they can sync but cannot delete Applications.

## Testing and Validation

Start by confirming ArgoCD picked up your repository and rendered the manifests correctly without applying anything:

{% highlight bash %}
argocd app diff sample-app
{% endhighlight %}

This shows a unified diff between the desired state (rendered from Git) and the live state (from the Kubernetes API). An empty output means the two are in sync. Output with additions means resources in Git are not yet in the cluster. Output with deletions means resources exist in the cluster that are not in Git — these would be pruned on the next sync if `prune: true` is set.

Check the sync history to confirm deployments are being recorded:

{% highlight bash %}
argocd app history sample-app
{% endhighlight %}

Each entry shows the Git commit SHA, the deploy timestamp, and who triggered the sync. This is your audit trail.

To verify automated sync is working end to end, push a manifest change to your repository and watch ArgoCD detect and apply it:

{% highlight bash %}
# In your manifests repo, update an image tag or replica count and push
git commit -m "bump sample-app to v1.2.0"
git push origin main

# Back in the terminal watching ArgoCD
argocd app get sample-app --watch
{% endhighlight %}

Within the refresh interval (default 3 minutes, configurable down to 5 seconds with `--refresh-interval`) you will see the sync status move from `Synced` to `OutOfSync` and back to `Synced` as ArgoCD detects the new commit and applies the change.

## Best Practices

**Store your Application manifests in Git.** The `argocd-app-sample.yaml` you created above should live in a repository, just like your workload manifests. This is the "app of apps" pattern: a dedicated ArgoCD Application that watches a repository of Application definitions and creates or updates them automatically. It means your entire ArgoCD configuration is version-controlled and recoverable.

**Pin `targetRevision` to tags in production.** Tracking a branch means any push to that branch triggers a deployment. For production workloads, use `targetRevision: v1.2.0` and update the tag deliberately after testing in a lower environment. This gives you an explicit promotion step and makes rollback trivial: change the tag in Git and let ArgoCD reconcile.

**Enable `prune` only after you understand what it removes.** With `prune: true`, deleting a manifest from Git deletes the corresponding resource from the cluster. This is the correct behavior for GitOps, but it surprises teams the first time it removes a resource they forgot was defined in a file they deleted. Run `argocd app diff` before enabling prune to understand what would be removed on the next sync.

**Use Projects to isolate teams.** The `default` project in ArgoCD has no restrictions. For a multi-team cluster, create an `AppProject` for each team that scopes which repositories, destination namespaces, and resource kinds their Applications can use. This prevents one team's ArgoCD Application from accidentally deploying into another team's namespace.

{% highlight yaml %}
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/your-org/team-a-repo.git
  destinations:
    - namespace: team-a-*
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
{% endhighlight %}

**Set resource health checks for custom resources.** ArgoCD has built-in health logic for core Kubernetes resources (Deployments, StatefulSets, Services), but if your manifests include CRDs from other operators, ArgoCD will mark those resources as `Unknown` health. You can add custom health check Lua scripts in the `argocd-cm` ConfigMap to teach ArgoCD how to evaluate the health of any resource type.

**Avoid storing secrets in Git.** ArgoCD syncs whatever is in your repository. Plaintext secrets in manifests are a serious security issue. Use Sealed Secrets, External Secrets Operator, or a Vault integration to manage sensitive values outside of Git and inject them at sync time.

## Conclusion

ArgoCD turns the question "what is deployed in this cluster?" into a question you answer by reading Git. The sync loop is always running, drift is always visible, and every change has an author and a commit hash attached to it. That alone removes a whole category of production incidents.

The setup in this post — ArgoCD installed in its own namespace, a private repository connected, an Application resource with automated sync and self-healing, and basic RBAC — is a foundation you can build on. From here, the interesting work is structuring your manifest repositories (mono-repo versus per-service), setting up ApplicationSets to template Applications across environments, and integrating ArgoCD notifications with Slack or your incident tooling.

Start with one application, let it run for a sprint, and pay attention to the sync history. You will quickly develop an intuition for how to structure your manifests to make GitOps feel effortless rather than rigid.

Happy scripting!
