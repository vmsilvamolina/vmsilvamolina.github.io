---
title: "Crossplane: managing cloud infrastructure as Kubernetes resources"
author: Victor Silva
date: 2025-06-09T21:28:46+00:00
layout: post
permalink: /crossplane-cloud-infrastructure-kubernetes/
excerpt: "If you already live in Kubernetes, why switch tools to provision cloud infrastructure? Crossplane extends the Kubernetes API to manage Azure, AWS, and GCP resources through the same kubectl workflow and reconciliation loop you already know. This post walks through installing Crossplane, configuring the Azure provider, and provisioning real cloud infrastructure via Kubernetes manifests."
categories:
  - IaC & GitOps
tags:
  - crossplane
  - kubernetes
  - infrastructure-as-code
  - cncf
  - azure
  - gitops
---

If you are already running workloads on Kubernetes, you have two separate operational surfaces to manage: the cluster itself and the cloud infrastructure it depends on — storage accounts, databases, virtual networks, managed identities. Most teams reach for Terraform for the latter. That works, but it introduces a second state backend, a second pipeline, a second set of credentials to manage, and a second conceptual model to hold in your head. When something breaks at 2 AM, you are context-switching between `kubectl` and `terraform` trying to understand which layer the problem is in.

Crossplane offers a different model: extend the Kubernetes API itself to manage cloud infrastructure. Instead of running `terraform apply`, you `kubectl apply` a manifest describing an Azure Storage Account. Kubernetes reconciles it. The resource appears in Azure. If someone modifies it out of band, the reconciliation loop brings it back to the desired state. The entire infrastructure lifecycle — create, update, delete — is driven by YAML manifests and Kubernetes controllers.

Crossplane is a CNCF graduated project, which means it has completed the maturity process for production adoption, has a large and active adopter community, and maintains a stable API surface. This post walks through installing Crossplane via Helm, configuring the Azure provider, and provisioning an Azure Resource Group and Storage Account using Crossplane Managed Resources.

## How Crossplane Works

Before touching a cluster, it helps to understand how Crossplane maps cloud infrastructure concepts onto Kubernetes.

**Providers** are the bridge between Kubernetes and a cloud platform. A Provider is itself a Kubernetes deployment — a controller — that knows how to talk to a specific cloud API. `provider-azure` knows the Azure Resource Manager API. `provider-aws` knows the AWS API. You install a Provider the same way you install any Kubernetes operator: by applying a manifest. The Provider installs its own CRDs, which are the resource types you will later instantiate.

**Managed Resources** are instances of those CRDs. When you apply a manifest with `kind: ResourceGroup` from the `azure.upbound.io` API group, Crossplane's Azure provider creates the corresponding Azure Resource Group and keeps it reconciled. The managed resource object in Kubernetes holds the spec (desired state) and the status (observed state, including the external resource's ID and any conditions).

**ProviderConfig** holds the authentication configuration that the Provider uses to call the cloud API. For Azure, this means a reference to a Kubernetes Secret containing service principal credentials or workload identity configuration.

The reconciliation flow looks like this:

```
kubectl apply -f resourcegroup.yaml
        |
   kube-apiserver
        |
   Crossplane Provider controller
   (watches Managed Resource objects)
        |
   Cloud API (e.g. Azure Resource Manager)
        |
   Resource created / updated / observed
        |
   Status written back to Managed Resource object
```

This is the same controller pattern every Kubernetes operator uses. Crossplane is not inventing a new model — it is applying the model you already know to cloud infrastructure.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.27 or higher
- `kubectl` configured and pointing at the target cluster
- Helm 3 installed
- An Azure subscription and a service principal with Contributor access
- The Azure CLI installed locally for credential setup

Verify your cluster access and Helm installation:

{% highlight bash %}
kubectl cluster-info
kubectl get nodes
helm version --short
{% endhighlight %}

If you do not have a service principal yet, create one now and note the output — you will need it shortly:

{% highlight bash %}
az ad sp create-for-rbac \
  --name crossplane-provider-sp \
  --role Contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --output json
{% endhighlight %}

## Installing Crossplane

Crossplane ships as a Helm chart from its own repository. Add the Upbound stable chart repository and install:

{% highlight bash %}
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update
{% endhighlight %}

Install Crossplane into its own namespace:

{% highlight bash %}
helm upgrade --install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 1.16.0 \
  --wait
{% endhighlight %}

The `--wait` flag blocks until all Crossplane pods reach the Running state. Once the command returns, verify:

{% highlight bash %}
kubectl get pods -n crossplane-system
{% endhighlight %}

