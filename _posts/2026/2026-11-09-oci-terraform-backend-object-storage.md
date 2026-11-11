---
title: 'Terraform OCI Backend: Securing State in Object Storage'
author: Victor Silva
date: 2026-11-09T14:30:04+00:00
layout: post
permalink: /oci-terraform-backend-object-storage/
excerpt: 'Terraform 1.12 added a native backend "oci" for Object Storage. Build a Vault-encrypted, versioned state bucket with least-privilege IAM on Always Free.'
categories:
  - OCI
  - Security
  - Terraform
tags:
  - terraform-oci-backend
  - terraform-state
  - oci-object-storage
  - oci-vault
  - oci-iam
  - oci-always-free
---

Here is a policy I would happily have written a year ago, straight off the HashiCorp documentation for the new Terraform OCI backend, which keeps state in Object Storage:

{% highlight text %}
Allow group tfstate-operators to manage objects in compartment tfstate
  where all {
    target.bucket.name = 'tfstate-prod',
    any {
      request.permission = 'OBJECT_INSPECT',
      request.permission = 'OBJECT_READ',
      request.permission = 'OBJECT_CREATE',
      request.permission = 'OBJECT_DELETE'
    }
  }
{% endhighlight %}

Four permissions, one bucket, no `manage object-family in tenancy`. It looks like textbook least privilege. It also breaks on your second `terraform apply`.

The reason is one line in that reference. `PutObject` on a *new* object needs `OBJECT_CREATE`. `PutObject` on an object that *already exists* needs `OBJECT_OVERWRITE`. The first apply creates `terraform.tfstate`, so it works. Every apply after that overwrites the same object, and `OBJECT_OVERWRITE` is not in HashiCorp's list. I first spotted it by reading the two references side by side, then ran it on an Always Free tenancy to be sure: the first apply went through, the second one died with `Failed to save state` on a `PutObject`. The policies later in this post include the missing permission.

That gap is a good excuse to go through the whole setup carefully. Terraform 1.12 added a native `backend "oci"` that stores state in Object Storage and handles locking without a second service. Oracle now marks the old S3-compatible approach as deprecated. Everything you need to harden the state bucket (a Vault key, versioning, lifecycle rules, access logs, scoped IAM) fits inside the Always Free tier. This post builds that bucket end to end, migrates a local state into it, and goes through the parts the docs skip.

## Your State File Is a Secrets File

If you've read my [post on managing OCI Vault secrets with Terraform]({% link _posts/2026/2026-04-06-oci-vault-secrets-management-terraform.md %}), you already know where this is going. Terraform state holds every attribute of every resource it manages, and on OCI that includes things you'd never paste into Slack.

Terraform 1.10 added ephemeral resources and 1.11 added write-only arguments (`*_wo` plus `*_wo_version`), which keep values out of plan and state entirely. That only helps if the provider implements them. As of `oracle/oci` v9.12.1 I couldn't find a single ephemeral resource or write-only argument. The docs tree has no ephemeral section, the changelog never mentions either feature, and a code search for `EphemeralResource` in the provider repo comes back empty. The provider now muxes in terraform-plugin-framework, so this may change. Re-check before you rely on what follows.

In practice, today:

- `oci_vault_secret` with `secret_content.content` stores the secret value in state. Use `enable_auto_generation = true` when you can, so Vault generates the value and Terraform never sees it.
- The `oci_secrets_secretbundle` data source writes the decoded secret into state. Avoid it in stacks whose state many people can read.
- The `tls_private_key` resource stores the private key PEM in state, in plaintext. There *is* an `ephemeral "tls_private_key"` (tls provider v4.1.0), but an ephemeral value is only useful when a write-only argument consumes it, and no OCI resource has one. Generate SSH and API keys outside Terraform and pass in the public half.
- `sensitive = true` on outputs hides them from CLI output. The value is still in state.

A customer-managed key on the bucket doesn't change any of that. Encryption at rest protects the bytes on Oracle's disks. Anyone with `OBJECT_READ` on the state object gets the decrypted JSON, private keys included. So the real controls here are who can read the object and whether you can find out that they did. Encryption is the baseline under those.

## How the Terraform OCI Backend Uses Object Storage

Before writing any IAM, it helps to know exactly which API calls the backend makes. I read through `internal/backend/remote-state/oci/` in the Terraform source (mostly `client.go`), and the design is tidy.

**Locking.** `Lock()` sends a `PutObject` for `<state path>.lock` with the header `If-None-Match: *`. That conditional create only succeeds if no object with that name exists. If someone else holds the lock, the PUT fails, the backend GETs the existing lock object, and you get its `LockInfo` JSON (ID, who, operation, created) in the error message.

**Unlocking.** `Unlock()` GETs the lock, checks that the lock ID matches yours, then calls `DeleteObject` with `If-Match: <etag>`. That's a compare-and-delete: a slow, stale unlock can't remove a newer lock that someone else took in the meantime.

**Reading state.** A `HeadObject`, then a `GetObject` with `If-Match: <etag>`, then an MD5 check against `Content-MD5` or `opc-multipart-md5`.

