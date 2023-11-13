---
title: 'GCP Secret Manager Terraform: secrets, IAM, and rotation'
author: Victor Silva
date: 2023-11-13T10:00:00+00:00
layout: post
permalink: /gcp-secret-manager-terraform/
excerpt: "Create and manage GCP Secret Manager secrets with Terraform: google_secret_manager_secret, secret-level IAM bindings, state file exposure fixes, and Pub/Sub rotation."
categories:
  - GCP
  - Security
tags:
  - GCP
  - Secret Manager
  - Terraform
  - Security
  - google_secret_manager_secret
  - Secret Manager IAM
  - GCP secrets pipeline
  - google_secret_manager_secret_version
  - Cloud Run secrets
  - GCP audit logging
---

Secrets management is one of those problems that developers solve quickly the first time and correctly the second time — after something goes wrong. The quick solution is environment variables, a `.env` file, a CI/CD variable stored in plaintext, or the most direct path of all: the credential in the source code. These approaches share a common trait: the secret lives somewhere it was never designed to live, alongside code, logs, or pipeline output that gets read by people who do not need access to production credentials.

The correct solution is a dedicated secrets manager. If you are working in GCP, that service is Secret Manager. If you are coming from Azure, think Azure Key Vault — similar purpose, similar IAM model, but with a few GCP-specific behaviors that will trip you up if you do not know them upfront. If you are coming from AWS, Secrets Manager is the closest analogue, though the pricing model and versioning semantics are different.

This post builds a complete Secret Manager setup with Terraform. It covers the mental model for secrets and versions, creates secrets and IAM bindings the right way, addresses the Terraform state file problem directly with three concrete solutions, sets up rotation notifications via Pub/Sub, shows how to consume secrets in applications, and enables audit logging so you know who is reading what.

## Secret Manager Mental Model

Before writing any Terraform, the versioning model is worth understanding precisely, because it affects how you reference secrets in code and how rotation works.

### Secrets and Versions

A **secret** is a metadata container. It holds configuration — the secret ID, labels, replication policy, rotation schedule — but it does not hold the actual credential value. Think of it as a named slot.

A **version** is the actual payload. It contains the credential value as a byte array (up to 64 KiB), and it is immutable once created. Versions are numbered sequentially — 1, 2, 3 — and the alias `latest` always resolves to the highest-numbered enabled version. When you rotate a credential, you add a new version; the old versions remain available until you explicitly disable or destroy them.

This split is deliberate. It means you can update the value of a secret without changing the secret's name or IAM bindings. Your application code references `my-db-password:latest` and gets the current value without knowing anything about rotation history. Your rotation pipeline adds a new version; everything downstream updates automatically.

```
my-db-password (secret metadata, IAM bindings, replication config)
  ├── version/1  [DISABLED]   — original password, rotated out
  ├── version/2  [ENABLED]    — current password
  └── version/3  [ENABLED]    — latest (alias points here after rotation)
```

### Replication Policy

The replication policy controls where your secret versions are physically stored. It is set once at secret creation time and **cannot be changed afterwards**. This is the most operationally significant constraint in Secret Manager, and it is worth emphasizing because there is no Terraform `lifecycle` trick or import path that lets you modify it — you would have to delete the secret and recreate it, which means rebuilding all the version history and updating every reference to it.

Two options exist:

- **`auto {}`** — Google selects the storage regions automatically. This is the right default for most workloads. Secret versions may be stored in any global region, and Google handles redundancy. Use this unless you have a specific data residency requirement.
- **`user_managed { replicas { location } }`** — you specify the exact regions. Required if you need CMEK (customer-managed encryption keys), because each replica's key must be in the same region as the replica itself. Required for strict data residency compliance.

The practical recommendation: use `auto {}` unless you have a compliance requirement that mandates specific regions. The operational overhead of managing regional replicas is real, and CMEK for Secret Manager is only necessary if your threat model includes GCP infrastructure access by Google employees.

## Prerequisites

To follow along you will need:

- Terraform 1.3 or later
- The `google` provider version 4.x or later (examples in this post also call out `secret_data_wo` which requires 6.x)
- A GCP project with the Secret Manager API enabled
- `gcloud` CLI authenticated with a principal that has `roles/secretmanager.admin` on your target project

Verify your setup:

{% highlight bash %}
terraform version
gcloud auth list
gcloud config get-value project
gcloud services list --filter="NAME:secretmanager.googleapis.com"
{% endhighlight %}

If the Secret Manager API is not enabled, enable it:

