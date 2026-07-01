---
title: "OCI Vault: managing secrets for Terraform pipelines"
author: Victor Silva
date: 2023-09-05T14:38:22+00:00
layout: post
permalink: /oci-vault-secrets-terraform-pipelines/
excerpt: "How to use OCI Vault to store and retrieve secrets in Terraform pipelines — including vault and key creation, secret lifecycle management, and reading secrets at plan/apply time."
categories:
  - OCI
  - Terraform
tags:
  - OCI
  - Oracle Cloud
  - Vault
  - Terraform
  - IaC
  - Security
  - Secrets Management
---

Hardcoded credentials in Terraform variables files are a recurring problem in infrastructure teams. It starts small — someone runs `terraform apply` with a database password in `terraform.tfvars`, the file ends up committed to the repository, and that is the credential hygiene story for the entire project. The pattern is familiar because it is the path of least resistance: the credential needs to be somewhere, the variables file is right there, and the pipeline is working. The fact that the password is now readable by everyone with repository access tends to only become a problem when it becomes a problem.

OCI Vault solves this at the right layer. It provides a managed secrets store where Terraform can pull sensitive values at plan and apply time — the secret lives in Vault, not in your repository. The OCID of the secret is safe to commit and reference in pipeline configuration; the actual credential never leaves the service. If you are coming from Azure, this is the same role filled by Azure Key Vault. If you have used AWS, it is equivalent to Secrets Manager. OCI's implementation has its own resource model and API surface, which is what this post covers in full.

By the end of this post you will have a working Vault with a master encryption key and a secret created via OCI CLI, the same resources provisioned through Terraform, and the data source pattern for reading secrets inside a Terraform configuration at apply time. I will also cover IAM policies for Vault access and the security conventions that make the difference between a secrets store that actually improves your posture and one that just adds a layer of indirection.

## OCI Vault Concepts

Before writing any CLI commands or HCL, the three-level resource model is worth understanding precisely, because it affects every decision you make about how to structure your Vault setup.

### Vault

The **vault** is the top-level container. It holds master encryption keys and secrets. When you create a vault you choose a type: **Default** or **Virtual Private Vault**. The Default type uses a shared Hardware Security Module (HSM) infrastructure managed by Oracle — it is GA, production-ready, and the right choice for most workloads. Virtual Private Vault allocates a dedicated HSM partition to your tenancy, which meets stricter compliance requirements but carries a substantially higher cost. For Terraform pipeline secrets, Default is almost always the correct choice.

### Master Encryption Key (MEK)

Every secret in OCI Vault is encrypted at rest. The **master encryption key** is what encrypts it. You create the MEK inside the vault, choose the algorithm and key length at creation time, and it cannot be changed afterwards. For symmetric secrets — passwords, API keys, connection strings — AES-256 is the right choice. The MEK is not something your Terraform pipeline uses directly; it is the infrastructure-level control that protects your secret values even from operators who have console access to the Vault service itself.

### Secret

The **secret** is the actual sensitive value, encrypted with the MEK. OCI Vault stores secrets as base64-encoded payloads. Secrets are versioned: when you update a secret, a new version is created and the previous versions are retained. This is important for rotation — you can create a new version, update your downstream consumers, and then schedule the old version for deletion rather than destroying it immediately. The OCID of a secret does not change across versions, which means any configuration that references the secret OCID continues to work after a rotation.

## Prerequisites

To follow along you will need:

- OCI CLI 3.x installed and configured with a profile that has access to your tenancy
- Terraform 1.3 or later with the `hashicorp/oci` provider at `~> 5.0`
- A compartment OCID for the resources you will create
- IAM permissions to manage vaults, keys, and secrets in that compartment

Verify your CLI setup and confirm the compartment is reachable:

{% highlight bash %}
oci --version
oci iam compartment get --compartment-id $COMPARTMENT_OCID --query 'data."display-name"' --raw-output
{% endhighlight %}

Set the environment variables you will reuse throughout:

{% highlight bash %}
export COMPARTMENT_OCID="ocid1.compartment.oc1..aaaa..."
export REGION="us-ashburn-1"
{% endhighlight %}

## Creating a Vault and Key with OCI CLI

### Creating the Vault

The vault creation command specifies the compartment, a display name, and the vault type. The `--wait-for-state ACTIVE` flag blocks until the vault is provisioned and ready to accept key and secret operations — vault creation is asynchronous and takes a minute or two.

{% highlight bash %}
oci kms management vault create \
    --compartment-id $COMPARTMENT_OCID \
    --display-name "vault-terraform-prod" \
    --vault-type DEFAULT \
    --wait-for-state ACTIVE
{% endhighlight %}

Once the vault is active, capture its OCID and management endpoint. The management endpoint is a vault-specific URL required for all key operations — it is not a global OCI endpoint.

{% highlight bash %}
export VAULT_OCID=$(oci kms management vault list \
    --compartment-id $COMPARTMENT_OCID \
    --query 'data[?("display-name"==`vault-terraform-prod`)].id | [0]' \
    --raw-output)

export MANAGEMENT_ENDPOINT=$(oci kms management vault get \
    --vault-id $VAULT_OCID \
    --query 'data."management-endpoint"' \
    --raw-output)

echo "Vault OCID: $VAULT_OCID"
echo "Management endpoint: $MANAGEMENT_ENDPOINT"
{% endhighlight %}

### Creating the Master Encryption Key

With the management endpoint in hand, create the AES-256 master encryption key. The `--key-shape` parameter takes a JSON object specifying the algorithm and key length in bytes — `32` bytes equals 256 bits.

{% highlight bash %}
oci kms management key create \
    --compartment-id $COMPARTMENT_OCID \
    --display-name "key-terraform-secrets" \
    --key-shape '{"algorithm":"AES","length":32}' \
    --endpoint $MANAGEMENT_ENDPOINT \
    --wait-for-state ENABLED

export KEY_OCID=$(oci kms management key list \
    --compartment-id $COMPARTMENT_OCID \
    --endpoint $MANAGEMENT_ENDPOINT \
    --query 'data[?("display-name"==`key-terraform-secrets`)].id | [0]' \
    --raw-output)

echo "Key OCID: $KEY_OCID"
{% endhighlight %}

## Storing and Retrieving Secrets

### Creating a Secret

OCI Vault requires secret values to be base64-encoded before submission. The `oci vault secret create-base64` subcommand handles this directly — you pass the base64-encoded value as `--secret-content-content` and set the content type to `BASE64`.

{% highlight bash %}
# Encode the secret value
SECRET_VALUE=$(echo -n "my-database-password-here" | base64)

# Create the secret
oci vault secret create-base64 \
    --compartment-id $COMPARTMENT_OCID \
    --vault-id $VAULT_OCID \
    --key-id $KEY_OCID \
    --secret-name "db-admin-password" \
    --secret-content-content "$SECRET_VALUE" \
    --secret-content-content-type "BASE64"
{% endhighlight %}

The `-n` flag on `echo` is important — it suppresses the trailing newline. A base64-encoded newline at the end of your secret will cause authentication failures against most databases and APIs, and the error messages you get from those systems rarely point back to a stray whitespace character as the root cause.

Capture the secret OCID from the response and store it somewhere your Terraform configuration can reference it — a pipeline variable, a parameter file, or a tfvars entry that contains the OCID but not the value.

{% highlight bash %}
export SECRET_OCID=$(oci vault secret list \
    --compartment-id $COMPARTMENT_OCID \
    --query 'data[?("secret-name"==`db-admin-password`)].id | [0]' \
    --raw-output)

echo "Secret OCID: $SECRET_OCID"
{% endhighlight %}

### Retrieving a Secret Value

To verify the secret was stored correctly, use the Secrets Retrieval API via the `oci secrets secret-bundle get` command and decode the base64 payload:

{% highlight bash %}
oci secrets secret-bundle get \
    --secret-id $SECRET_OCID \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode
{% endhighlight %}

