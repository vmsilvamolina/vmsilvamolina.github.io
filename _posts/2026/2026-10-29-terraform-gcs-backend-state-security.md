---
title: 'Terraform GCS Backend: Least-Privilege State Bucket on GCP'
author: Victor Silva
date: 2026-10-29T19:42:17+00:00
layout: post
permalink: /terraform-gcs-backend-state-security/
excerpt: "Terraform GCS backend: Object Admin is too broad, Creator + Viewer breaks locking. Build a 4-permission role, CMEK, soft delete and audit logs."
categories:
  - GCP
  - Security
  - Terraform
tags:
  - terraform-gcs-backend
  - terraform-state
  - google-cloud-storage
  - gcp-iam-conditions
  - cloud-kms
  - cloud-audit-logs
---

The Terraform GCS backend documentation has one line about permissions: the credentials need Storage Object Admin (`roles/storage.objectAdmin`) on the state bucket. A security reviewer will push back on that, and they'll be right. Object Admin includes `setRetention`, `overrideUnlockedRetention`, `restore`, `move` and object-level IAM, and Terraform calls none of them. So the reviewer suggests the obvious cut: Object Creator to write, Object Viewer to read. You bind both to the pipeline's service account, run `terraform init` against an empty prefix, and the backend answers with something like this:

{% highlight text %}
Error: ...

Additionally, unlocking the state file on Google Cloud Storage failed:
  ... 403 ...

You may have to force-unlock this state in order to use it again.
The GCloud backend acquires a lock during initialization to ensure
the initial state file is created.
{% endhighlight %}

That's abridged from the error strings in the backend source. The cause is one sentence on Google's IAM permissions page: "In order to replace existing objects, both `storage.objects.create` and `storage.objects.delete` permissions are required." Neither Creator nor Viewer has `delete`. The backend releases its lock by deleting a `.tflock` object, so the first unlock fails and leaves a stale lock. Clear it by hand and the next apply fails anyway, because overwriting `default.tfstate` is a replace. This is usually where teams go back to Object Admin and stop thinking about it.

What the backend needs is `storage.objects.get`, `create`, `delete` and `list`. No predefined role matches that, so you write a custom one. Then there's a second trap when you scope it with IAM Conditions: `list` can't be restricted by object name, and `terraform init` won't run without it.

This post builds the whole setup in Terraform: a dedicated state project, a CMEK-encrypted bucket with versioning and soft delete, a four-permission custom role per environment prefix, keyless access, and Data Access audit logs so you can see who ran `terraform state pull`. Examples target Terraform v1.17.1 and `hashicorp/google` v8.9.0. If you read my [Azure Blob Storage remote state post]({% link _posts/2022/2022-01-11-terraform-remote-state-azure-blob-storage.md %}), the shape is familiar. The IAM is where GCS differs.

## How the Terraform GCS Backend Stores State and Locks

I read `internal/backend/remote-state/gcs/` at the v1.17.1 tag before writing any IAM. It's short, and a few details drive everything below.

### Object layout

Both object names are built with `path.Join(prefix, workspace + ".tfstate")` (and `.tflock`). Workspaces sit flat under the prefix, with no `env:/` sub-path like the S3 backend:

{% highlight text %}
gs://acme-state-tfstate/
  envs/prod/default.tfstate     # default workspace
  envs/prod/default.tflock      # exists only while a lock is held
  envs/prod/blue.tfstate        # workspace "blue"
  envs/dev/default.tfstate
{% endhighlight %}

Leading slashes in the prefix are trimmed and a trailing one is added, so `envs/prod`, `envs/prod/` and `/envs/prod` are the same location to the backend. IAM Conditions don't normalise anything, which comes back later.

### The lock is a generation precondition

Locking writes a small JSON `LockInfo` to `<prefix>/<workspace>.tflock` with the Go client's `DoesNotExist` condition, which becomes `ifGenerationMatch=0`: the write only proceeds if no live object has that name. A second run gets `412 Precondition Failed`. Noncurrent versions don't count, so versioning doesn't interfere.