{% highlight bash %}
gcloud services enable secretmanager.googleapis.com
{% endhighlight %}

## Creating Secrets and IAM with Terraform

### The Secret Container

The first resource to create is `google_secret_manager_secret`. This is just the container — no credential value yet.

{% highlight hcl %}
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

resource "google_secret_manager_secret" "app_db_password" {
  project   = var.project_id
  secret_id = "app-db-password"

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  replication {
    auto {}
  }
}
{% endhighlight %}

The `secret_id` is what you reference in application code and `gcloud` commands. Make it descriptive and consistent — something like `{service}-{credential-type}` works well at scale: `payments-db-password`, `payments-stripe-api-key`, `payments-jwt-signing-key`.

The `labels` block is worth populating even if it feels like overhead. Labels are the primary way to query secrets across a project (`gcloud secrets list --filter="labels.environment=production"`), and they are the only metadata field you can change after creation without recreating the secret.

### The Secret Version

The version holds the actual credential value. This is where the most important caveat in the entire post applies.

{% highlight hcl %}
variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database password — passed via TF_VAR_db_password or pipeline secret"
}

resource "google_secret_manager_secret_version" "v1" {
  secret      = google_secret_manager_secret.app_db_password.id
  secret_data = var.db_password

  deletion_policy = "DISABLE"

  lifecycle {
    create_before_destroy = true
  }
}
{% endhighlight %}

> **State file warning**: `secret_data` is stored as plaintext in your Terraform state file. Marking the variable `sensitive = true` hides the value from `terraform plan` and `terraform apply` output, but it does not affect what gets written to state. If your state backend is a GCS bucket without encryption or proper access controls, the credential is effectively exposed to anyone who can read state. The next section covers this problem in detail and gives you three ways to handle it.

The `deletion_policy = "DISABLE"` setting means Terraform will disable the version rather than destroy it when you remove the resource from your configuration. This is a safer default than the implicit destruction behavior — it gives you a recovery window. The `create_before_destroy` lifecycle rule ensures that when you rotate the credential by changing `var.db_password` and re-applying, the new version is created before the old one is disabled, avoiding any window where no enabled version exists.

### IAM at the Secret Level

This is where a common mistake happens. The `roles/secretmanager.secretAccessor` role can be granted at the project level or at the secret level. Project-level grants give the principal access to every secret in the project — past, present, and future. Secret-level grants give access to exactly one secret.

**Always bind at the secret level.** A service account that needs the database password should not be able to read the Stripe API key, the JWT signing key, or any other secret in the project. The project-level grant is convenient but creates the exact blast radius you are trying to prevent with a secrets manager in the first place.

{% highlight hcl %}
resource "google_service_account" "app_sa" {
  project      = var.project_id
  account_id   = "my-application-sa"
  display_name = "My Application Service Account"
}

resource "google_secret_manager_secret_iam_member" "app_reads_db" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.app_db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}
{% endhighlight %}

The resource to reach for is `google_secret_manager_secret_iam_member` — note `secret_iam_member`, not `project_iam_member`. If you find yourself writing `google_project_iam_member` with `roles/secretmanager.secretAccessor`, stop and reconsider whether the principal genuinely needs access to every secret in the project. It almost certainly does not.

The IAM roles reference for Secret Manager:

| Role | What it grants |
|---|---|
| `roles/secretmanager.secretAccessor` | Read the secret payload — what applications need |
| `roles/secretmanager.secretVersionAdder` | Create new versions — what CI pipelines need |
| `roles/secretmanager.secretVersionManager` | Add, disable, and destroy versions — what rotation handlers need |
| `roles/secretmanager.viewer` | Read metadata only, no payload — what auditors need |

Grant each service account the minimum role for what it actually does. A rotation Cloud Function needs `secretVersionManager`. A CI pipeline that writes new versions needs `secretVersionAdder`. An application that reads credentials needs `secretAccessor`. These are distinct roles for a reason.

## The Terraform State Problem

The state file problem is real and worth treating seriously. When `secret_data` contains a credential and you use a remote state backend, that credential is accessible to anyone with read access to the state. With GCS as the backend, that means anyone with `storage.objects.get` on the state bucket — which in many setups includes all developers who can run Terraform.

Three approaches exist, and they represent different tradeoffs between convenience and security posture.

### Approach 1: Separate the Lifecycle (Recommended)

The cleanest solution is to not put the secret value in Terraform at all. Use Terraform to create the secret container and IAM bindings, and write the actual credential value in a separate CI step that runs after `terraform apply`.