**Writing state.** A plain `PutObject` with `Content-MD5`. This write is not conditional, so correctness depends on the lock. Large states switch to multipart upload, falling back to a single-part PUT if multipart fails.

One detail matters a lot for encryption. The backend's `kms_key_id` argument is sent as `opc-sse-kms-key-id` **only on the state PUT**. The lock object PUT carries no encryption headers, so it gets whatever the bucket's default encryption is. Lock files contain your username, hostname and operation, which isn't secret, but if your compliance story is "everything in this bucket uses our CMK", the key has to be set on the bucket. Setting it only in the backend block won't get you there.

Paths follow a predictable layout:

| Workspace | Object name |
|---|---|
| `default` | `<key>` (default `terraform.tfstate`) |
| any other | `<workspace_key_prefix>/<workspace>/<key>` (prefix default `tf-state-env`) |
| lock | `<state object name>.lock` |

Listing workspaces is a `ListObjects` with that prefix, which needs `OBJECT_INSPECT`. Put all of that together and the permission set for an operator is `OBJECT_INSPECT`, `OBJECT_READ`, `OBJECT_CREATE`, `OBJECT_OVERWRITE` and `OBJECT_DELETE`. That's five. HashiCorp's page lists the first four minus overwrite.

## State Bucket Architecture

Two stacks, two kinds of identity:

{% highlight text %}
  bootstrap admin (one-time, then rarely)
        │  manages vault, key, bucket, policies, logs
        ▼
 ┌──────────────────────── compartment: tfstate ────────────────────────┐
 │                                                                       │
 │  Vault (DEFAULT)  ──►  AES-256 key (SOFTWARE)                         │
 │                              │ bucket default encryption              │
 │                              ▼                                        │
 │  Bucket: tfstate-prod   NoPublicAccess · versioning Enabled           │
 │    ├── bootstrap/terraform.tfstate                                    │
 │    ├── network/terraform.tfstate   (+ .lock while running)            │
 │    └── apps/terraform.tfstate                                         │
 │          │                                                            │
 │          ├── lifecycle: delete previous versions after 30 days        │
 │          │             abort multipart uploads after 1 day            │
 │          └── service logs (read + write) ──► Log group tfstate-access │
 └───────────────────────────────────────────────────────────────────────┘
        ▲                                   ▲
        │ objects only, one bucket          │ objects only, one prefix
  group tfstate-operators            dynamic group ci-runners
  (SecurityToken auth)               (InstancePrincipal on an A1/E2 VM)
{% endhighlight %}

The bootstrap admin creates the bucket, key and policies. Operators and CI only get object-level permissions and never `manage buckets`, because that's where `PAR_MANAGE` (pre-authenticated requests, which are bearer URLs) lives.

## Prerequisites

- Terraform **1.12.0 or later**. The examples were written against 1.17.1 and validated end to end (on 2026-11-11) with Terraform 1.15.5, `oracle/oci` v9.12.1 and OCI CLI 3.86 in `sa-saopaulo-1`.
- OCI provider `oracle/oci` ~> 9.12.
- OCI CLI configured, with an identity that can create vaults, keys, buckets, policies in the target compartment *and* a policy in the root compartment (the lifecycle rule needs one there, more on that below).
- A compartment for state. I use one called `tfstate`. My [OCI IAM with Terraform post]({% link _posts/2026/2026-01-09-oci-iam-terraform.md %}) covers building compartments and groups as code.

Check the basics:

{% highlight bash %}
terraform version            # must be >= 1.12.0
oci --version
oci os ns get --query data --raw-output   # your Object Storage namespace
{% endhighlight %}

Write that namespace down. It is **not** your tenancy name, and copying the tenancy name into the backend block is the most common reason `terraform init` comes back with a 404.

If this is a fresh Always Free tenancy, read the [zero-bill lab guide]({% link _posts/2026/2026-09-08-oci-always-free-tier-security-guide.md %}) first. Nothing in this post needs a paid account, but the quota and budget guardrails there are worth having before you start creating keys.

## Bootstrapping the Object Storage State Bucket

There's a chicken-and-egg problem: the bucket that holds state has to be created by Terraform, and that Terraform needs somewhere to keep its state. The answer is boring and it works. Run the bootstrap stack with local state, then migrate it into the bucket it just created.

### The Vault and Customer-Managed Key

{% highlight hcl %}
terraform {
  required_version = ">= 1.12.0"
  required_providers {
    oci = { source = "oracle/oci", version = "~> 9.12" }
  }
  # no backend block yet: local state, migrated later
}

variable "tenancy_ocid"   {}
variable "compartment_id" {}
variable "region"         { default = "sa-saopaulo-1" }

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# DEFAULT vault is Always Free. Virtual private vaults are not.
resource "oci_kms_vault" "state" {
  compartment_id = var.compartment_id
  display_name   = "tfstate-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "state" {
  compartment_id      = var.compartment_id
  display_name        = "tfstate-key"
  management_endpoint = oci_kms_vault.state.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 32 # bytes, so AES-256
  }
}
{% endhighlight %}

