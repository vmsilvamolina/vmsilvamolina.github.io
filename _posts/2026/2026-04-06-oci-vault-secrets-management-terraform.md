---
title: 'OCI Vault: Secrets Management with Terraform'
author: Victor Silva
date: 2026-04-06T09:00:00+00:00
layout: post
permalink: /oci-vault-secrets-management-terraform/
excerpt: "Learn how to manage secrets in OCI Vault with Terraform: vault, keys, IAM policies, and the right pattern to prevent your secrets from ending up in the state file."
categories:
  - Oracle
  - Terraform
tags:
  - OCI
  - vault
  - terraform
  - secrets-management
  - iam
  - security
---

If you've ever opened a Terraform repository and found something like `db_password = "Sup3rS3cr3t!"` hardcoded in a `.tfvars` file — or worse, in `main.tf` itself — you already know exactly what problem we're talking about. Hardcoded credentials are one of the most common vulnerabilities in infrastructure-as-code projects, and the risk doesn't stop there: even when secrets are passed correctly as variables, certain Terraform data sources write the secret value directly into the state file, which often lives in an S3 bucket or a remote backend without additional encryption.

OCI Vault solves this problem at the root. It's Oracle Cloud's managed service for key and secret storage, backed by HSM, with granular access control via IAM and native support in the Terraform provider for OCI. In this post we'll build the complete infrastructure from scratch: vault, master encryption key, secrets with expiration and rotation rules, IAM policies for teams and for workloads via Instance Principal, and the verification commands to confirm everything works before trusting the system in production.

We'll also be explicit about the state file problem and how to avoid it, because it's the most dangerous gotcha when working with secrets in Terraform.

## Architecture and key concepts

OCI Vault has an architecture with two separate planes:

- **Management Endpoint (control plane):** used for administrative operations — creating vaults, keys, and secrets, rotating versions. All Terraform calls go here.
- **Cryptographic Endpoint (data plane):** used for actual cryptographic operations — encrypt, decrypt, sign. Applications that need direct encryption point here.

This separation is not cosmetic. It means you can restrict access to the data plane independently from the control plane, which is relevant for IAM policy design.