{% highlight hcl %}
# secrets.tf — Terraform manages the container and IAM only
resource "google_secret_manager_secret" "app_db_password" {
  project   = var.project_id
  secret_id = "app-db-password"
  replication { auto {} }
}

resource "google_secret_manager_secret_iam_member" "app_reads_db" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.app_db_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_sa.email}"
}

# No google_secret_manager_secret_version here
{% endhighlight %}

Then, in your CI pipeline, after the Terraform step completes, write the credential value directly via `gcloud`:

{% highlight bash %}
# The secret value comes from a CI/CD-native secret store (GitHub Actions secret, GitLab CI variable, etc.)
echo -n "$DB_PASSWORD" | gcloud secrets versions add app-db-password --data-file=-
{% endhighlight %}

The `-n` flag on `echo` is important — it suppresses the trailing newline. Many credential consumers are sensitive to trailing whitespace; a password ending in `\n` will fail authentication against most databases and APIs.

This approach means the credential never touches Terraform state. The CI pipeline secret store holds the value temporarily for the pipeline run; Secret Manager holds it durably. The secret container and IAM bindings are IaC-managed and version-controlled; the secret value has a separate, auditable write path.

### Approach 2: `sensitive = true` (Partial Mitigation)

Marking the variable `sensitive = true` prevents the value from appearing in `terraform plan` and `terraform apply` output, which reduces the risk of credentials being exposed in CI logs. The value is still written to state in plaintext.

{% highlight hcl %}
variable "db_password" {
  type      = string
  sensitive = true
}
{% endhighlight %}

This is a meaningful improvement over an unsensitized variable, but it is not a solution to the state exposure problem. Use it as a complement to a well-secured state backend (GCS bucket with CMEK and tight IAM), not as a substitute for one.

### Approach 3: `secret_data_wo` (Provider 6.x and Later)

The `google` provider version 6.x introduced a write-only attribute `secret_data_wo` as a replacement for `secret_data`. Write-only attributes do not persist to state — the value is sent to the API at creation time and never stored in the state file.

{% highlight hcl %}
resource "google_secret_manager_secret_version" "v1" {
  secret         = google_secret_manager_secret.app_db_password.id
  secret_data_wo = var.db_password  # does not persist to Terraform state
  deletion_policy = "DISABLE"
}
{% endhighlight %}

This is the cleanest Terraform-native solution, but it requires provider 6.x. If your project is still on provider 4.x or 5.x — which is common given the breaking changes in the 5.x and 6.x releases — you cannot use it today. Check your provider constraint before adopting this approach.

For most teams right now, Approach 1 (separate lifecycle) is the most practical and the most secure. It also has the benefit of making the credential write path explicit and auditable independent of Terraform runs.

## Rotation with Pub/Sub

Secret Manager does not rotate secrets for you. What it does is send a notification when a rotation is due, and you implement the rotation logic in a subscriber — typically a Cloud Function or Cloud Run job. The notification model is important to understand: if you configure rotation but do not wire up a subscriber, your secrets will age past their rotation schedule silently.

### Wiring Up the Notification

{% highlight hcl %}
data "google_project" "current" {
  project_id = var.project_id
}

resource "google_pubsub_topic" "rotation_topic" {
  project = var.project_id
  name    = "secret-rotation-notifications"
}

# Secret Manager's service agent needs publish rights on the topic
resource "google_pubsub_topic_iam_member" "sm_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.rotation_topic.id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
}

resource "google_secret_manager_secret" "rotating_api_key" {
  project   = var.project_id
  secret_id = "third-party-api-key"

  replication { auto {} }

  topics {
    name = google_pubsub_topic.rotation_topic.id
  }

  rotation {
    next_rotation_time = "2024-02-01T00:00:00Z"
    rotation_period    = "2592000s"  # 30 days
  }
}
{% endhighlight %}

The `service-PROJECT_NUMBER@gcp-sa-secretmanager.iam.gserviceaccount.com` service agent is the identity Secret Manager uses to publish rotation notifications. Without the `roles/pubsub.publisher` binding on the topic, Secret Manager cannot send notifications and the rotation schedule is effectively dead. This is a common configuration mistake — the secret looks correctly configured, but nothing actually happens at rotation time because the publish call fails silently.

When `next_rotation_time` arrives, Secret Manager publishes a message to the topic with metadata about the secret that needs rotation. Your subscriber reads that message and performs the actual rotation: generating a new credential, writing it to Secret Manager as a new version, and disabling the old version. Secret Manager has no knowledge of what the credential is used for, how to generate a replacement, or where to update it. That logic is entirely yours to implement.