Both choices here are about the free tier. Virtual private vaults are billed, so `DEFAULT`. Software-protected master keys are all free, while HSM keys share a pool of 20 key versions across the tenancy and every rotation burns one. I'd rather not have the state key competing for that budget.

`key_shape.length` is in bytes. `32` is AES-256. People write `256` here and get a validation error.

### The Two Service Policies

Object Storage encrypts and decrypts on your behalf, so the regional Object Storage service principal needs permission to use the key. Scope it to this one key:

{% highlight hcl %}
resource "oci_identity_policy" "objectstorage_kms" {
  compartment_id = var.compartment_id
  name           = "objectstorage-use-tfstate-key"
  description    = "Allow Object Storage to use the tfstate key"
  statements = [
    "Allow service objectstorage-${var.region} to use keys in compartment id ${var.compartment_id} where target.key.id = '${oci_kms_key.state.id}'",
  ]
}

# Lifecycle rules need this one in the ROOT compartment
resource "oci_identity_policy" "objectstorage_lifecycle" {
  compartment_id = var.tenancy_ocid
  name           = "objectstorage-lifecycle"
  description    = "Allow Object Storage lifecycle to purge old state versions"
  statements = [
    "Allow service objectstorage-${var.region} to manage object-family in compartment id ${var.compartment_id}",
  ]
}
{% endhighlight %}

The service name includes the region identifier (`objectstorage-sa-saopaulo-1`). Get it wrong, or put the key in a different region from the bucket, and the bucket create fails with a KMS authorization error that doesn't tell you much. Both `compartment <name>` and `compartment id <ocid>` are valid policy syntax. I use the OCID form here because it survives a compartment rename.

The identity running the bootstrap also needs `KEY_ASSOCIATE` (granted by `use key-delegate`) to attach a key to a bucket. If you're running as a tenancy admin you already have it. If not, that's the error you'll hit.

### The Versioned, Encrypted Bucket

{% highlight hcl %}
resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id        = var.compartment_id
  namespace             = data.oci_objectstorage_namespace.ns.namespace
  name                  = "tfstate-prod" # no dots, the oci backend rejects them
  access_type           = "NoPublicAccess"
  versioning            = "Enabled"
  storage_tier          = "Standard"     # cannot be changed after create
  kms_key_id            = oci_kms_key.state.id
  object_events_enabled = true

  depends_on = [oci_identity_policy.objectstorage_kms]

  lifecycle {
    prevent_destroy = true
  }
}
{% endhighlight %}

Line by line, since every attribute here was a decision:

- **`name`**: the backend validates bucket names against `^[a-zA-Z0-9_-]+$`. OCI itself allows periods in bucket names, so `tfstate.prod` will create fine and then fail at `terraform init`.
- **`access_type`**: `NoPublicAccess` is already the default. I set it anyway so a policy-as-code check can assert on it explicitly.
- **`versioning`**: off by default. Once you enable it you can never go back to `Disabled`, only `Suspended`. For a state bucket that's exactly what you want.
- **`kms_key_id`**: the bucket-level default key, which also covers the `.lock` objects the backend creates without encryption headers.
- **`object_events_enabled`**: lets you hang an Events rule on object writes later.
- **`prevent_destroy`**: a `terraform destroy` in the wrong directory shouldn't be able to delete every state you have.

Policy propagation can lag a few seconds behind the API response. If the bucket create fails once with a KMS authorization error right after the policy was created, run apply again before you start debugging. A `time_sleep` resource between the two also works.

### Lifecycle Instead of Retention Rules

Every apply writes a new version of the state object, so with versioning on, old versions pile up forever unless something cleans them up:

{% highlight hcl %}
resource "oci_objectstorage_object_lifecycle_policy" "tfstate" {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.tfstate.name

  rules {
    name        = "purge-old-state-versions"
    action      = "DELETE"
    target      = "previous-object-versions"
    time_amount = 30
    time_unit   = "DAYS"
    is_enabled  = true
  }

  rules {
    name        = "abort-stale-multipart"
    action      = "ABORT"
    target      = "multipart-uploads"
    time_amount = 1
    time_unit   = "DAYS"
    is_enabled  = true
  }

  depends_on = [oci_identity_policy.objectstorage_lifecycle]
}
{% endhighlight %}

The `previous-object-versions` target only exists on buckets with versioning `Enabled` or `Suspended`. Rules typically run within about ten minutes but can take up to 24 hours, so don't expect old versions to vanish the moment you apply. The multipart rule is there because large states go through multipart upload, and an interrupted one leaves parts behind that count toward storage.

Somebody always asks why not use retention rules and make the state WORM. It's a reasonable instinct for an audit-sensitive file, and it doesn't work, for three documented reasons:

1. You can't add retention rules to a bucket that has versioning enabled.
2. You can't enable versioning on a bucket with active retention rules.
3. Retention blocks overwrites, and Terraform overwrites the state object on every apply.