This is also the pattern your CI pipeline can use to inject a secret value into a script — retrieve it from Vault at runtime rather than storing it in pipeline variables.

## Managing Vault Resources with Terraform

Now that we have the concepts and CLI commands clear, let's implement the same setup with Terraform. The `hashicorp/oci` provider at version 5.x exposes `oci_kms_vault`, `oci_kms_key`, and `oci_vault_secret` as first-class resources.

### Vault, Key, and Secret Resources

{% highlight hcl %}
# versions.tf
terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = "~> 5.0"
    }
  }
}

# vault.tf
resource "oci_kms_vault" "terraform_vault" {
  compartment_id = var.compartment_ocid
  display_name   = "vault-terraform-prod"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "secrets_key" {
  compartment_id      = var.compartment_ocid
  display_name        = "key-terraform-secrets"
  management_endpoint = oci_kms_vault.terraform_vault.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_vault_secret" "db_password" {
  compartment_id = var.compartment_ocid
  vault_id       = oci_kms_vault.terraform_vault.id
  key_id         = oci_kms_key.secrets_key.id
  secret_name    = "db-admin-password"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.db_admin_password)
    name         = "initial-version"
  }
}
{% endhighlight %}

The `management_endpoint` attribute on `oci_kms_vault` is computed after the vault is created and flows directly into `oci_kms_key` — Terraform resolves this dependency automatically. You do not need to call out to the CLI to get the endpoint like we did in the manual steps above.

Notice that `oci_vault_secret` accepts the plaintext value through `base64encode(var.db_admin_password)`. Terraform handles the encoding, so your variable holds the actual password. Mark the variable `sensitive = true` so the value is redacted in plan and apply output:

{% highlight hcl %}
# variables.tf
variable "compartment_ocid" {
  type        = string
  description = "OCID of the compartment where Vault resources will be created"
}

variable "db_admin_password" {
  type        = string
  sensitive   = true
  description = "Database admin password — pass via TF_VAR_db_admin_password or pipeline secret"
}
{% endhighlight %}

> **State file note**: marking the variable `sensitive = true` prevents the value from appearing in `terraform plan` and `terraform apply` output, but Terraform writes the value to state in plaintext. If your state backend is an OCI Object Storage bucket, ensure it has appropriate access controls. The safest approach is to use Terraform to create the vault, key, and secret container (with `oci_vault_secret` holding a placeholder), then write the real credential to Vault in a separate CI step using the OCI CLI.

## Reading Secrets in Terraform

This is the pattern that pays off in practice. A Terraform configuration that provisions application infrastructure — databases, compute instances, Kubernetes workloads — needs to reference credentials without storing them inline. The `oci_secrets_secretbundle` data source retrieves a secret's current version at plan/apply time.

{% highlight hcl %}
# Read an existing secret from OCI Vault
data "oci_secrets_secretbundle" "db_password" {
  secret_id = var.db_password_secret_ocid
}

# Decode the base64 payload and mark it sensitive
locals {
  db_password = sensitive(base64decode(
    data.oci_secrets_secretbundle.db_password.secret_bundle_content[0].content
  ))
}

# Use the decoded value in a resource
resource "oci_database_autonomous_database" "app_db" {
  compartment_id = var.compartment_ocid
  db_name        = "appdb"
  admin_password = local.db_password
  cpu_core_count = 1
  data_storage_size_in_tbs = 1
  db_workload    = "OLTP"
  is_auto_scaling_enabled = false
  display_name   = "app-autonomous-db"
}
{% endhighlight %}

The `var.db_password_secret_ocid` is the only thing that needs to be in your Terraform variables — the OCID of the secret, not the value. OCIDs are safe to commit. Add the variable declaration:

{% highlight hcl %}
variable "db_password_secret_ocid" {
  type        = string
  description = "OCID of the OCI Vault secret holding the database admin password"
}
{% endhighlight %}

The `sensitive()` wrapper on the local value ensures that Terraform treats the decoded password as sensitive throughout the configuration — it will not appear in plan output or in the values displayed for any resource attribute that references it.