After implementing rotation in a subscriber, update `next_rotation_time` in Terraform to the next expected rotation. Alternatively, your subscriber can update `next_rotation_time` programmatically via the API — but that creates a dependency between your rotation code and Terraform-managed state that can cause plan drift.

## Consuming Secrets in Applications

### With gcloud

For scripts, debugging, and ad-hoc operations, `gcloud` gives you direct access:

{% highlight bash %}
# Access the latest enabled version
gcloud secrets versions access latest --secret=app-db-password

# Access a specific version by number (prefer this in production scripts)
gcloud secrets versions access 2 --secret=app-db-password

# List all versions and their states
gcloud secrets versions list app-db-password
{% endhighlight %}

In production scripts, pinning to a specific version number instead of `latest` is safer. If a rotation adds a new version before your script runs and the new credential has not yet propagated to the database, `latest` gives you a credential that will fail authentication. Pinning gives you predictability during the propagation window — just make sure you have a process to update the pin after a successful rotation.

### With the Python SDK

For applications that fetch secrets at startup or on demand:

{% highlight python %}
from google.cloud import secretmanager


def get_secret(project_id: str, secret_id: str, version: str = "latest") -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version}"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")


# Usage
db_password = get_secret("my-project-id", "app-db-password")
{% endhighlight %}

The application's service account needs `roles/secretmanager.secretAccessor` on the specific secret — the IAM binding you created in the previous section. If the application runs on a GCP resource (GCE, GKE, Cloud Run), it uses the attached service account automatically via the metadata server. No key files involved.

One practical note: fetch the secret once at startup and cache it in memory rather than calling Secret Manager on every request. Secret Manager has per-project API quota limits, and fetching credentials on the hot path adds latency and risks hitting those limits under load.

### Cloud Run Native Secret References (Preferred)

For Cloud Run, there is a better approach than fetching secrets in application code: mount the secret directly as an environment variable or a volume at deploy time. This is the preferred approach because the application does not need the Secret Manager SDK at all — it just reads an environment variable or a file.

{% highlight bash %}
gcloud run deploy my-app \
  --image=gcr.io/my-project/my-app:latest \
  --set-secrets="DB_PASSWORD=app-db-password:latest" \
  --region=us-central1
{% endhighlight %}

The `--set-secrets` flag injects the secret value as an environment variable at container startup. Cloud Run resolves `app-db-password:latest` to the current version's value, so your application code reads `os.environ["DB_PASSWORD"]` — no SDK, no API calls, no quota consumption during normal operation.

With Terraform, you set this via the `env` block on your Cloud Run service:

{% highlight hcl %}
resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = "my-app"
  location = "us-central1"

  template {
    service_account = google_service_account.app_sa.email

    containers {
      image = "gcr.io/${var.project_id}/my-app:latest"

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_db_password.secret_id
            version = "latest"
          }
        }
      }
    }
  }
}
{% endhighlight %}

The Cloud Run service agent (`service-PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com`) needs `roles/secretmanager.secretAccessor` on the secret to resolve the reference at deploy time. If the service account attached to the Cloud Run service is your application SA, that SA also needs accessor rights. Both are needed: one for the deployment system to resolve the secret, one for the runtime container to read it if your application also accesses secrets programmatically.

## Audit Logging

Admin Activity logs in Secret Manager are always on — they capture create, update, and delete operations on secrets and IAM policies without any configuration needed. What you have to opt into explicitly are Data Access logs, which capture `AccessSecretVersion` calls. These are the logs that tell you who read a credential, and when. Without them, you have no visibility into secret consumption.

### Enabling Data Access Logs

Data Access logs for Secret Manager are disabled by default because they can be high-volume. Enable them via the project's IAM audit configuration. The simplest path is through the console (IAM & Admin > Audit Logs > Secret Manager API > Data Read), but you can also manage this in Terraform via `google_project_iam_audit_config`:

{% highlight hcl %}
resource "google_project_iam_audit_config" "secret_manager_data_access" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }
}
{% endhighlight %}

With this in place, every `AccessSecretVersion` call generates a log entry in Cloud Logging under the `cloudaudit.googleapis.com/data_access` log.

### Querying the Audit Trail

Once Data Access logs are enabled, you can query who accessed which secret and when:

{% highlight bash %}
gcloud logging read \
  'protoPayload.serviceName="secretmanager.googleapis.com" AND protoPayload.methodName="google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion"' \
  --limit=10 \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.resourceName)"
{% endhighlight %}