Locked retention rules also become irreversible after a mandatory 14-day delay ("not even a tenancy administrator or Oracle Support can delete a locked rule"), so don't experiment on a bucket you care about. Versioning plus a 30-day purge gives you a month of rollback points, which is what a state bucket actually needs.

### Object Storage Access Logs

This is the piece most setups skip, and the reason is easy to miss. The OCI Audit overview says Object Storage "supports logging for bucket-related events, but not for object-related events." Audit will tell you someone changed the bucket's versioning. It will **not** tell you someone downloaded `network/terraform.tfstate` with the database password in it.

For that you need Object Storage service logs in the Logging service, which has a 10 GB/month Always Free allowance:

{% highlight hcl %}
resource "oci_logging_log_group" "tfstate" {
  compartment_id = var.compartment_id
  display_name   = "tfstate-access"
}

resource "oci_logging_log" "tfstate_read" {
  display_name       = "tfstate-read"
  log_group_id       = oci_logging_log_group.tfstate.id
  log_type           = "SERVICE"
  retention_duration = 30
  is_enabled         = true

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "read"   # GET, HEAD, LIST
      resource    = oci_objectstorage_bucket.tfstate.name
      service     = "objectstorage"
      source_type = "OCISERVICE"
    }
  }
}

resource "oci_logging_log" "tfstate_write" {
  display_name       = "tfstate-write"
  log_group_id       = oci_logging_log_group.tfstate.id
  log_type           = "SERVICE"
  retention_duration = 30
  is_enabled         = true

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "write"  # PUT, POST, DELETE
      resource    = oci_objectstorage_bucket.tfstate.name
      service     = "objectstorage"
      source_type = "OCISERVICE"
    }
  }
}
{% endhighlight %}

The `service` and `resource` values follow the OCI service-log conventions. The provider's own example doesn't show them, but `oci logging service list` does: service `objectstorage`, resource type `bucket`, categories `read` and `write`. `retention_duration` goes in 30-day increments up to 180.

One caveat if you plan to use these logs as compliance evidence: Oracle delivers Object Storage service logs "on a best effort basis." They're great for detection and investigation. Don't promise an auditor they're complete.

Now apply the whole bootstrap stack with local state:

{% highlight bash %}
terraform init
terraform apply
{% endhighlight %}

## Configuring backend "oci" and Migrating Local State

Add a `backend.tf` to the bootstrap stack:

{% highlight hcl %}
terraform {
  backend "oci" {
    bucket              = "tfstate-prod"
    namespace           = "axxxxxxxxxxx"   # from: oci os ns get
    region              = "sa-saopaulo-1"
    key                 = "bootstrap/terraform.tfstate"
    auth                = "SecurityToken"
    config_file_profile = "tfstate"
    # kms_key_id is optional here: the bucket default key covers state and lock
  }
}
{% endhighlight %}

Then authenticate and migrate:

{% highlight bash %}
oci session authenticate --region sa-saopaulo-1 --profile-name tfstate
terraform init -migrate-state      # answer "yes" to copy the local state
terraform plan                     # should report no changes
oci os object list --bucket-name tfstate-prod --prefix bootstrap/
rm terraform.tfstate terraform.tfstate.backup   # only after the remote copy checks out
{% endhighlight %}

Don't skip that `rm`. A leftover local `terraform.tfstate` is the plaintext copy you just spent an hour avoiding, and it's the file that ends up in a git commit three months later.

### Picking an Auth Method

The backend supports `ApiKey` (the default), `InstancePrincipal`, `InstancePrincipalWithCerts`, `ResourcePrincipal`, `SecurityToken` and `OKEWorkloadIdentity`. Matching is case-insensitive, so the docs' spelling `APIKey` also works. A few rules the code enforces that the schema doesn't make obvious:

- `region` is required for `InstancePrincipal`, `InstancePrincipalWithCerts`, `ResourcePrincipal` and `SecurityToken`.
- `config_file_profile` is required for `SecurityToken`.
- `namespace` and `bucket` can't come from environment variables. Everything optional can, with an `OCI_` prefix or none. I haven't checked how the backend handles the case of those variable names, so test the exact spelling in your tenancy before putting it in CI.