## Updating Secrets and Managing Versions

Updating a secret creates a new version. The previous version is retained and can be scheduled for deletion or left in place for rollback purposes.

{% highlight bash %}
# Create a new version (rotation)
NEW_SECRET=$(echo -n "new-rotated-password" | base64)

oci vault secret update-base64 \
    --secret-id $SECRET_OCID \
    --secret-content-content "$NEW_SECRET" \
    --secret-content-content-type "BASE64"

# List all versions and their status
oci vault secret-version list \
    --secret-id $SECRET_OCID \
    --all \
    --query 'data[*].{Version:"version-number", Status:"lifecycle-state", Created:"time-created"}'
{% endhighlight %}

After rotation, the `oci_secrets_secretbundle` data source returns the latest enabled version by default. Any Terraform run that follows will pick up the new value automatically — no changes to the Terraform configuration required. This is the entire point of the data source approach: your infrastructure code references the secret by OCID, and Vault handles the versioning.

To schedule an old version for deletion after confirming the new credential is working:

{% highlight bash %}
# Schedule version 1 for deletion (30 days from now)
oci vault secret-version schedule-secret-version-deletion \
    --secret-id $SECRET_OCID \
    --secret-version-number 1 \
    --time-of-deletion "$(date -u -v+30d '+%Y-%m-%dT%H:%M:%SZ')"
{% endhighlight %}

## IAM Policy for Vault Access

OCI Vault access is controlled through IAM policies. A Terraform runner or CI/CD service account needs read access to secrets and use access to the vault and keys. The policy statements follow OCI's standard verb and resource-type syntax.

The three statements required for reading secrets in a pipeline:

{% highlight bash %}
# Minimal policy for a CI/CD service account to read secrets:
# Allow group terraform-runners to read secret-family in compartment infra-prod
# Allow group terraform-runners to use vaults in compartment infra-prod
# Allow group terraform-runners to use keys in compartment infra-prod
{% endhighlight %}

Manage this policy with Terraform alongside the rest of your IAM configuration:

{% highlight hcl %}
# iam.tf
resource "oci_identity_policy" "vault_read_policy" {
  compartment_id = var.tenancy_ocid
  name           = "terraform-vault-read"
  description    = "Allow Terraform CI/CD to read secrets from Vault"

  statements = [
    "Allow group terraform-runners to read secret-family in compartment infra-prod",
    "Allow group terraform-runners to use vaults in compartment infra-prod",
    "Allow group terraform-runners to use keys in compartment infra-prod",
  ]
}
{% endhighlight %}

The distinction between `read` and `use` matters here. `read secret-family` grants permission to call `GetSecretBundle` — the API the `oci_secrets_secretbundle` data source and `oci secrets secret-bundle get` CLI command use. `use vaults` and `use keys` are required for the decryption operations that happen transparently when a secret is retrieved. Without all three statements, secret retrieval will fail with a 404 or authorization error depending on which permission is missing.

If your pipeline runs using instance principals or dynamic groups — which is the recommended approach for OCI DevOps pipelines and Compute-based runners — substitute `group terraform-runners` with `dynamic-group terraform-runners-dg` or `any-user` scoped appropriately.

## Security Considerations

**Never output secret values in Terraform.** Avoid `output` blocks that reference the decoded local value. If you need to confirm a secret was read correctly, output the secret OCID or the version number — not the payload. Use `sensitive = true` on any output that might inadvertently reference a sensitive local.

**Secret OCIDs are safe to version-control; secret values are not.** The OCID identifies the secret without disclosing its contents. Storing OCIDs in `terraform.tfvars`, pipeline parameters, or even committed variable files is fine. Storing the `TF_VAR_db_admin_password` value anywhere near your repository is not.

**Enable Vault audit logging.** All secret access operations are logged to OCI Audit automatically — `GetSecretBundle` calls appear as audit events with the caller's principal, timestamp, and secret OCID. This gives you a complete read trail without any additional configuration. Review audit logs periodically and set up alerting for access patterns that do not match your expected pipeline behavior.