You should see two pods running: `crossplane` (the core controller) and `crossplane-rbac-manager` (which manages the RBAC for provider service accounts). Both should show `Running` with the `READY` column showing `1/1`.

## Installing the Azure Provider

Crossplane providers are installed as `Provider` custom resources. The official Azure provider from Upbound is `provider-azure`. Because the Azure provider covers hundreds of resource types, it ships as a family of sub-providers. For this walkthrough we need the storage and resources sub-providers.

Create a file called `azure-provider.yaml`:

{% highlight yaml %}
# azure-provider.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-storage
spec:
  package: xpkg.upbound.io/upbound/provider-azure-storage:v1.3.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-resources
spec:
  package: xpkg.upbound.io/upbound/provider-azure-resources:v1.3.0
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f azure-provider.yaml
{% endhighlight %}

Crossplane pulls the provider package from the registry and installs its CRDs. This takes a minute or two. Watch the provider become healthy:

{% highlight bash %}
kubectl get providers
{% endhighlight %}

Wait until both providers show `INSTALLED: True` and `HEALTHY: True`. If a provider is stuck in `Unhealthy`, describe it to see the reason:

{% highlight bash %}
kubectl describe provider provider-azure-storage
{% endhighlight %}

The `Status.Conditions` section will tell you if there is a network issue reaching the registry or a version incompatibility.

## Configuring the Azure Provider

Now that the provider is installed, it needs credentials. You will store the service principal credentials in a Kubernetes Secret, then reference that Secret from a `ProviderConfig`.

Create the credentials file from the service principal output you captured earlier:

{% highlight bash %}
cat > azure-credentials.json <<EOF
{
  "clientId": "<appId from sp create output>",
  "clientSecret": "<password from sp create output>",
  "tenantId": "<tenant from sp create output>",
  "subscriptionId": "<your-subscription-id>"
}
EOF
{% endhighlight %}

Store it as a Kubernetes Secret:

{% highlight bash %}
kubectl create secret generic azure-provider-credentials \
  --namespace crossplane-system \
  --from-file=credentials=./azure-credentials.json
{% endhighlight %}

Delete the local file after creating the secret — you do not want service principal credentials sitting in your working directory:

{% highlight bash %}
rm azure-credentials.json
{% endhighlight %}

Now create the `ProviderConfig` that points the provider at this secret. Create `azure-providerconfig.yaml`:

{% highlight yaml %}
# azure-providerconfig.yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-provider-credentials
      key: credentials
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f azure-providerconfig.yaml
{% endhighlight %}

The `ProviderConfig` is named `default`. When you create managed resources without explicitly specifying a `providerConfigRef`, Crossplane uses the config named `default`. You can create multiple `ProviderConfig` objects pointing at different subscriptions or identities and reference them explicitly in each managed resource — a useful pattern for multi-subscription environments.

## Creating Managed Resources

This is where Crossplane becomes tangible. You are going to create an Azure Resource Group and a Storage Account by applying Kubernetes manifests. No ARM templates, no Terraform modules — just YAML and `kubectl`.

### Azure Resource Group

Create `rg.yaml`:

{% highlight yaml %}
# rg.yaml
apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: crossplane-demo-rg
spec:
  forProvider:
    location: eastus
  providerConfigRef:
    name: default
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f rg.yaml
{% endhighlight %}

Watch Crossplane provision the resource:

{% highlight bash %}
kubectl get resourcegroup crossplane-demo-rg
{% endhighlight %}

The output will show columns for `READY`, `SYNCED`, and `EXTERNAL-NAME`. Initially both `READY` and `SYNCED` will be `False` with a reason of `Creating`. Within a few seconds they will flip to `True`, and `EXTERNAL-NAME` will show the Azure resource ID of the Resource Group.

You can confirm the resource exists in Azure directly:

{% highlight bash %}
az group show --name crossplane-demo-rg
{% endhighlight %}

### Azure Storage Account

Now create a Storage Account inside that Resource Group. Create `storage.yaml`:

{% highlight yaml %}
# storage.yaml
apiVersion: storage.azure.upbound.io/v1beta1
kind: Account
metadata:
  name: crossplanedemostore
spec:
  forProvider:
    location: eastus
    resourceGroupName: crossplane-demo-rg
    accountReplicationType: LRS
    accountTier: Standard
    minTlsVersion: TLS1_2
    enableHttpsTrafficOnly: true
  providerConfigRef:
    name: default
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f storage.yaml
{% endhighlight %}

Storage account provisioning in Azure takes longer than a Resource Group — typically 30 to 60 seconds. Watch the status:

{% highlight bash %}
kubectl get account crossplanedemostore --watch
{% endhighlight %}