The lock ID Terraform prints is the object's **generation number**. Unlock is a delete with `GenerationMatch` set to that number, a compare-and-delete, so a `force-unlock` with a stale ID can't remove someone else's newer lock. That's also why this backend rejects non-numeric IDs with `Lock ID should be numerical value`. On a conflict, the backend reads the existing `.tflock` to show you who holds it, which is one more `storage.objects.get`.

### Every init lists the prefix

`terraform init` calls `Workspaces()`, which lists objects under the prefix with a `/` delimiter and keeps names ending in `.tfstate`. That's `storage.objects.list`, and if it's denied, init stops with `Failed to get existing workspaces`.

### Reads, writes, and which object gets your key

A state read is two GETs (content, then metadata for the MD5). A state write is an insert with **no** precondition, relying entirely on the lock.

The encryption detail is the one I'd have missed without the source. The backend's `encryption_key` (CSEK) and `kms_encryption_key` (CMEK) are applied to the **state object only**. The lock is written with neither, so it gets the bucket default. That's harmless by itself, since `LockInfo` holds an ID, operation, user, version, timestamp and path. It becomes a problem if you enforce CMEK-only encryption on the bucket and count on the backend argument for the key: the lock write carries no key and should be rejected. That's derived from source and provider docs, not reproduced, so test it. Or skip the question entirely: set `default_kms_key_name` on the bucket and leave the backend key arguments unset. Both objects are covered, and `terraform_remote_state` readers don't need any key config.

## The Four Permissions the GCS Backend Actually Needs

| Operation | API call | Permission |
|---|---|---|
| `terraform init` workspace listing | `objects.list` | `storage.objects.list` |
| Read state | `objects.get` ×2 | `storage.objects.get` |
| Acquire lock | `objects.insert`, `ifGenerationMatch=0` | `storage.objects.create` |
| Write state (overwrite) | `objects.insert` | `storage.objects.create` + `storage.objects.delete` |
| Release lock / `force-unlock` | `objects.delete`, `ifGenerationMatch=N` | `storage.objects.delete` |
| `terraform workspace delete` | `objects.delete` | `storage.objects.delete` |

The backend never reads bucket metadata, so `storage.buckets.get` isn't needed. Readers don't need KMS permissions either, because Cloud Storage decrypts CMEK objects for anyone allowed to read them. I expect the same for writes that use the bucket default key, and the tests at the end check it.

Object Admin adds object IAM (inert under uniform bucket-level access, but present), `setRetention`, `overrideUnlockedRetention`, `restore`, `move`, `update`, folder and managed-folder permissions, and multipart uploads. `overrideUnlockedRetention` is the worrying one: a pipeline holding it can shorten or remove object retention. Storage Object User (`roles/storage.objectUser`) is the closest predefined role, without the IAM and retention permissions, but it still has `move`, `restore`, `update` and the folder set.

The permission you can't drop has a cost of its own. `storage.objects.delete` works on **any generation**, current or noncurrent, so a compromised pipeline can wipe every version of your state. Versioning alone doesn't stop that. Soft delete does, and it's in the bucket config below.

## Why Terraform State Gets Its Own Google Cloud Project

Cloud Storage Data Access audit logs (`DATA_READ`, `DATA_WRITE`) are off by default. Without them, a `terraform state pull`, a `gcloud storage cat` or a console download leaves no trace. Admin Activity logs only cover bucket config and IAM. Data Access logging is set per service at project, folder or org level, and **you can't enable it for one bucket**. Turn it on for `storage.googleapis.com` in a project that also hosts a busy data lake and you log, and pay for, every object read in there. A project that holds only state keeps the volume tiny and the log reviewable.

It keeps IAM small too. The bootstrap identity owns the bucket, key, roles and audit config. Pipelines and humans get object permissions on a prefix. Nobody in CI gets `storage.buckets.update`, the permission that changes soft delete.