```
┌─────────────────────────────────────────────────────────────┐
│  OCI Tenancy                                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Compartment: production                              │  │
│  │                                                       │  │
│  │  ┌─────────────────┐    ┌───────────────────────────┐ │  │
│  │  │   OCI Vault     │    │   Compute Instance        │ │  │
│  │  │  ┌───────────┐  │    │   (Instance Principal)    │ │  │
│  │  │  │  MEK Key  │  │    │                           │ │  │
│  │  │  └─────┬─────┘  │    │   oci secrets             │ │  │
│  │  │        │ encrypts│   │   secret-bundle get ───►  │ │  │
│  │  │  ┌─────▼─────┐  │◄───┤                           │ │  │
│  │  │  │  Secrets  │  │    │                           │ │  │
│  │  │  └───────────┘  │    └───────────────────────────┘ │  │
│  │  └─────────────────┘                                  │  │
│  │         ▲                                             │  │
│  │   Management Endpoint   Cryptographic Endpoint        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Vault types: an irreversible decision

This is the first point where you need to think before running `terraform apply`, because **the vault type cannot be changed after creation**. The options are:

| Type | HSM | Key auto-rotation | Cost | Recommended use |
|---|---|---|---|---|
| `DEFAULT` | Shared | No | Lower | Development, staging |
| `VIRTUAL_PRIVATE` | Dedicated | Yes (GA since Feb 2024) | Higher | Production |
| `EXTERNAL` | External (BYOK) | No | Variable | Strict regulations |

For production, `VIRTUAL_PRIVATE` is the right answer: dedicated HSM, support for automatic key rotation, and full isolation. For development and testing environments, `DEFAULT` works well and is considerably more economical.

In this post we'll use `DEFAULT` to keep the example deployable in any tenancy, but in the best practices section we'll look at when and how to migrate to `VIRTUAL_PRIVATE`.

### Keys: AES for secrets, RSA/ECDSA for signing

OCI Vault supports symmetric keys (AES) and asymmetric keys (RSA, ECDSA). The important constraint: **only AES keys can encrypt secrets**. RSA and ECDSA keys are for signing and asymmetric encryption, not for the vault secrets service. If you try to associate an RSA key with a secret, the operation fails.

The Terraform gotcha that bites almost everyone the first time: **key length is specified in bytes, not bits**. AES-256 = `length = 32`. If you set `length = 256` you're requesting a 2048-bit key, which isn't even a valid AES size.

## Prerequisites

To follow this post you'll need:

- OCI CLI installed and configured (`oci setup config` or API key in `~/.oci/config`)
- Terraform >= 1.3
- Provider `oracle/oci` >= 8.0
- A compartment OCID where you have `manage vaults`, `manage keys`, and `manage secret-family` permissions
- Your tenancy OCID (needed to create Dynamic Groups, which are tenancy-level)

Verify access before starting:

{% highlight bash %}
# Verify the CLI is configured correctly
oci iam user get --user-id $(oci iam user list --query 'data[0].id' --raw-output)

# Verify you have access to the compartment
oci iam compartment get --compartment-id $COMPARTMENT_ID

# Verify the provider version in your project
terraform providers
{% endhighlight %}

## Step-by-step implementation

### Provider configuration

We start with the provider configuration block. Nothing special here, but it's important to pin the provider version because the OCI Vault API changed between major versions:

{% highlight hcl %}
terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.0"
    }
  }
}

provider "oci" {
  region = var.region
}
{% endhighlight %}

The variables we'll need throughout the example:

{% highlight hcl %}
variable "region" {
  description = "OCI region"
  type        = string
}

variable "compartment_id" {
  description = "OCID of the compartment where resources are deployed"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCID of the tenancy (required for Dynamic Groups)"
  type        = string
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}
{% endhighlight %}

### Creating the Vault and Master Encryption Key

The vault and key are created with two separate resources. The relationship between them is that `oci_kms_key` requires the `management_endpoint` of the vault — not a hardcoded endpoint, but a reference to the vault resource's attribute. Without `depends_on`, Terraform may try to create the key before the vault is fully provisioned, resulting in an unavailable endpoint error.

{% highlight hcl %}
resource "oci_kms_vault" "app_vault" {
  compartment_id = var.compartment_id
  display_name   = "app-production-vault"
  vault_type     = "DEFAULT"

  freeform_tags = {
    "Environment" = "production"
    "ManagedBy"   = "terraform"
  }
}

resource "oci_kms_key" "app_key" {
  compartment_id      = var.compartment_id
  display_name        = "app-secrets-key"
  management_endpoint = oci_kms_vault.app_vault.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32   # 32 bytes = AES-256 (Terraform uses bytes, not bits)
  }

  protection_mode = "HSM"

  depends_on = [oci_kms_vault.app_vault]
}
{% endhighlight %}

Two important decisions in this block:

`protection_mode = "HSM"` means the key material never leaves the HSM — OCI cannot export it and neither can you. If you use `protection_mode = "SOFTWARE"`, the key can be exported, which expands the attack surface. For production, always HSM.

The explicit `depends_on` is not just best practice: it's necessary. The vault may take a few seconds to become operational after the API reports the resource as created, and the key needs the management endpoint to be active to register.

### Creating the secret with expiration rules

Now for the secret itself. The secret content must be base64-encoded — OCI Vault does not accept plain text in the API. Terraform has the `base64encode()` function that does exactly that:

{% highlight hcl %}
resource "oci_vault_secret" "db_password" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.app_vault.id
  key_id         = oci_kms_key.app_key.id
  secret_name    = "app-db-password"
  description    = "Database admin password for app-production"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.db_password)
    stage        = "CURRENT"
  }

  secret_rules {
    rule_type                                     = "SECRET_EXPIRY_RULE"
    secret_version_expiry_interval                = "P90D"
    is_secret_content_retrieval_blocked_on_expiry = true
  }

  secret_rules {
    rule_type                              = "SECRET_REUSE_RULE"
    is_enforced_on_deleted_secret_versions = true
  }
}
{% endhighlight %}

The `secret_rules` are the component most often overlooked in basic implementations and that makes the biggest difference in production:

**SECRET_EXPIRY_RULE** with `P90D` makes the secret expire after 90 days. The critical part is `is_secret_content_retrieval_blocked_on_expiry = true`. By default this field is `false`, meaning that even when the secret expires, applications can still read it. That makes expiration decorative. With `true`, OCI blocks access to the secret bundle once it expires, forcing real rotation.

**SECRET_REUSE_RULE** with `is_enforced_on_deleted_secret_versions = true` prevents reuse of a previous secret value, even in deleted versions. This is a compliance control relevant in regulated environments.

### Outputs for later reference

Outputs are important both for verification and so that other Terraform modules can reference these resources:

{% highlight hcl %}
output "vault_id" {
  description = "Vault OCID"
  value       = oci_kms_vault.app_vault.id
}

output "vault_management_endpoint" {
  description = "Vault management endpoint (required for key operations)"
  value       = oci_kms_vault.app_vault.management_endpoint
}

output "key_id" {
  description = "Master encryption key OCID"
  value       = oci_kms_key.app_key.id
}

output "db_secret_id" {
  description = "Database secret OCID"
  value       = oci_vault_secret.db_password.id
}
{% endhighlight %}

## The state file problem

This is the point where most projects fail silently, and it's worth pausing.

OCI Vault exposes two data sources for reading secrets in Terraform:

- `oci_vault_secret` — returns **only metadata** about the secret: OCID, name, state, dates. The secret value never appears in the state.
- `oci_secrets_secretbundle` — returns the **actual content** of the secret, decoded. **This value is stored in the state file.**

The Terraform state file is not encrypted by default. If your backend is an AWS S3 bucket or an OCI Object Storage bucket without additional encryption, the secret is stored in plain text in the state. Anyone with access to the backend has access to the secret.

The safest pattern is to never read the secret value from Terraform. Applications should retrieve it at runtime using the OCI SDK or CLI with Instance Principal, not during apply. If you need to reference a secret's OCID in another resource, use `oci_vault_secret` (metadata only) or directly reference the output of the resource that created it.

If for some operational reason you need to read the bundle in Terraform, there are three mitigations:

**1. KMS-encrypted backend.** If you use OCI Object Storage as a Terraform backend, you can configure it with an OCI Vault key so the state file is encrypted at rest. The secret is still in the state, but the state is encrypted with a key whose access you control with IAM.

**2. Automatic secret generation.** Some secret types support `enable_auto_generation = true` in `oci_vault_secret`. In that case, OCI generates the value internally and it never goes through Terraform — the state only contains the OCID, never the value. This is ideal for database passwords that you don't need to know yourself, only the application does.

**3. Separate provisioning.** The vault and keys are managed with Terraform. Secret values are loaded with the CLI or a separate pipeline with limited access. Terraform manages the infrastructure, not the sensitive data.

The recommended posture: use Terraform to create the vault infrastructure (vault, key, secret resource with a placeholder value or with auto-generation), and leave injecting the real value for a separate step outside the Terraform state.

## IAM Policies: granular access control

This is the component that's hardest to get right, because OCI IAM has a verb matrix that's not immediately obvious.

### The verb matrix for secrets

| Verb | Operation | Who needs it |
|---|---|---|
| `read secret-bundles` | GetSecretBundle — retrieve the secret value | App workloads, production instances |
| `read secrets` | GetSecret — view secret metadata | Audit, CI/CD pipelines that only reference OCIDs |
| `use secrets` | ListSecretVersions and rotation operations | Automated rotation tools |
| `manage secret-family` | Full control — create, delete, rotate, modify | Security administrators only |

The golden rule: **never grant `manage secret-family` to an application workload**. With that verb, the application can delete secrets, create versions with arbitrary values, and modify expiration rules. The blast radius if the application is compromised extends to the entire vault.

### Policies for the administrator team

{% highlight hcl %}
resource "oci_identity_policy" "vault_admin_policy" {
  compartment_id = var.compartment_id
  name           = "vault-admin-policy"
  description    = "Allow SecurityAdmins group to fully manage vault resources"

  statements = [
    "Allow group SecurityAdmins to manage vaults in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage keys in compartment id ${var.compartment_id}",
    "Allow group SecurityAdmins to manage secret-family in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

### Dynamic Groups for Instance Principal

Dynamic Groups are OCI's mechanism for compute instances to authenticate with IAM without static credentials. The instance assumes an identity based on its compartment membership, and that identity has the policies you assign to it.

An important operational detail: **Dynamic Groups are created at the tenancy level, not the compartment level**. The `compartment_id` of the `oci_identity_dynamic_group` resource must be the tenancy OCID, even if the matching rule filters instances from a specific compartment. If you use a child compartment OCID, the OCI provider will return an error.

{% highlight hcl %}
resource "oci_identity_dynamic_group" "app_instances" {
  compartment_id = var.tenancy_ocid   # Always tenancy, not compartment
  name           = "app-compute-instances"
  description    = "Compute instances in the app production compartment"
  matching_rule  = "All {instance.compartment.id = '${var.compartment_id}'}"
}

resource "oci_identity_policy" "instance_secret_policy" {
  compartment_id = var.compartment_id
  name           = "instance-vault-access-policy"
  description    = "Allow app instances to retrieve secrets from vault"

  statements = [
    "Allow dynamic-group app-compute-instances to read secret-bundles in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

If you want to narrow access to a specific secret rather than the entire compartment, OCI supports conditions in IAM statements:

{% highlight hcl %}
resource "oci_identity_policy" "instance_specific_secret_policy" {
  compartment_id = var.compartment_id
  name           = "instance-specific-secret-policy"
  description    = "Allow app instances to retrieve only the db password secret"

  statements = [
    "Allow dynamic-group app-compute-instances to read secret-bundles in compartment id ${var.compartment_id} where target.secret.name = 'app-db-password'",
  ]
}
{% endhighlight %}

This granularity is particularly useful in multi-application environments where different services need access to different secrets within the same compartment.

## Testing and verification

With the infrastructure applied, verification has three levels: vault and key state, secret retrieval from your local machine, and retrieval from an instance using Instance Principal.

### Verify vault and key state

{% highlight bash %}
# Verify the vault is ACTIVE
oci kms management vault get \
  --vault-id "$(terraform output -raw vault_id)" \
  --query 'data."lifecycle-state"' --raw-output

# Verify the key is ENABLED
oci kms management key get \
  --key-id "$(terraform output -raw key_id)" \
  --endpoint "$(terraform output -raw vault_management_endpoint)" \
  --query 'data."lifecycle-state"' --raw-output
{% endhighlight %}

The expected vault state is `ACTIVE`. The expected key state is `ENABLED`. If the vault is in `CREATING` or `PROVISIONING`, wait a few seconds and query again.

### Retrieve and verify the secret

{% highlight bash %}
# Retrieve the secret and decode the base64
oci secrets secret-bundle get \
  --secret-id "$(terraform output -raw db_secret_id)" \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 --decode
{% endhighlight %}

If the output matches the value you passed in `var.db_password`, the complete cycle works: Terraform created the secret, OCI encrypted it with the MEK, and the CLI retrieved it correctly.

### Verify access from an instance with Instance Principal

From an instance that belongs to the compartment configured in the Dynamic Group's matching rule:

{% highlight bash %}
# On the compute instance — no static credentials needed
oci secrets secret-bundle get \
  --secret-id "ocid1.vaultsecret.oc1.xxx" \
  --auth instance_principal \
  --query 'data."secret-bundle-content".content' --raw-output | base64 --decode
{% endhighlight %}

If this command returns the secret value without needing API keys configured on the instance, Instance Principal is working correctly. If it returns an authorization error, verify that the instance is in the correct compartment and that the Dynamic Group has the appropriate matching rule.

### Verify expiration rules

{% highlight bash %}
# View secret metadata including rules and expiration date
oci vault secret get \
  --secret-id "$(terraform output -raw db_secret_id)" \
  --query 'data.{name:"secret-name", state:"lifecycle-state", rules:"secret-rules"}'
{% endhighlight %}

## Best Practices

**Never use `VIRTUAL_PRIVATE` in the same apply as the secrets if you're just starting.** The `VIRTUAL_PRIVATE` vault takes several minutes to provision its dedicated HSM. If Terraform tries to create keys and secrets before the vault is fully operational, the apply fails. Separating vault creation into its own module with a prior `terraform apply` avoids this problem.

**Use `protection_mode = "HSM"` in production, always.** With `SOFTWARE`, the key material can be exported. That means with the right permissions, someone can extract the key from the vault. With `HSM`, the material never leaves the hardware. The additional cost of HSM is marginal compared to the risk of an exportable key.

**The vault type is immutable after creation.** If you need to migrate from `DEFAULT` to `VIRTUAL_PRIVATE`, the process is: create a new `VIRTUAL_PRIVATE` vault, create new keys, rotate all secrets to the new vault, and delete the old one. There's no in-place upgrade. Plan your vault type before the first deploy.

**Enable `is_secret_content_retrieval_blocked_on_expiry = true` in all expiration rules.** The default is `false`, which turns expiration into a toothless alert. With `true`, OCI blocks access to the secret once it expires, forcing rotation. Without this, a secret "expired" six months ago is still accessible.

**Separate key management from secret management.** Keys (MEK) are the responsibility of the security team. Individual secrets can be the responsibility of application teams, with the constraint that they can only use pre-approved keys. This is modeled in IAM by separating groups and policies: `SecurityAdmins` has `manage keys`, application teams have `use keys` and `manage secret-family` in their compartment.

**Use encrypted backends for Terraform state.** If your Terraform backend is in OCI Object Storage, configure server-side encryption with an OCI Vault key. This doesn't eliminate the risk of secrets being in the state, but adds a layer of at-rest protection with auditable access control.

**Prefer auto-generation or separate provisioning over reading secrets in Terraform.** The safest pattern is for Terraform to never know the actual value of the secrets it manages. For database passwords, enable `enable_auto_generation`. For secrets you need to control, load them with the CLI in a separate pipeline step with reduced permissions.

## Conclusion

We built the complete OCI Vault infrastructure with Terraform: vault with correctly configured type and protection mode, AES-256 master encryption key in HSM, secrets with expiration rules that actually block access, and the correct IAM policies for both administrators and workloads via Instance Principal.

The most important point is not the code itself, but the gotchas you need to know before going to production: the vault type is irreversible, key length is in bytes, `oci_secrets_secretbundle` writes the value to the state, and `is_secret_content_retrieval_blocked_on_expiry` is `false` by default. With that clear, the rest is configuration.

The natural next step is integrating this vault with CI/CD pipelines using OCI DevOps or GitHub Actions with OIDC, so pipelines retrieve secrets at runtime without static credentials. That's material for another post.

Happy scripting!