Once `READY` and `SYNCED` are both `True`, the storage account exists in Azure. The `--watch` flag keeps the command running and updates the output in place as the status changes.

## Testing and Validation

Start by confirming the managed resource status reflects the Azure resource correctly:

{% highlight bash %}
kubectl describe account crossplanedemostore
{% endhighlight %}

In the `Status` section, look for the `Conditions` block. A healthy managed resource shows two conditions: `Ready: True` (the cloud resource exists and is in the expected state) and `Synced: True` (Crossplane successfully reconciled the desired spec against the observed state). If either is `False`, the `Message` field explains why — common causes are authentication failures, quota limits, or an invalid field value in the spec.

To observe the reconciliation loop directly, simulate an out-of-band change by modifying the storage account in the Azure portal or CLI — for example, enabling public network access. Watch the Crossplane controller detect the drift and reconcile it back:

{% highlight bash %}
# Disable HTTPS traffic only via az CLI to simulate out-of-band drift
az storage account update \
  --name crossplanedemostore \
  --resource-group crossplane-demo-rg \
  --https-only false

# Watch Crossplane reconcile it back within seconds
kubectl get account crossplanedemostore --watch
{% endhighlight %}

Crossplane will detect that the observed state diverges from the desired spec and call the Azure API to restore `enableHttpsTrafficOnly: true`. This is the same self-healing behavior as ArgoCD, but applied to cloud resources rather than Kubernetes workloads.

To clean up the resources, delete the Kubernetes objects. Crossplane will cascade-delete the cloud resources:

{% highlight bash %}
kubectl delete -f storage.yaml
kubectl delete -f rg.yaml
{% endhighlight %}

Verify deletion in Azure:

{% highlight bash %}
az group show --name crossplane-demo-rg
{% endhighlight %}

The command should return a `ResourceNotFound` error once Crossplane has finished the deletion.

## Best Practices

**Use the `deletionPolicy` field to protect production resources.** By default, deleting a Crossplane managed resource object also deletes the cloud resource. For stateful resources like databases or storage accounts containing data, set `spec.deletionPolicy: Orphan`. This removes the Kubernetes object without touching the cloud resource. You can then re-import the cloud resource into a new managed resource object later using `spec.managementPolicies`.

**Store managed resource manifests in Git and sync them with ArgoCD.** Crossplane and ArgoCD complement each other naturally. ArgoCD manages the desired state of your Kubernetes objects — including Crossplane managed resources — from Git. Crossplane reconciles those objects against the cloud API. The result is a fully GitOps infrastructure pipeline: a pull request to add a storage account, ArgoCD syncs the manifest, Crossplane provisions the resource.

**Use Compositions for reusable infrastructure abstractions.** The managed resources we created directly are the low-level API. Crossplane's `Composition` and `CompositeResourceDefinition` let you define higher-level abstractions — for example, a `DatabaseInstance` type that internally creates a Resource Group, a Virtual Network, a subnet, and an Azure Database for PostgreSQL as a single unit. Platform teams define the Composition; application teams consume the abstraction without needing to know the underlying managed resources.

**Pin provider versions explicitly.** The `package` field in the `Provider` manifest accepts a specific version tag. Avoid using `latest` or floating tags. Provider upgrades can introduce new required fields or change the behavior of existing ones. Pin to a specific version and upgrade deliberately after testing in a lower environment.

**Check the provider's managed resource documentation before writing specs.** Each provider maintains API reference documentation at `marketplace.upbound.io`. The docs list every field, its type, whether it is required, and whether it is immutable after creation. Immutable fields are particularly important — many Azure resources cannot have certain properties changed after creation, and Crossplane will report a conflict error if you try to update them.

## Conclusion

Crossplane collapses the operational split between Kubernetes workloads and cloud infrastructure. You write YAML, apply it with `kubectl`, and the reconciliation loop takes care of the rest — creating, updating, and self-healing cloud resources exactly the way Kubernetes manages pods and deployments. When you combine Crossplane with ArgoCD, you get a single GitOps pipeline that covers both your workloads and the infrastructure they depend on, with a full audit trail in Git for every change.

The setup in this post — Crossplane installed via Helm, the Azure provider configured with a `ProviderConfig`, a Resource Group and Storage Account provisioned as managed resources — is the foundation. From here, the interesting work is building `Compositions` that give your application teams a clean, opinionated API for infrastructure without exposing every Azure configuration knob. That is where Crossplane starts to feel like building a true internal developer platform.

Install it in a dev cluster, provision a few resources, break one out of band, and watch the reconciliation loop fix it. That moment tends to make the value immediately clear.

Happy scripting!