{% highlight text %}
project: acme-state
 |
 +-- KMS key ring "tfstate" (us-central1)
 |     +-- key "tfstate"   <- GCS service agent: cryptoKeyEncrypterDecrypter
 |
 +-- bucket "acme-state-tfstate" (US-CENTRAL1, UBLA, PAP enforced,
 |     |                         versioning, soft delete 30d, CMEK default)
 |     +-- bootstrap/   <- bootstrap admin only
 |     +-- envs/dev/    <- tf-dev SA   (get/create/delete, conditional)
 |     +-- envs/prod/   <- tf-prod SA  (get/create/delete, conditional)
 |         (every pipeline SA: objects.list on the bucket, unconditional)
 |
 +-- custom roles: tfStateObjectRW, tfStateList
 +-- audit config: storage.googleapis.com DATA_READ + DATA_WRITE

humans          --impersonate-->  tf-<env> SA
GitHub Actions  --WIF---------->  tf-<env> SA
{% endhighlight %}

## Prerequisites

- Terraform 1.11+ (write-only arguments need 1.11, ephemeral resources 1.10) and the `hashicorp/google` provider `~> 8.9`.
- `gcloud`, authenticated as a principal that can create buckets, KMS keys and custom roles and set project IAM policy. In a fresh state-only project, Owner during bootstrap is pragmatic. Drop it afterwards.
- Billing enabled. KMS keys aren't free.
- Comfort with service accounts and IAM bindings. My [GCP IAM fundamentals post]({% link _posts/2023/2023-06-12-gcp-iam-fundamentals-terraform.md %}) covers `_member` versus `_binding`.

{% highlight bash %}
terraform version          # expect v1.11 or later
gcloud auth list
gcloud config set project acme-state

gcloud services enable \
  storage.googleapis.com \
  cloudkms.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com
{% endhighlight %}

`iamcredentials.googleapis.com` is what service account impersonation runs on.

## Bootstrapping the GCS State Bucket with Terraform

The bucket has to exist before Terraform can keep state in it, so the bootstrap stack starts with local state and migrates itself in once the bucket and IAM exist.

### Provider, key ring and key

{% highlight hcl %}
terraform {
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
  }
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1" # Free Tier region; must match the key ring
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_storage_project_service_account" "gcs" {
  project = var.project_id
}

resource "google_kms_key_ring" "state" {
  name     = "tfstate"
  location = var.region
}

resource "google_kms_crypto_key" "state" {
  name            = "tfstate"
  key_ring        = google_kms_key_ring.state.id
  rotation_period = "7776000s" # 90 days; each rotation adds a billed key version

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "gcs_agent" {
  crypto_key_id = google_kms_crypto_key.state.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}
{% endhighlight %}

The key ring must be in the bucket's location. The Cloud Storage service agent uses the key, not your pipeline, so it gets `cryptoKeyEncrypterDecrypter`. Use the data source rather than interpolating the agent's email: per the provider docs, it also makes sure the agent exists, which in a new project it may not. `prevent_destroy` matters more on the key than on the bucket. A destroyed key leaves you able to list and delete objects but never read them again.

### The bucket

{% highlight hcl %}
resource "google_storage_bucket" "state" {
  name                        = "${var.project_id}-tfstate"
  location                    = upper(var.region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 2592000 # 30 days
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.state.id

    google_managed_encryption_enforcement_config {
      restriction_mode = "FullyRestricted"
    }
    customer_supplied_encryption_enforcement_config {
      restriction_mode = "FullyRestricted"
    }
  }

  # Keep at most 20 old versions of each object...
  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
      send_age_if_zero   = false
    }
    action {
      type = "Delete"
    }
  }

  # ...and none older than 30 days after being superseded.
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
      send_age_if_zero           = false
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_kms_crypto_key_iam_member.gcs_agent]
}
{% endhighlight %}

**`uniform_bucket_level_access`** defaults to `false` in the provider. Bucket-level IAM Conditions require it. Organizations created on or after 3 May 2024 enforce it by org policy, but be explicit.

