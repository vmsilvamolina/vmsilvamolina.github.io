---
title: 'External Secrets Operator on OKE: Multicloud Backends'
author: Victor Silva
date: 2026-05-08T11:23:47+00:00
layout: post
permalink: /external-secrets-operator-oke-multicloud/
excerpt: "ESO on OKE syncs secrets from OCI Vault, AWS Secrets Manager, and Azure Key Vault into native Kubernetes Secrets without hardcoding credentials."
categories:
  - OCI
  - Security
tags:
  - OKE
  - kubernetes
  - external-secrets-operator
  - OCI Vault
  - AWS Secrets Manager
  - Azure Key Vault
  - secrets-management
  - devsecops
  - cncf
---

Kubernetes Secrets are base64-encoded, not encrypted. If you store credentials directly in a manifest or create them with `kubectl create secret`, those values end up in etcd, in your Git history if you're not careful, and in any backup that ever touches the cluster. The solution everyone gravitates toward is a dedicated secrets manager — OCI Vault, AWS Secrets Manager, Azure Key Vault, HashiCorp Vault — but then you have a different problem: how does the workload in Kubernetes actually get those values at runtime without a human copy-pasting them across?

External Secrets Operator solves exactly that. It runs as a controller inside your cluster, reads from whichever secrets backends you configure, and writes the results into native Kubernetes Secrets. Your pods consume regular Kubernetes Secrets and have no knowledge of OCI Vault or AWS Secrets Manager. The ESO controller handles the sync, the refresh interval, and the error reporting. Platform teams own the `SecretStore` resources that define what backends exist and which identities access them. Application teams own the `ExternalSecret` resources that declare which keys to pull. Neither team needs to ever touch the raw credential.

This post covers running ESO on Oracle Kubernetes Engine with three backends: OCI Vault (using workload identity and instance principal), AWS Secrets Manager (using static credentials, because OKE is not EKS), and Azure Key Vault (using a service principal, because Azure Workload Identity federation on non-AKS clusters is unsupported in practice). By the end you will have a working multi-backend setup, verified `SecretStore` connections, and synced secrets ready for your pods to consume.

## How ESO Works

ESO is a CNCF Sandbox project accepted in July 2022. Version 1.0.0 reached GA in late 2025 and the current stable Helm chart is v2.4.1, released April 28, 2025. One note worth mentioning for production planning: the maintainer team paused releases in August 2025 due to sustainability pressures, then resumed on September 22, 2025 after a governance reform. This was resolved, not ongoing — but it is the kind of context that matters when you are assessing adoption risk for a regulated workload.

ESO extends Kubernetes with five custom resource definitions:

- `SecretStore` — namespaced, describes one backend with its auth config
- `ClusterSecretStore` — cluster-scoped equivalent, for platform-wide access
- `ExternalSecret` — namespaced, declares which keys to sync and into which Kubernetes Secret
- `ClusterExternalSecret` — cluster-scoped, for pushing the same ExternalSecret across namespaces
- `PushSecret` — writes a Kubernetes Secret value back to an external backend

The stable API version is `external-secrets.io/v1`. If you are coming from older installations using `v1beta1`, note that it is no longer served from ESO 0.17.x onward. Update your manifests before upgrading.

The reconciliation loop is straightforward:

{% highlight text %}
ExternalSecret
     |
     | resolves
     v
SecretStore (backend: OCI Vault / AWS SM / Azure KV)
     |
     | API call
     v
External secrets manager
     |
     | response
     v
Kubernetes Secret (created/updated in same namespace)
{% endhighlight %}

ESO re-runs this loop on every `refreshInterval` you set in the `ExternalSecret`. If the upstream value changes, the Kubernetes Secret is updated automatically and any pods with a volume mount referencing the secret will eventually pick up the new value (subject to kubelet sync, typically under 60 seconds).

## Prerequisites

You need:

- An OKE cluster (Enhanced Cluster recommended — required for workload identity auth)
- `kubectl` configured against the cluster
- Helm 3.x
- OCI CLI configured (`oci setup config` or instance principal)
- An OCI Vault with at least one secret
- AWS credentials with Secrets Manager permissions
- An Azure Key Vault with a secret and an Azure subscription

Verify connectivity from the worker nodes to the relevant endpoints. ESO pods make outbound HTTPS (port 443) calls to:

- `secrets.ap-sydney-1.oci.oraclecloud.com` (adjust region)
- `secretsmanager.us-east-1.amazonaws.com`
- `my-keyvault.vault.azure.net`

Check your OKE worker subnet Security Lists or NSGs to confirm those egress rules exist before installing anything. A missing egress rule produces a timeout in the ESO pod logs that is easy to misdiagnose as an auth failure.

## Installing ESO on OKE

Add the Helm repository and install into a dedicated namespace:

{% highlight bash %}
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --version 2.4.1
{% endhighlight %}

Verify the controller, webhook, and cert-controller pods are running:

{% highlight bash %}
kubectl get pods -n external-secrets
{% endhighlight %}

You should see three pods: `external-secrets`, `external-secrets-webhook`, and `external-secrets-cert-controller`. All three need to reach `Running` before you create any `SecretStore`. The webhook registers itself against the API server, and if it's not ready when you submit resources, you'll get timeout errors from the validating webhook instead of a helpful message.

## Backend 1: OCI Vault

OCI Vault is the natural first backend on OKE. The recommended authentication path is OKE Workload Identity, which scopes access to a specific Kubernetes service account in a specific namespace on a specific cluster — not to the entire node. This is important: if you use Instance Principal instead, any workload running on the same node can call the OCI API with the same permissions, not just ESO.

### Option A: Workload Identity (Recommended)

This requires an OKE Enhanced Cluster. If you are on a Basic Cluster, skip to Option B. The OCI Vault setup here assumes you already have a vault and secrets created — if not, the [OCI Vault secrets management with Terraform](/oci-vault-secrets-management-terraform/) post walks through provisioning from scratch.

Create a Kubernetes service account for ESO to use when calling OCI:

{% highlight yaml %}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: eso-oci-sa
  namespace: external-secrets
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f eso-oci-sa.yaml
{% endhighlight %}

Now create the OCI IAM policy that grants this specific workload identity read access to secrets in your compartment. Replace the OCIDs with your actual values:

{% highlight bash %}
Allow any-user to read secret-family in compartment mycompartment where all {
  request.principal.type = 'workload',
  request.principal.namespace = 'external-secrets',
  request.principal.service_account = 'eso-oci-sa',
  request.principal.cluster_id = 'ocid1.cluster.oc1.ap-sydney-1.aaaaaaaXXXXXX'
}
{% endhighlight %}

Apply this policy in the OCI Console under Identity > Policies, or via the OCI CLI:

{% highlight bash %}
oci iam policy create \
  --compartment-id <tenancy-or-compartment-ocid> \
  --name eso-workload-identity-policy \
  --description "ESO workload identity access to Vault secrets" \
  --statements '["Allow any-user to read secret-family in compartment mycompartment where all {request.principal.type = '\''workload'\'', request.principal.namespace = '\''external-secrets'\'', request.principal.service_account = '\''eso-oci-sa'\'', request.principal.cluster_id = '\''ocid1.cluster.oc1.ap-sydney-1.aaaaaaaXXXXXX'\''}"]'
{% endhighlight %}

With the service account and IAM policy in place, create the `SecretStore` in the namespace where your application runs. The `SecretStore` is namespaced — it lives in `myapp`, not in `external-secrets`. The `serviceAccountRef` points back to the service account in the `external-secrets` namespace:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: oci-vault-store
  namespace: myapp
spec:
  provider:
    oracle:
      vault: ocid1.vault.oc1.ap-sydney-1.aaaaaaaXXXXXX
      region: ap-sydney-1
      principalType: Workload
      serviceAccountRef:
        name: eso-oci-sa
        namespace: external-secrets
      compartment: ocid1.compartment.oc1..aaaaaaaXXXXXX
{% endhighlight %}

### Option B: Instance Principal

If you are on a Basic Cluster or prefer a simpler setup for non-production environments, Instance Principal works at the node level. Create a dynamic group that matches your OKE worker nodes:

{% highlight bash %}
All {instance.compartment.id = 'ocid1.compartment.oc1..aaaaaaaXXXXXX'}
{% endhighlight %}

Then create an IAM policy granting the dynamic group read access:

{% highlight bash %}
Allow dynamic-group Default/oke-workers-dg to read secret-family in compartment mycompartment
{% endhighlight %}

The `SecretStore` for Instance Principal omits the `serviceAccountRef`:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: oci-vault-store
  namespace: myapp