For humans I prefer `SecurityToken`: a short-lived session from `oci session authenticate` and no long-lived API key in `~/.oci`. Sessions expire (about an hour by default is the commonly cited figure, and I haven't checked what the backend does if a token dies mid-write), so refresh before a long apply.

For CI running on an Always Free A1 or E2 VM, use `InstancePrincipal` plus `region`. There's no config file and no key on disk, and the VM's identity comes from a dynamic group you can scope in policy.

HashiCorp has one warning I'd underline: don't pass secrets through `-backend-config`. Those values persist in `.terraform/` and in saved `*.tfplan` files. If you're using `ApiKey`, point `private_key_path` at a file. Don't inline the key.

### Workload Stacks and Cross-Stack Reads

Every other stack uses the same backend block with a different `key`, such as `network/terraform.tfstate`. To read outputs from another stack:

{% highlight hcl %}
data "terraform_remote_state" "network" {
  backend = "oci"
  config = {
    bucket    = "tfstate-prod"
    namespace = "axxxxxxxxxxx"
    region    = "sa-saopaulo-1"
    key       = "network/terraform.tfstate"
    auth      = "InstancePrincipal"
  }
}
{% endhighlight %}

This needs `OBJECT_READ` on that state object, and it exposes the **whole** state to the reader. There's no output-only read in this model. If your app stack reads the network stack's outputs, the app pipeline can read every secret the network stack holds. Keep that in mind when you decide which stacks share a bucket, or a prefix, or a policy.

## Least-Privilege IAM Policies for Terraform State

With the API calls mapped out, here's the policy for humans. It's the one from the opening, plus the permission it was missing:

{% highlight text %}
Allow group tfstate-operators to read buckets in compartment tfstate
  where target.bucket.name = 'tfstate-prod'

Allow group tfstate-operators to manage objects in compartment tfstate
  where all {
    target.bucket.name = 'tfstate-prod',
    any {
      request.permission = 'OBJECT_INSPECT',
      request.permission = 'OBJECT_READ',
      request.permission = 'OBJECT_CREATE',
      request.permission = 'OBJECT_OVERWRITE',
      request.permission = 'OBJECT_DELETE'
    }
  }
{% endhighlight %}

`manage objects` filtered by `request.permission` gives exactly the five operations the backend uses. The `read buckets` line is optional: in my lab the five-permission statement alone got through init, apply and re-apply. I keep it because it lets an operator run `oci os bucket get` to check the bucket's posture without being able to change it, but drop it if you want the strict minimum. Note what's absent: `OBJECT_VERSION_DELETE`, so operators can't purge history, and anything bucket-level, so no PARs. A few weeks after rollout, it's worth [checking which of those permissions nobody actually uses]({% link _posts/2026/2026-08-02-oci-unused-iam-permissions.md %}) and trimming further.

One thing to watch: `target.bucket.name` matches case-insensitively. If you have `tfstate-prod` and `TFSTATE-PROD` in the same compartment (please don't), this policy covers both.

For CI, I'd go further and scope each runner to one stack's prefix with `target.object.name`. My first version of this policy looked like the obvious one, a single statement with the prefix condition next to the bucket name:

{% highlight text %}
# Broken: terraform init fails under this policy
Allow dynamic-group ci-runners to manage objects in compartment tfstate
  where all {
    target.bucket.name = 'tfstate-prod',
    target.object.name = /network\/*/,
    any {
      request.permission = 'OBJECT_INSPECT',
      request.permission = 'OBJECT_READ',
      request.permission = 'OBJECT_CREATE',
      request.permission = 'OBJECT_OVERWRITE',
      request.permission = 'OBJECT_DELETE'
    }
  }
{% endhighlight %}

Half of it works. The pattern does behave as a prefix match: as the runner identity, a PUT to `network/...` went through and a PUT to `apps/...` was denied. `ListObjects` is the half that doesn't. A list call isn't about any single object, so the `target.object.name` condition can't match it, and the whole statement fails for that request. `terraform init` lists workspaces first, so CI never gets past it:

{% highlight text %}
Error: Failed to get existing workspaces: Error returned by ObjectStorage
Service. Http Status Code: 404. Error Code: BucketNotFound.
{% endhighlight %}

The fix is to split listing from everything else. `OBJECT_INSPECT` gets a bucket-only condition, and the four permissions that touch object contents keep the prefix:

{% highlight text %}
Allow dynamic-group ci-runners to manage objects in compartment tfstate
  where all {
    target.bucket.name = 'tfstate-prod',
    request.permission = 'OBJECT_INSPECT'
  }

Allow dynamic-group ci-runners to manage objects in compartment tfstate
  where all {
    target.bucket.name = 'tfstate-prod',
    target.object.name = /network\/*/,
    any {
      request.permission = 'OBJECT_READ',
      request.permission = 'OBJECT_CREATE',
      request.permission = 'OBJECT_OVERWRITE',
      request.permission = 'OBJECT_DELETE'
    }
  }
{% endhighlight %}

With this pair, the runner could init, apply, overwrite state and create a workspace under `network/`, and it got a 404 on every read, write or delete under `apps/`, including a GET of another stack's state, which is exactly what `terraform_remote_state` would try. The trade-off is that `OBJECT_INSPECT` is bucket-wide, so the runner can *list* every object name in the bucket. It sees that `apps/terraform.tfstate` exists. It can't read it.

The second trap is workspaces. With the default `workspace_key_prefix`, a non-default workspace lives at `tf-state-env/<workspace>/network/terraform.tfstate`, which is outside `network/`. `terraform workspace new staging` fails on the lock PUT to `tf-state-env/staging/network/terraform.tfstate.lock`. Put the prefix under the stack's own path in the backend block:

{% highlight hcl %}
terraform {
  backend "oci" {
    # ...
    key                  = "network/terraform.tfstate"
    workspace_key_prefix = "network/env" # workspaces: network/env/<name>/network/terraform.tfstate
  }
}
{% endhighlight %}

I tested this with a user in a group, not with a dynamic group on a real runner. The policy conditions are the same, but run one plan from the actual runner before you rely on it.

### What About OCI Deny Policies?

OCI added IAM deny policies in November 2025. They're opt-in under Policies > Actions > Policy settings, only default-domain Administrators can enable them, and **enabling is permanent**. Deny beats allow, except that members of the default Administrators group are always exempt.

The two denies I'd want on a state bucket are "nobody creates PARs" and "nobody deletes versions." Built from the documented syntax, they'd look something like this:

{% highlight text %}
deny group tfstate-operators to { PAR_MANAGE } in compartment tfstate
  where target.bucket.name = 'tfstate-prod'
deny group tfstate-operators to { OBJECT_VERSION_DELETE } in compartment tfstate
  where target.bucket.name = 'tfstate-prod'
{% endhighlight %}

Treat these as untested. I wrote them from the syntax reference, not from an Oracle example. I also haven't confirmed that deny policies are available on a pure Always Free tenancy. I used `group tfstate-operators` instead of `any-user` deliberately: an `any-user` deny on `OBJECT_VERSION_DELETE` might also catch the Object Storage service principal and silently break your lifecycle rule. That's a guess on my part, and given that the opt-in can't be undone, I'd rather be conservative.

Without deny policies, the control for PARs is simpler: never grant `manage buckets` to anyone except the bootstrap admin, and check for strays regularly:

{% highlight bash %}
oci os preauth-request list --bucket-name tfstate-prod --all
{% endhighlight %}

## Migrating from the S3-Compatible Backend to backend "oci"

If you've been on OCI for a while, your state probably lives behind the `s3` backend pointed at `https://<namespace>.compat.objectstorage.<region>.oraclecloud.com`. On Terraform 1.6.4 and later that setup needs a whole list of flags (`skip_region_validation`, `skip_credentials_validation`, `skip_requesting_account_id`, `use_path_style`, `skip_s3_checksum`, `skip_metadata_api_check`, plus `endpoints.s3`), and it authenticates with a **Customer Secret Key**.

That key is the real reason to migrate. A Customer Secret Key is a long-lived static access/secret pair tied to a user, shown exactly once at creation, and you can't constrain it with conditions beyond the user's own policies. It's also the credential most likely to have been copied into a CI variable in 2021 and forgotten there.

Locking was the other weak point. There's no DynamoDB equivalent on OCI, so in practice most of these setups ran with no locking at all. Whether OCI's S3-compatible API honours the `If-None-Match` header that the S3 backend's `use_lockfile = true` relies on is something I haven't verified. Don't assume it does.

The migration itself is the same `-migrate-state` move as the bootstrap. Swap the `backend "s3"` block for `backend "oci"` (keeping the same object key if you want the same path), then:

{% highlight bash %}
terraform init -migrate-state
terraform plan    # expect no changes

# Once every stack has moved, find and remove the old keys
oci iam customer-secret-key list --user-id <user_ocid>
oci iam customer-secret-key delete --user-id <user_ocid> --customer-secret-key-id <key_id>
{% endhighlight %}

Delete the keys, don't just stop using them. And skip the `http` backend with a read/write PAR that you may see suggested: Oracle discourages it, and anyone holding a PAR URL can read and overwrite your state.

Coming from Azure, this will feel familiar: it's the same shape as the [remote state on Azure Blob Storage]({% link _posts/2022/2022-01-11-terraform-remote-state-azure-blob-storage.md %}) setup from 2022, minus the storage account keys. On GCP, the [Terraform GCS backend post]({% link _posts/2026/2026-10-29-terraform-gcs-backend-state-security.md %}) runs into a similar least-privilege trap, where the obvious role pair breaks lock release.

## Staying Inside the Always Free Limits

| Resource | Always Free allowance | What it means for state |
|---|---|---|
| Object Storage | 20 GB combined (Standard, IA, Archive) on free-only tenancies | Versions count. The lifecycle rule is mandatory, not optional |
| Object Storage API | 50,000 requests/month | Plenty for humans, tight for a CI loop |
| Vault master keys | All software-protected keys free | Use `SOFTWARE` |
| Vault HSM keys | 20 key versions total | Every rotation consumes one |
| Vault secrets | 150 secrets, 40 versions each | Shared with anything else you store |
| Logging | 10 GB/month | Two service logs on one bucket barely dent it |
| Notifications | 1M HTTPS, 1,000 email per month | Room for alerts on log queries later |
| Cross-region replication | Not free | Doubles storage and adds transfer, so skip it |

On a paid or trial account the split is 10 GB per tier instead of 20 GB combined. If you're coming off a trial with more than 20 GB stored, Oracle's documented behaviour is that all your objects get deleted when the trial ends. I haven't tested what happens to writes on a free-only tenancy that hits the cap, but I'd plan for "applies stop working".

The request budget is the one to think about. Going by the calls in `client.go`, a `plan` is roughly a HEAD and a GET for state plus a PUT and a DELETE for the lock, and an apply adds a state PUT and some extra reads. Call it 5 to 10 requests per run. That's my estimate from the source, not an Oracle number, but it puts 50,000 requests at several thousand runs a month. A drift check that runs `terraform plan` every minute, which is about 43,200 runs at roughly 5 requests each, would blow through it. If you want scheduled drift detection without burning requests, [Resource Manager's built-in drift detection]({% link _posts/2026/2026-08-20-oci-resource-manager-drift-detection.md %}) is the better tool.

## Testing the State Bucket, Lock, and IAM Policy

Run these against your own bucket. Everything in this section is what I got from a lab run on an Always Free tenancy, not what the docs predict.

### Bucket Posture

{% highlight bash %}
oci os bucket get --bucket-name tfstate-prod \
  --query 'data.{access:"public-access-type",ver:versioning,kms:"kms-key-id",events:"object-events-enabled"}'
{% endhighlight %}

You want `NoPublicAccess`, `Enabled`, an `ocid1.key...` value, and `true`.

{% highlight json %}
{
  "access": "NoPublicAccess",
  "events": true,
  "kms": "ocid1.key.oc1.sa-saopaulo-1.xxxx",
  "ver": "Enabled"
}
{% endhighlight %}

Don't go looking for the key on the state object itself. `oci os object head` on `bootstrap/terraform.tfstate` returns size, MD5, ETag and `version-id`, but no `opc-sse-kms-key-id` header, even with the CMK in place. The `kms-key-id` on the bucket is the evidence you get.

### The State Lock

Open two terminals. In the first, run `terraform apply` and leave it sitting at the approval prompt. In the second:

{% highlight text %}
$ terraform plan -lock-timeout=0s
Error: Error acquiring the state lock

Error message: Error returned by ObjectStorage Service. Http Status Code:
412. Error Code: IfNoneMatchFailed.
Message: The If-None-Match header is '*' but there is an existing entity
Operation Name: PutObject
Lock Info:
  ID:        5afec43e-0466-0c26-000f-2bd5e686877a
  Path:      lock-test/terraform.tfstate
  Operation: OperationTypeApply
  Who:       victor@erebor.local
  Version:   1.15.5
  Created:   2026-11-11 12:34:22.785106 +0000 UTC
{% endhighlight %}

That `412 IfNoneMatchFailed` is the conditional create from `client.go` doing its job. List the prefix while the first apply is still waiting and the lock sits next to the state:

{% highlight bash %}
oci os object list --bucket-name tfstate-prod --prefix bootstrap/
# bootstrap/terraform.tfstate
# bootstrap/terraform.tfstate.lock
{% endhighlight %}

Cancel the first apply and the `.lock` object disappears.

### The OBJECT_OVERWRITE Test

The opening of this post depends on this one, so I ran it. A throwaway user in a throwaway group, a trivial stack (one `terraform_data` resource) pointed at a fresh key, and four policy variants, each given two minutes to propagate:

| Policy | `read buckets` | `OBJECT_OVERWRITE` | put new object | overwrite object | apply 1 | apply 2 |
|---|---|---|---|---|---|---|
| HashiCorp docs | no | no | ok | denied | ok | **denied** |
| HashiCorp docs + `read buckets` | yes | no | ok | denied | ok | **denied** |
| five permissions | no | yes | ok | ok | ok | ok |
| five permissions + `read buckets` | yes | yes | ok | ok | ok | ok |

The "put" columns are plain `oci os object put` calls as the same user, outside Terraform. `OBJECT_OVERWRITE` is the only variable that matters. Here's what the second apply looks like without it:

{% highlight text %}
Error: Failed to save state

Error returned by ObjectStorage Service. Http Status Code: 404.
Error Code: BucketNotFound.
Message: Either the bucket named 'tfstate-lab' does not exist in the
namespace '...' or you are not authorized to access it
Operation Name: PutObject

Error: Failed to persist state to backend
{% endhighlight %}

Notice it's a 404, not a 403. OCI doesn't tell you that you lack a permission, it tells you the bucket doesn't exist. Terraform keeps the new state in `errored.tfstate` in your working directory when this happens, which is one more plaintext copy to clean up.

If your tenancy behaves differently, tell me in the comments.

### History and Restore

{% highlight bash %}
oci os object list-object-versions --bucket-name tfstate-prod --prefix bootstrap/ --all

# Incident drill: pull a previous version
oci os object get --bucket-name tfstate-prod \
  --name bootstrap/terraform.tfstate \
  --version-id <version_id> --file restored.tfstate
{% endhighlight %}

Grab the `version-id` of a `terraform.tfstate` entry, not a `.lock` one: with `--prefix` the listing mixes both, and asking for a lock's version ID on the state object returns `ObjectVersionNotFound`.

While you have `restored.tfstate` open, try this on any stack that uses `tls_private_key`:

{% highlight bash %}
grep -c "BEGIN RSA PRIVATE KEY\|BEGIN OPENSSH PRIVATE KEY" restored.tfstate
{% endhighlight %}

A non-zero count is your private key in plaintext, CMK and all.

### No PARs, and Someone Is Watching

{% highlight bash %}
oci os preauth-request list --bucket-name tfstate-prod --all   # expect empty
{% endhighlight %}

For the access logs, search the read log for GETs on the bucket. The Object Storage log reference documents the fields `bucketName`, `principalName`, `clientIpAddress`, `requestAction`, `requestResourcePath` and `statusCode`, and this query works as written, from `oci logging-search search-logs` or the Console's Logging Search:

{% highlight text %}
search "<compartment_ocid>/<log_group_ocid>/<log_ocid>"
  | where data.bucketName = 'tfstate-prod' and data.requestAction = 'GET'
  | select datetime, data.principalName, data.clientIpAddress, data.requestResourcePath, data.statusCode
{% endhighlight %}

After a lab session it came back with every ListObjects from `terraform init`, every lock PUT and every state GET, each with the principal and source IP. The events carry a few more fields worth alerting on: `authenticationType`, `userAgent` and `isPar`. A read on a state bucket with `isPar = true` should never happen if you followed the PAR advice above, so it's a cheap, high-signal alert.

Finally, the negative test: take a user out of `tfstate-operators` and run `terraform init` as them. You get `Failed to get existing workspaces` with a 404 `BucketNotFound`, not a 403. In my tenancy the removal took about two minutes to apply, and the user could still init during that window.

## Gotchas I'd Want to Know Up Front

**Stale locks.** Ctrl-C at the wrong moment, or a CI runner that gets killed, leaves `<key>.lock` behind. Run `terraform force-unlock <LOCK_ID>` with the ID from the error. Because unlock checks the ID and deletes with `If-Match`, a wrong ID fails cleanly. Your last resort is `oci os object delete --bucket-name tfstate-prod --object-name <key>.lock`, and only after confirming nobody is actually running.

**Lock files pile up as versions.** Every run creates the lock and then deletes it. With versioning on, that delete leaves a previous version behind, so a busy stack accumulates hundreds of tiny noncurrent `.lock` versions. They're small, and the 30-day lifecycle rule eats them, but they make `list-object-versions` output noisy. In the lab every plan or apply left one lock version plus one delete marker; a dozen runs on one stack gave me 22 entries for the `.lock` alone.

**IAM changes aren't instant, and denials look like 404s.** A new policy, user or API key needed 90 to 120 seconds before results were stable; at 60 seconds ListObjects was still failing intermittently. And OCI reports every denial in this post as `BucketNotFound`, so a 404 right after a policy change almost never means the bucket is gone. Wait two minutes before you start debugging the policy.

**Region and namespace.** The service policy must name the bucket's region. The key should live in the same region as the bucket. The namespace is the random-looking string from `oci os ns get`, never the tenancy name.

**Dots in bucket names.** OCI accepts them and the backend doesn't. Rename before you migrate, not after.

**Key lifecycle.** Rotating the Vault key doesn't re-encrypt existing objects; use Bucket Re-encryption for that. Disabling or scheduling deletion of the key should make the state unreadable. That's the expected behaviour, though Oracle's encryption page doesn't spell it out, so don't test it on the production bucket. Keep `prevent_destroy` on the key as well as the bucket if you're nervous.

## Terraform State Security Best Practices on OCI

**Split admin from operator.** The bootstrap stack and its identity manage the bucket, key and policies. Everyone else gets objects only. If an operator can run `manage buckets`, your PAR control is gone.

**One bucket per sensitivity level, not one per stack.** Prefix-scoped CI policies handle separation between stacks of similar sensitivity. A stack that holds database credentials and a stack that holds DNS records shouldn't share a reader, because `terraform_remote_state` hands over the whole file.

**Keep secrets out of state where the provider lets you.** `enable_auto_generation` on Vault secrets, keys generated outside Terraform, no `oci_secrets_secretbundle` data sources. Then look for ephemeral and write-only support in each OCI provider release, because once it lands most of this section gets simpler.

**Map to the controls you'll be asked about.** The CIS OCI Foundations Benchmark has controls for public buckets, CMK encryption, versioning and write-level Object Storage logging (check the current PDF for section numbers). In NIST 800-53 terms: SC-28, AC-6, AU-2/AU-12 and CP-9.

## Wrapping Up

You now have a state bucket that's private, versioned with a 30-day rollback window, encrypted with a free software-protected Vault key at the bucket level (so the lock files are covered too), logged for reads as well as writes, and reachable only through policies that grant the five object permissions the backend actually uses. All of it is inside Always Free, and the bootstrap state lives in the bucket it created.

The OBJECT_OVERWRITE gap is real, and it's the difference between a least-privilege policy that works and one that fails on the second day. After that, wire an alert on unexpected principals in the read log, and when the OCI provider finally ships write-only arguments, go back through your stacks and pull the secrets out of state for good.

Happy scripting!