**`public_access_prevention`** defaults to `"inherited"`, which only enforces if an org policy does, and PAP is **not** in the secure-by-default set. Cloud Audit Logs also don't record access to public objects, so a state file made public by accident can be read without a trace.

**`encryption`** puts the CMEK on both state and lock. The enforcement blocks (provider v7.26.0+) reject new objects using Google-managed or customer-supplied keys. They only affect new objects, and I couldn't find a docs page confirming GA status, so check it in your project. CMEK covers object data and checksums, not names or metadata, so workspace names stay readable. `depends_on` makes the service agent grant land first.

**Lifecycle rules** cap paid history. Put `send_age_if_zero = false` on every condition, or the provider sends `age = 0` alongside it. The provider docs also note that `0` for `num_newer_versions` or `days_since_noncurrent_time` is silently ignored; use the matching `send_*_if_zero` flag if you need a zero.

### Soft delete protects state from your own pipeline

If I had to keep only one setting on this bucket, it would be this one. Versioning protects you from mistakes. It doesn't protect you from someone holding the pipeline's identity, because `delete` reaches noncurrent generations. Soft-deleted objects can't be permanently deleted during the retention window. Lowering retention only applies to objects deleted afterwards, changing the policy needs `storage.buckets.update` (not in the custom role, not in Object Admin), and restoring needs `storage.objects.restore`, which the pipeline doesn't get either. The writer can delete everything it can reach and you still get it all back.

Retention runs from 7 to 90 days. The default is 7, `0` disables it, and omitting the block keeps whatever the server has. Soft-deleted bytes bill like live ones. Lifecycle deletions are soft deletes too, so here a superseded version can live 30 days as noncurrent plus 30 in soft delete. The org policy `storage.softDeletePolicySeconds` can constrain allowed values.

### Why not a retention policy or Bucket Lock

Under a retention policy, objects "cannot be deleted or replaced until they reach the age you define", and you get `403 retentionPolicyNotMet`. Without versioning, every state overwrite and `.tflock` delete fails. With versioning, the docs say a retained live version can still become noncurrent, so overwrites may succeed, but every lock and state generation is then kept for the full period with no cleanup. I wouldn't want to learn how that interacts with the backend in production. Bucket Lock (`is_locked = true`) makes it permanent.

`ip_filter` (provider v6.37.0+) can restrict the bucket to VPCs or CIDRs, but GitHub-hosted runners have no stable egress and the provider can't remove the block once added, only disable it. I left it out.

## Custom Roles and Prefix-Scoped IAM Conditions

One service account per environment, two bindings each: unconditional `list`, conditional everything else.

{% highlight hcl %}
locals {
  envs = toset(["dev", "prod"])
}

resource "google_project_iam_custom_role" "state_rw" {
  role_id     = "tfStateObjectRW"
  title       = "Terraform state object read/write"
  permissions = [
    "storage.objects.get",
    "storage.objects.create",
    "storage.objects.delete",
  ]
}

resource "google_project_iam_custom_role" "state_list" {
  role_id     = "tfStateList"
  title       = "Terraform state workspace listing"
  permissions = ["storage.objects.list"]
}

resource "google_service_account" "tf" {
  for_each     = local.envs
  account_id   = "tf-${each.key}"
  display_name = "Terraform ${each.key} pipeline"
}

# objects.list is evaluated against the bucket, so it can't be
# scoped by object name. It has to be unconditional.
resource "google_storage_bucket_iam_member" "list" {
  for_each = local.envs
  bucket   = google_storage_bucket.state.name
  role     = google_project_iam_custom_role.state_list.id
  member   = google_service_account.tf[each.key].member
}

resource "google_storage_bucket_iam_member" "rw" {
  for_each = local.envs
  bucket   = google_storage_bucket.state.name
  role     = google_project_iam_custom_role.state_rw.id
  member   = google_service_account.tf[each.key].member

  condition {
    title      = "tfstate-${each.key}-prefix"
    expression = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.state.name}/objects/envs/${each.key}/\")"
  }
}
{% endhighlight %}