spec:
  provider:
    oracle:
      vault: ocid1.vault.oc1.ap-sydney-1.aaaaaaaXXXXXX
      region: ap-sydney-1
      principalType: InstancePrincipal
      compartment: ocid1.compartment.oc1..aaaaaaaXXXXXX
{% endhighlight %}

The trade-off is explicit: any process on the node — not just the ESO controller — can call OCI Vault with these permissions. In a shared cluster, that means a compromised container in any namespace has access. Use this only when the cluster is single-tenant or in environments where the threat model accepts node-level trust.

## Backend 2: AWS Secrets Manager

OKE is not EKS. EKS has native OIDC federation that lets pod service accounts assume IAM roles without static credentials (IRSA). OKE has no equivalent integration with AWS IAM, so the practical path here is static AWS credentials stored in a Kubernetes Secret. This is a bootstrapping trade-off you accept knowingly, and the best practices section covers how to reduce the exposure.

### Step 1: AWS IAM Policy

Create an IAM policy in AWS that scopes access to exactly the secrets your application needs. Scoping to a prefix (`myapp/*`) keeps the blast radius manageable:

{% highlight json %}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ESOReadSecrets",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:myapp/*"
    },
    {
      "Sid": "ESOListSecrets",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:ListSecrets",
        "secretsmanager:BatchGetSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
{% endhighlight %}

Attach this policy to a dedicated IAM user (not a user with console access), generate an access key pair, and note the `AccessKeyId` and `SecretAccessKey`.

### Step 2: Kubernetes Secret for AWS Credentials

Store the credentials as a Kubernetes Secret in the same namespace as the `SecretStore`:

{% highlight yaml %}
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: myapp
type: Opaque
stringData:
  access-key: AKIAIOSFODNN7EXAMPLE
  secret-access-key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
{% endhighlight %}

Apply it, and note that `stringData` values are stored base64-encoded by Kubernetes automatically:

{% highlight bash %}
kubectl apply -f aws-credentials.yaml
{% endhighlight %}

### Step 3: SecretStore for AWS

Reference the credentials secret in the `SecretStore`:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secretsmanager-store
  namespace: myapp
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
{% endhighlight %}

## Backend 3: Azure Key Vault

Azure Workload Identity federation requires your cluster to expose an OIDC issuer endpoint that Azure AD can call back to for token validation. AKS does this natively. OKE does not publish a compatible OIDC discovery endpoint by default, and standing up that infrastructure manually to support workload identity from OKE to Azure is a significant undertaking that is not justified for most use cases. The supported path is a service principal with a client secret.

### Step 1: Create the Service Principal

Use the Azure CLI to create a service principal scoped to your Key Vault:

{% highlight bash %}
az ad sp create-for-rbac --name "eso-oke-reader" --skip-assignment
{% endhighlight %}

Note the `appId`, `password`, and `tenant` from the output. Then assign the `Key Vault Secrets User` built-in role — this is read-only for secrets:

{% highlight bash %}
KV_ID=$(az keyvault show --name my-keyvault --query id -o tsv)

az role assignment create \
  --assignee <appId> \
  --role "Key Vault Secrets User" \
  --scope $KV_ID
{% endhighlight %}

`Key Vault Secrets User` grants `secrets/get` and `secrets/list` on the vault. If you are using Azure RBAC authorization on the Key Vault (not the older access policies model), this role assignment is sufficient. If the Key Vault still uses access policies, add a separate policy granting `Get` and `List` for secrets to the service principal's object ID.

### Step 2: Kubernetes Secret for the Service Principal

{% highlight yaml %}
apiVersion: v1
kind: Secret
metadata:
  name: azure-sp-credentials
  namespace: myapp
type: Opaque
stringData:
  ClientID: "7d8cdf74-xxxx-xxxx-xxxx-274d963d358b"
  ClientSecret: "xxxx-the-sp-password-xxxx"
{% endhighlight %}

{% highlight bash %}
kubectl apply -f azure-sp-credentials.yaml
{% endhighlight %}

### Step 3: SecretStore for Azure Key Vault

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: azure-keyvault-store
  namespace: myapp
spec:
  provider:
    azurekv:
      tenantId: "5a02a20e-xxxx-xxxx-xxxx-0ad5b634c5d8"
      vaultUrl: "https://my-keyvault.vault.azure.net"
      authSecretRef:
        clientId:
          name: azure-sp-credentials
          key: ClientID
        clientSecret:
          name: azure-sp-credentials
          key: ClientSecret
{% endhighlight %}

## Creating ExternalSecrets

With all three `SecretStore` resources deployed, you can now write `ExternalSecret` manifests that pull actual values. These are the resources your application teams create — they describe which keys to pull and what Kubernetes Secret to produce.

### Single Key from OCI Vault

The simplest case: pull one secret by name from OCI Vault and map it to a key in a Kubernetes Secret:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-password-from-oci
  namespace: myapp
spec:
  refreshInterval: 15m
  secretStoreRef:
    kind: SecretStore
    name: oci-vault-store
  target:
    name: db-credentials
    creationPolicy: Owner
    deletionPolicy: Retain
  data:
    - secretKey: password
      remoteRef:
        key: myapp-db-password
{% endhighlight %}

`creationPolicy: Owner` means ESO creates the Kubernetes Secret and owns it — if the `ExternalSecret` is deleted, ESO will also delete the resulting secret. `deletionPolicy: Retain` means the secret survives even if the upstream value is deleted or the ESO cannot reach OCI Vault. Both are deliberate choices here: you almost always want to retain production database credentials rather than have them disappear because of a transient Vault API failure.

### JSON Secret from AWS with Property Extraction

AWS Secrets Manager commonly stores structured JSON payloads. ESO can extract individual fields using the `property` field in `remoteRef`:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: app-config-from-aws
  namespace: myapp
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: aws-secretsmanager-store
  target:
    name: app-config
    creationPolicy: Owner
  data:
    - secretKey: db_host
      remoteRef:
        key: myapp/production/config
        property: database.host
    - secretKey: db_password
      remoteRef:
        key: myapp/production/config
        property: database.password
{% endhighlight %}

The `property` field uses dot notation to traverse nested JSON. `database.host` extracts the `host` field from a `database` object inside the secret value. The resulting Kubernetes Secret will have two keys: `db_host` and `db_password`, ready for your pod's `env` or `envFrom` block.

### Bulk Extract from Azure Key Vault

When a Key Vault secret stores multiple key-value pairs as a JSON object, or when you want every secret in the vault mapped into one Kubernetes Secret, `dataFrom.extract` does the work without enumerating each key:

{% highlight yaml %}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: all-azure-secrets
  namespace: myapp
spec:
  refreshInterval: 30m
  secretStoreRef:
    kind: SecretStore
    name: azure-keyvault-store
  target:
    name: azure-app-secrets
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: myapp-config
{% endhighlight %}

This pulls the `myapp-config` secret from Azure Key Vault, parses it as JSON, and creates one Kubernetes Secret key per top-level field. If `myapp-config` contains `{"api_url": "...", "api_key": "..."}`, the resulting Kubernetes Secret has `api_url` and `api_key` as separate keys.

## Testing and Verification

Start by checking that the `SecretStore` resources are healthy. The `STATUS` column should show `Valid`:

{% highlight bash %}
kubectl get secretstore -n myapp
{% endhighlight %}

If any shows `Invalid`, describe it to read the condition message:

{% highlight bash %}
kubectl describe secretstore oci-vault-store -n myapp
{% endhighlight %}

The `Status.Conditions` block will tell you what ESO found when it tried to connect. A `401 Unauthorized` from OCI almost always means the IAM policy is missing or uses the wrong OCID. An `AccessDeniedException` from AWS means the IAM policy is too narrow or attached to the wrong user. A `Forbidden` from Azure usually means the service principal is missing the role assignment, or the `tenantId` in the `SecretStore` does not match the tenant of the Key Vault.

Once all stores are valid, check the `ExternalSecret` status:

{% highlight bash %}
kubectl get externalsecret -n myapp
{% endhighlight %}

A healthy sync shows `READY: True` and `STATUS: SecretSynced`. If the status is `SecretSyncedError`, describe the `ExternalSecret`:

{% highlight bash %}
kubectl describe externalsecret db-password-from-oci -n myapp
{% endhighlight %}

The events section will surface the specific error from the backend API.

Inspect the resulting Kubernetes Secret to confirm the value is present and correct:

{% highlight bash %}
kubectl get secret db-credentials -n myapp -o json \
  | jq -r '.data.password' \
  | base64 -d
{% endhighlight %}

If you change a value in OCI Vault or AWS Secrets Manager and want ESO to pick it up immediately without waiting for the next `refreshInterval`, annotate the `ExternalSecret`:

{% highlight bash %}
kubectl annotate externalsecret db-password-from-oci \
  force-sync=$(date +%s) \
  --overwrite \
  -n myapp
{% endhighlight %}

This triggers an immediate reconciliation outside the normal refresh cycle.

Finally, check that the ESO pods themselves are healthy and not logging errors:

{% highlight bash %}
kubectl get pods -n external-secrets
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=50
{% endhighlight %}

## Best Practices

**Workload Identity over Instance Principal for OCI.** The security difference is not subtle. Instance Principal grants access to all workloads on the node. A compromised sidecar container in a completely unrelated deployment can make the same OCI API calls as the ESO controller. Workload Identity scopes the trust to a specific service account in a specific namespace on a specific cluster. Use it on Enhanced Clusters.

**Scope your IAM and RBAC to the minimum resource.** For OCI, scope the policy to the compartment (not the tenancy) and use `secret-family` not `vault-family`. For AWS, use a resource ARN with a path prefix (`arn:aws:secretsmanager:region:account:secret:myapp/*`) instead of `"Resource": "*"`. For Azure, assign `Key Vault Secrets User` at the Key Vault level, not at the subscription level.

**Use `SecretStore` by default, `ClusterSecretStore` only for platform-wide access.** A `ClusterSecretStore` can be referenced by `ExternalSecret` resources in any namespace. That's powerful and dangerous. If you do need it, add a `conditions.namespaceSelector` to restrict which namespaces can reference it:

{% highlight yaml %}
spec:
  conditions:
    - namespaceSelector:
        matchLabels:
          eso-access: "true"
{% endhighlight %}

**Set `refreshInterval` based on the secret's rotation characteristics.** For database passwords that rotate infrequently: `1h`. For TLS private keys: `1h`. For rarely-rotated API keys: `6h`. For one-time bootstrap credentials you intend to delete after setup: `0` (ESO fetches once and never re-reads). Don't default everything to `15m` — that generates unnecessary API calls at scale.

**The AWS static credentials are a bootstrapping risk.** The AWS access key and secret are stored as a plain Kubernetes Secret (base64, not encrypted). A common mitigation: store the AWS credentials themselves in OCI Vault, access them via workload identity to bootstrap the ESO controller, and then have ESO sync them into the Kubernetes Secret that the AWS `SecretStore` references. This collapses the problem back to OCI Vault as the single root of trust, and OCI access is controlled via workload identity with no static credentials anywhere. The setup is more involved, but it removes the credential-in-etcd exposure.

**Verify ESO container images before deploying in regulated environments.** ESO publishes Cosign signatures for its container images. In an environment where image provenance matters, verify before deploying:

{% highlight bash %}
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/external-secrets/external-secrets' \
  ghcr.io/external-secrets/external-secrets:v0.17.0
{% endhighlight %}

**Structure your secrets in the backend to match how you consume them.** If your application needs five configuration values, consider storing them as a single JSON secret in the backend rather than five separate secrets. This reduces API calls, simplifies the `ExternalSecret` manifest with `dataFrom`, and makes key management in the backend easier. The trade-off is that you cannot grant access to individual keys within the JSON blob — it's all-or-nothing at the secret level.

## Conclusion

External Secrets Operator gives you a consistent, auditable way to bring secrets from any backend into Kubernetes without embedding credentials in manifests or letting your application code deal with vault SDKs. On OKE specifically, the three backends covered here — OCI Vault with workload identity, AWS Secrets Manager with static credentials, and Azure Key Vault with a service principal — cover the most common multicloud scenarios you will encounter.

The separation of concerns that ESO enforces is worth internalizing: platform teams define the trust boundary (`SecretStore`), application teams declare their needs (`ExternalSecret`), and the controller handles the sync. That model scales to large clusters with many teams without requiring each team to understand the underlying vault API or IAM configuration.

The next step from here is exploring `ClusterExternalSecret` for pushing the same secret across multiple namespaces, and `PushSecret` for scenarios where Kubernetes is the source of truth and you need values written back to a vault. Both build on the same CRD model and the same `SecretStore` backends you already have configured. If you are building out your OKE security posture more broadly, [cert-manager on OKE with OCI DNS](/cert-manager-oke-oci-dns/) and [OPA Gatekeeper admission policies on OKE](/gatekeeper-opa-oke-admission-policies/) cover complementary layers of the stack.

Happy scripting!