This gives you a table of timestamps, the principal that made the access call (email of the service account or user), and the full resource name of the version that was accessed. The resource name includes the project, secret ID, and version number — enough to correlate a specific access event with a specific credential version.

To narrow to a specific secret:

{% highlight bash %}
gcloud logging read \
  'protoPayload.serviceName="secretmanager.googleapis.com"
   AND protoPayload.methodName="google.cloud.secretmanager.v1.SecretManagerService.AccessSecretVersion"
   AND protoPayload.resourceName=~"secrets/app-db-password"' \
  --limit=50 \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail)"
{% endhighlight %}

To detect unexpected access — for example, a principal you did not expect reading a secret — set up a Cloud Logging log-based alert. Create a metric that counts `AccessSecretVersion` calls filtered to a specific secret and a specific principal, and alert when the count exceeds a threshold that does not match your expected access pattern. This is the most practical form of runtime secrets monitoring available without a dedicated CSPM tool.

## Best Practices

**Decide on replication policy before you create the secret.** Since it cannot be changed post-creation, get it right the first time. For most workloads, `auto {}` is correct. If you have data residency requirements, document them before provisioning any secrets and use `user_managed` replication with explicit regions. Changing this later means a destroy-and-recreate cycle that disrupts every consumer of the secret.

**Separate the Terraform lifecycle for secret values.** Even if you are on provider 6.x and can use `secret_data_wo`, consider whether writing credentials in Terraform is the right operational model for your team. The separate-lifecycle approach (Terraform manages containers and IAM, CI writes values) has the significant advantage of making the credential write path visible and auditable independently of infrastructure changes.

**Never grant project-level `secretAccessor`.** If you find a `google_project_iam_member` in your Terraform with `roles/secretmanager.secretAccessor`, treat it as a finding. Every service account should only be able to read the specific secrets it actually needs. Secret-level IAM bindings are the only way to enforce this.

**Pin version numbers in production consumers.** Using `latest` is convenient during development, but it means a rotation that writes a new version triggers an immediate credential switch for every consumer that reads on the next request. In production, pin to a specific version number and update the pin in a controlled rollout after verifying the new credential works.

**Enable Data Access audit logs before your first production deployment.** Enabling them retroactively means you have a gap in your audit trail that you cannot fill. The logs are cheap to store relative to what they give you — a complete record of every credential read in your project.

**Test your rotation subscriber before relying on it.** Rotation notifications from Pub/Sub are not automatically retried if your subscriber fails. If your Cloud Function throws on the first invocation, the rotation notification is consumed and not replayed unless you configure a dead-letter topic. Test the full rotation path — Pub/Sub message receipt, new credential generation, version write, old version disable — in a non-production environment before enabling rotation on production secrets.

**Use `deletion_policy = "DISABLE"` on secret versions.** Destroying a secret version is irreversible. Setting `DISABLE` in Terraform means that removing the version resource from your configuration disables the version rather than destroying it. You have a recovery window if something goes wrong during rotation. Only destroy versions after you have confirmed the replacement credential is working.

## Conclusion

Secret Manager gives you a solid foundation for credential management in GCP. The mental model — secret container plus immutable versions — is simple, and the IAM integration is clean once you understand that secret-level bindings are the right default. The Terraform resources map directly onto the API surface with one important caveat: the state file exposure problem for `secret_data` is real and needs an explicit decision from your team, not a default acceptance.

The patterns covered here — separate lifecycle for credential values, secret-level IAM, rotation notifications via Pub/Sub, Cloud Run native secret injection, and Data Access audit logging — give you a complete setup that you can apply consistently across all the secrets in your project. Start with `auto {}` replication, use `google_secret_manager_secret_iam_member` instead of project-level bindings, and enable audit logging from day one.

From here, look at how [GCP IAM roles and service accounts managed with Terraform](/gcp-iam-fundamentals-terraform/) interacts with the service account grants in this post — the `iam_member` vs `iam_binding` semantics apply equally to secret-level IAM. If you want to enforce that secret-level IAM bindings are always used (never project-level), that is a good candidate for a [Checkov custom policy for Terraform resources](/checkov-custom-policies-azure-terraform/). To surface misconfigured secrets and overly permissive IAM as operational findings, see [automating GCP Security Command Center findings with Cloud Functions](/gcp-security-command-center-cloud-functions/). For broader network-layer controls on the same GCP project, [GCP Cloud Armor WAF policies with Terraform](/gcp-cloud-armor-waf-terraform/) completes the picture.

Happy scripting!