The custom role's `id` is `projects/<project>/roles/<id>`, the format bucket IAM wants, and `.member` on the service account gives you the `serviceAccount:` string.

### The trailing slash in the condition

The `_` in `projects/_/buckets/` is literal; you can't put a project ID there. The trailing slash is the part people drop. Without it, `startsWith(".../objects/envs/prod")` also matches `envs/prod-legacy/` and `envs/production/`. The backend doesn't care about the slash. IAM does. The lock lives under the same prefix, so one condition covers both objects.

### Why list gets its own binding

From the GCS IAM docs: "you cannot use the `resource.name` condition attribute to restrict object listing access." List is checked against the bucket, so `list` inside the conditional binding never matches and init fails with `Failed to get existing workspaces`. Hence the separate unconditional role.

That leaves every pipeline able to enumerate the bucket: names, sizes, timestamps, MD5s, but not contents. Most teams can live with prod knowing `envs/dev/payments.tfstate` exists. If workspace names are sensitive, use separate buckets.

The provider handles the policy version 3 that conditions need. Bucket IAM changes are eventually consistent, and HashiCorp's docs warn about 403s for a few minutes after a change, so don't debug the role immediately after `apply`.

## Keyless Access with Impersonation and Workload Identity Federation

The backend picks credentials in this order: `access_token`, `credentials`, the `GOOGLE_BACKEND_CREDENTIALS` and `GOOGLE_CREDENTIALS` env vars, then Application Default Credentials. `impersonate_service_account` wraps whichever wins. None of this needs a key file, and orgs created since May 2024 block key creation by default anyway.

### Humans impersonate

{% highlight hcl %}
resource "google_service_account_iam_member" "alice_prod" {
  service_account_id = google_service_account.tf["prod"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:alice@example.com"
}
{% endhighlight %}

Grant Token Creator on the one service account. At project level it lets the person impersonate every service account there, the bootstrap one included.

{% highlight bash %}
gcloud auth application-default login

# Backend-only override; the provider keeps its own credentials
export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="tf-prod@acme-state.iam.gserviceaccount.com"
terraform init
{% endhighlight %}

Because the variable only affects the backend, the state identity and the deploying identity can differ, which is usually what you want. The impersonated token the backend mints carries only the `devstorage.read_write` scope, so it can't call any non-Storage API even if it leaks.

### CI uses Workload Identity Federation

I covered the pool, provider and attribute conditions in [Workload Identity Federation for GitHub Actions]({% link _posts/2025/2025-04-14-gcp-workload-identity-federation-github-actions.md %}). For the backend, the relevant bit is that `google-github-actions/auth` writes an `external_account` credential file and sets `GOOGLE_APPLICATION_CREDENTIALS`, which the backend reads through ADC:

{% highlight yaml %}
permissions:
  contents: read
  id-token: write

steps:
  - uses: actions/checkout@v4

  - uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github/providers/github-oidc
      service_account: tf-prod@acme-state.iam.gserviceaccount.com

  - run: terraform init -input=false
  - run: terraform plan -input=false -lock-timeout=5m
{% endhighlight %}

## Migrating Local State into the Terraform GCS Backend

Give the bootstrap stack a prefix no pipeline condition covers:

{% highlight hcl %}
terraform {
  backend "gcs" {
    bucket = "acme-state-tfstate"
    prefix = "bootstrap"
    # No kms_encryption_key: the bucket default CMEK covers state and .tflock
  }
}
{% endhighlight %}

{% highlight bash %}
terraform init -migrate-state
# Answer "yes" to copy the existing state

gcloud storage ls gs://acme-state-tfstate/bootstrap/
# gs://acme-state-tfstate/bootstrap/default.tfstate

terraform plan    # should report no changes

rm terraform.tfstate terraform.tfstate.backup
{% endhighlight %}

The `rm` matters. That local file is plaintext JSON of everything the bootstrap created.

Workload stacks use `prefix = "envs/prod"` and so on. I keep `impersonate_service_account` out of the committed block and set it via the env var, since CI and humans authenticate differently. HashiCorp warns that values from `-backend-config` or the block itself land in `.terraform/` and in plan files. Fine for a bucket name. For a CSEK, use `GOOGLE_ENCRYPTION_KEY`.

## Logging Terraform State Reads with Data Access Audit Logs

{% highlight hcl %}
resource "google_project_iam_audit_config" "storage" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
{% endhighlight %}

This resource is authoritative for its service and conflicts with `google_project_iam_policy`, so don't mix them. Each `audit_log_config` takes `exempted_members`, and anyone with `resourcemanager.projects.setIamPolicy` can add one and silence logging for a principal. That change does appear in Admin Activity as a `SetIamPolicy`, so alert on it.

Run `terraform state pull`, wait a few minutes, then:

{% highlight bash %}
gcloud logging read '
  log_id("cloudaudit.googleapis.com/data_access")
  AND resource.type="gcs_bucket"
  AND resource.labels.bucket_name="acme-state-tfstate"
  AND protoPayload.methodName="storage.objects.get"
  AND protoPayload.resourceName:".tfstate"' \
  --project=acme-state --freshness=7d \
  --format='table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.resourceName)'
{% endhighlight %}