**Set secret expiry for rotation reminders.** OCI Vault allows you to set a `current-version-expiry-time` on a secret. When the current version expires, the secret moves to a `PENDING` state and access fails until a new version is created. For production credentials on a rotation schedule, configure expiry to enforce that rotation actually happens rather than relying on calendar reminders.

**Use compartment-scoped policies, not tenancy-level grants.** The policy example above scopes the statements to `compartment infra-prod`. Avoid writing Vault access policies at the tenancy level — they grant access to every vault across every compartment in the tenancy. Compartment-scoped policies follow the principle of least privilege and make it straightforward to audit which groups have access to which vaults.

## Testing and Validation

After provisioning your Terraform configuration, validate that the data source is working by running a targeted plan and checking the state:

{% highlight bash %}
# Confirm the secret bundle data source resolved correctly
terraform state show 'data.oci_secrets_secretbundle.db_password'
{% endhighlight %}

The output will show `secret_bundle_content` populated with the base64 content. The decoded value will be redacted if you used `sensitive()` on the local.

To validate the IAM policy is working correctly before running a full pipeline, test secret retrieval as the service principal your pipeline uses:

{% highlight bash %}
# Test retrieval using the OCI CLI profile configured for the CI service account
oci secrets secret-bundle get \
    --secret-id $SECRET_OCID \
    --profile ci-runner \
    --query 'data."secret-bundle-content".content' \
    --raw-output | base64 --decode
{% endhighlight %}

If this fails with a 404, the `read secret-family` policy statement is missing or the principal is not in the correct group. If it fails with an authorization error on key operations, the `use keys` statement is missing.

## Best Practices

**Create one vault per environment, not one vault per secret.** A vault is a logical boundary for access control and audit. Separate production and non-production secrets into separate vaults in separate compartments, and use IAM policies to restrict cross-environment access. Do not create a new vault for every application — the MEK and vault overhead is not designed for that granularity.

**Manage vault and key creation in a separate Terraform root module from application infrastructure.** Vault and key resources are long-lived and should not be destroyed and recreated alongside application changes. A separate `terraform apply` for platform infrastructure — vaults, keys, IAM policies — versus application infrastructure reduces blast radius and makes the dependency direction explicit: application Terraform reads from Vault, platform Terraform writes to it.

**Prefer the data source pattern over creating secrets in Terraform for production credentials.** The `oci_vault_secret` Terraform resource is useful for bootstrapping and for secrets that Terraform genuinely owns (generated passwords, certificates). For credentials that originate outside Terraform — database passwords set by a DBA, API keys issued by a third-party service — the correct pattern is to write them to Vault out-of-band and reference them via `oci_secrets_secretbundle`. This keeps the credential write path separate from the infrastructure apply path.

**Do not delete old secret versions immediately after rotation.** OCI Vault's version history is your rollback path. Schedule old versions for deletion using `time-of-deletion` with a buffer that matches your deployment rollout window — if a rolling deployment takes 30 minutes, give yourself at least that long before the old credential version is gone. Immediate deletion means an immediate, unrecoverable failure if the new credential has a problem.

## Conclusion

OCI Vault fills the same role as Azure Key Vault or AWS Secrets Manager — a managed store where secrets live that is not a git repository, a CI/CD variable file, or a `terraform.tfvars` on a developer's laptop. The resource model is straightforward once the three levels are clear: vault as the container, master encryption key as the encryption control, and secret as the versioned payload. The Terraform data source pattern for reading secrets keeps pipelines clean — the secret OCID goes into your variable files, the actual credential never leaves Vault, and a rotation does not require any change to your Terraform configuration.

Start with a Default vault for most workloads, use AES-256 keys for symmetric secrets, and adopt the compartment-scoped IAM policy pattern from the start. The audit trail is automatic; make sure you are actually reviewing it. And keep the credential write path separate from the infrastructure apply path — the two belong in different operational contexts even if they happen to share the same CI system.

Happy scripting!