Expect two entries per read. With impersonation, `principalEmail` is the service account and the human should appear under `authenticationInfo.serviceAccountDelegationInfo`, which is how you tell Alice from the pipeline. Confirm the method names and that delegation path against a real entry before building alerts; they're standard fields, but I haven't checked them live for this post. The obvious first alert: any `storage.objects.get` on `envs/prod/` by a principal other than `tf-prod`.

## Keeping Secrets Out of GCS State with Write-Only Arguments

Everything so far controls who reads the state object, not what's in it. Anyone with `get` on `envs/prod/default.tfstate` receives decrypted JSON; CMEK doesn't change that.

The google provider is in good shape here, and it builds on the Secret Manager setup from my [Secret Manager with Terraform post]({% link _posts/2023/2023-11-13-gcp-secret-manager-terraform.md %}). `google_secret_manager_secret_version` has had a write-only `secret_data_wo` since v6.23.0 (Terraform 1.11+), sent at apply time and never stored in plan or state. In v8.0.0, `secret_data_wo_version` became a **string** and is required alongside `secret_data_wo`, which is the line to fix when upgrading v7 code:

{% highlight hcl %}
variable "db_password" {
  type      = string
  ephemeral = true # Terraform 1.10+: never persisted
}

resource "google_secret_manager_secret" "db" {
  secret_id = "app-db-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db" {
  secret                 = google_secret_manager_secret.db.id
  secret_data_wo         = var.db_password
  secret_data_wo_version = "1" # string in v8; change it to push a new value
}
{% endhighlight %}

Ephemeral resources handle the consuming side. The provider has had ephemeral `google_service_account_access_token`, `_id_token`, `_jwt` and `_key` since v6.13.0, and ephemeral `google_secret_manager_secret_version` since v7.6.0. Feed it into a write-only argument like `google_sql_user.password_wo` and the password goes from Secret Manager to Cloud SQL without touching state:

{% highlight hcl %}
# Database stack: read a secret another stack created
ephemeral "google_secret_manager_secret_version" "db" {
  secret = "projects/acme-app-prod/secrets/app-db-password"
}

resource "google_sql_user" "app" {
  name                = "app"
  instance            = google_sql_database_instance.main.name
  password_wo         = ephemeral.google_secret_manager_secret_version.db.secret_data
  password_wo_version = "1"
}
{% endhighlight %}

Check the current docs for `password_wo_version` and the ephemeral resource's `secret_data` attribute before copying; I'm surer of `secret_data_wo` than of those two names.

This only works when a provider has both halves. An ephemeral value can go into a write-only argument, a provider block or another ephemeral context, nowhere else. A provider with ephemeral resources but no write-only arguments leaves the value stranded, and you're back to resources that persist it. AWS has the same pair with `secret_string_wo`, covered in my [Secrets Manager least-privilege post]({% link _posts/2026/2026-07-20-aws-secrets-manager-terraform-least-privilege.md %}).

Plenty still lands in state: the non-ephemeral `google_service_account_key.private_key`, `random_password.result`, connection strings, emails. `sensitive = true` only hides output. Write-only arguments reduce what a leak exposes, and the IAM, CMEK and logging above stay necessary.

## What a Hardened GCS State Bucket Costs

| Item | Free allowance | Beyond it | Notes |
|---|---|---|---|
| Storage | 5 GB-months regional, `us-east1`/`us-west1`/`us-central1` combined | Standard regional rate | Dual- and multi-region aren't free. Noncurrent and soft-deleted bytes count. |
| Class A ops (`insert`, `list`) | 5,000/month | $0.005 per 1,000 | Init lists; locks and writes insert |
| Class B ops (`get`) | 50,000/month | Class B rate | Two per state read |
| Deletes | Free | Free | Unlocks cost nothing |
| Cloud KMS software key | None | ~$0.06 per key version/month, $0.03 per 10,000 ops | Disabled and pending-destruction versions still bill |
| Cloud KMS Autokey | 100 active versions, 10,000 ops/month | Standard rates | Autokey-created keys only (HSM, yearly rotation) |
| Cloud Logging | 50 GiB/project/month | $0.50/GiB | Data Access logs go to `_Default` (30 days included) |

With `US-CENTRAL1` and `STANDARD`, the bucket stays free. An `apply` costs a handful of Class A ops (a list, a lock insert, one or more state writes, since long applies persist mid-run), which works out to several hundred to roughly 1,500 runs a month before operations cost anything. The exact count per run depends on your apply, so treat that range as approximate.

History is what can grow. A 5 MB state applied 50 times a day with no lifecycle cap and 90-day soft delete reaches about 22 GB; that's what the two lifecycle rules prevent.

KMS is never zero with a normal key: every rotation adds a billed version, and old versions stay as long as any state uses them. Autokey's free tier gets around that, but its keys are HSM, one per bucket, and dedicated-key-project mode needs an org with folders. I haven't confirmed Terraform support for project-level Autokey (the provider example uses a folder), so verify before planning around it.

## Testing the GCS Backend Lock, IAM Conditions and Soft Delete

The `gcloud storage` flags and format keys below come from the docs, not from a run for this post. Check `--help` and adjust if a field comes back empty.

### Bucket posture

{% highlight bash %}
gcloud storage buckets describe gs://acme-state-tfstate \
  --format='yaml(uniform_bucket_level_access,public_access_prevention,versioning_enabled,soft_delete_policy,default_kms_key)'
{% endhighlight %}

### The Creator + Viewer negative test

Reproduce the opening error on purpose so it's in your runbook before anyone hits it:

{% highlight bash %}
gcloud iam service-accounts create tf-negative --project=acme-state

for ROLE in roles/storage.objectCreator roles/storage.objectViewer; do
  gcloud storage buckets add-iam-policy-binding gs://acme-state-tfstate \
    --member="serviceAccount:tf-negative@acme-state.iam.gserviceaccount.com" \
    --role="$ROLE"
done

export GOOGLE_BACKEND_IMPERSONATE_SERVICE_ACCOUNT="tf-negative@acme-state.iam.gserviceaccount.com"
terraform init -reconfigure -backend-config="prefix=test/negative"
{% endhighlight %}

Expect the "unlocking the state file ... failed ... force-unlock" error, a 403 on the delete, and a leftover `test/negative/default.tflock`. Capture the exact text, then clean up as an admin.

### Prefix isolation and the list gap

{% highlight bash %}
gcloud storage cat gs://acme-state-tfstate/envs/dev/default.tfstate \
  --impersonate-service-account=tf-prod@acme-state.iam.gserviceaccount.com
# expect 403

gcloud storage ls gs://acme-state-tfstate/envs/ \
  --impersonate-service-account=tf-prod@acme-state.iam.gserviceaccount.com
# expect success: the enumeration gap
{% endhighlight %}

For the list trap, temporarily move `storage.objects.list` into `tfStateObjectRW` and remove the unconditional binding. `terraform init` should fail with `Failed to get existing workspaces`.

### Lock contention and lock encryption

Run `terraform plan -lock-timeout=0s` in two terminals. The second reports `Error acquiring the state lock` with a numeric `ID` and a `Path` ending in `default.tflock`. While the first plan still holds the lock, compare that ID with the generation and check that both objects carry your key:

{% highlight bash %}
gcloud storage objects describe gs://acme-state-tfstate/envs/prod/default.tflock \
  --format='value(generation,kms_key)'

gcloud storage objects describe gs://acme-state-tfstate/envs/prod/default.tfstate \
  --format='value(kms_key)'
{% endhighlight %}

### Tamper and restore

Create a throwaway workspace (`terraform workspace new tamper`), then, as `tf-prod`:

{% highlight bash %}
gcloud storage rm --all-versions gs://acme-state-tfstate/envs/prod/tamper.tfstate \
  --impersonate-service-account=tf-prod@acme-state.iam.gserviceaccount.com

gcloud storage ls -a gs://acme-state-tfstate/envs/prod/              # gone
gcloud storage ls --soft-deleted gs://acme-state-tfstate/envs/prod/  # still there

# As an admin (tf-prod lacks storage.objects.restore):
gcloud storage restore gs://acme-state-tfstate/envs/prod/tamper.tfstate#<generation>
{% endhighlight %}

### The audit trail

Run `terraform state pull` before applying the audit config and again after. The first leaves nothing in Logging. The second shows two `storage.objects.get` entries.

## GCS Backend Gotchas

- **CSEK changes don't migrate.** Rewrite the object with `gcloud storage` first, then `terraform init -migrate-state`. CMEK changes are automatic, but objects re-encrypt only on their next write, so keep old key versions until every state has been written once.
- **A disabled key version blocks reads** until re-enabled. A destroyed one loses the data.
- **`encryption_key` and `kms_encryption_key` are mutually exclusive.**
- **`access_token` has an undocumented env var.** The docs table lists none, but the source reads `GOOGLE_OAUTH_ACCESS_TOKEN`, and it beats `credentials`. A stray export in a CI image wins.
- **`storage_custom_endpoint`** for Private Service Connect needs the full URL including `/storage/v1/b`.
- **No GCS-backend CVEs** turned up in my search, which I don't claim was exhaustive. Keep Terraform current; point releases pick up dependency fixes.

## Rules I'd Apply to Every Terraform State Bucket on GCP

**Four permissions, nothing broader.** Not Object Admin, not Object User, and never project Editor for a pipeline.

**Keep `storage.buckets.update` out of CI.** Soft delete only helps if the identity that deletes objects can't change the policy.

**One bucket per sensitivity level, one prefix per stack.** Conditions are enough between similar stacks. Very different ones get separate buckets, because of the list gap and because `terraform_remote_state` hands over the whole file.

**CMEK on the bucket, not the backend.** It covers the lock and keeps remote-state readers simple.

**Data Access logs from day one.** You can't find out later who read the state.

**Map it to your audit controls.** NIST 800-53: AC-6, SC-28, AU-2/AU-12, CP-9. The CIS GCP Foundations Benchmark covers audit logging, public buckets, UBLA and service account keys; check the current PDF for numbers.

## Where This Leaves You

You have a state project with one bucket: private by enforcement, versioned, encrypted with your key (locks included), with a soft delete window the pipeline can't shorten. Each environment's service account touches its own prefix through four permissions, people impersonate, CI federates, and every state read is logged with a name on it.

Run the Creator + Viewer test and the conditional-list test in a sandbox first. Those two failures are what push teams back to Object Admin, and having the errors in your runbook makes it easier to keep the custom role. Then add the alert on unexpected readers of `envs/prod/`, and start moving secrets to `_wo` arguments.

Happy scripting!
