---
title: 'GCP IAM Terraform: roles, service accounts, and WIF'
author: Victor Silva
date: 2023-06-12T22:14:25+00:00
layout: post
permalink: /gcp-iam-fundamentals-terraform/
excerpt: "IAM misconfiguration is the top GCP breach vector. Learn the IAM model, iam_member vs iam_binding semantics, and Workload Identity Federation with Terraform."
categories:
  - GCP
tags:
  - gcp
  - terraform
  - iam
  - service-accounts
  - workload-identity-federation
  - google-project-iam-member
  - google-project-iam-binding
  - gcp-least-privilege
  - gcp-security
  - iac-security
---

If you have spent time in Azure, GCP IAM will feel both familiar and subtly different in ways that matter. Azure RBAC and GCP IAM share the same core philosophy — principals, roles, and scopes — but GCP's resource hierarchy introduces inheritance behavior that creates real risk if you do not understand it upfront. More importantly, the Terraform resources for GCP IAM come in three distinct flavors with very different semantics, and picking the wrong one can either lock you out of your project or leave your policy in a permanently drifting state.

IAM misconfiguration consistently ranks as the top initial access vector in GCP security incidents. The patterns are almost always the same: a service account with primitive Owner or Editor, the default Compute Engine service account left with its default Editor binding, or a long-lived SA key that was committed to a repository and never rotated. None of these require sophisticated attacks — they are configuration problems that get introduced during initial setup and accumulate over time.

This post covers the GCP IAM model from first principles, walks through service account management pitfalls, implements everything with Terraform using the correct resource types, introduces Workload Identity Federation as the right replacement for SA keys in CI/CD, and shows how to verify the result with `gcloud`.

## The GCP IAM Model

Before writing any Terraform, it is worth building a solid mental model of how GCP IAM is structured. If you are coming from Azure, the parallels are close enough to be useful but the differences are close enough to cause confusion.

### Principals

GCP IAM recognizes four principal types, and every binding in a policy attaches a role to one of them:

- `user:` — a Google account (e.g. `user:alice@example.com`)
- `serviceAccount:` — a service account (e.g. `serviceAccount:my-sa@project-id.iam.gserviceaccount.com`)
- `group:` — a Google Group (e.g. `group:platform-team@example.com`)
- `domain:` — all users in a Google Workspace domain (e.g. `domain:example.com`)

The `group:` principal is the one you should be reaching for most often in practice. Binding a role to a group rather than individual user accounts means your IAM policy stays stable as team membership changes — you manage group membership in your identity provider, not in your GCP IAM policy.

### Roles

GCP roles are containers for permissions. Permissions themselves follow a consistent format: `service.resource.verb` — for example, `storage.objects.get`, `pubsub.topics.publish`, `iam.serviceAccounts.actAs`. You cannot grant individual permissions directly; they are always bundled into roles.

There are three categories of roles, and the distinctions matter operationally:

**Primitive roles** (also called basic roles) — `roles/owner`, `roles/editor`, `roles/viewer`. These predate GCP's granular IAM system and span every GCP service in the project. `roles/editor` includes write access to almost everything. `roles/owner` adds IAM management on top of that. You should never assign these roles to service accounts in production, and you should almost never assign them to users outside of break-glass scenarios. The problem is not just that they are broad — it is that they are so broad that it is impossible to reason about what a principal with `roles/editor` can and cannot do. Use predefined roles instead.

**Predefined roles** — granular, service-specific roles maintained by Google. These are what you should use for everything. Examples: `roles/pubsub.publisher`, `roles/bigquery.dataViewer`, `roles/container.developer`. The [GCP IAM roles reference](https://cloud.google.com/iam/docs/understanding-roles) documents every predefined role and the permissions it contains. If you are moving from Azure, think of these as the equivalent of Azure's built-in roles like `Storage Blob Data Reader` — specific enough that you can grant them without worrying about unexpected lateral access.

**Custom roles** — roles you define yourself, composed of individual permissions you specify. Custom roles are appropriate when no predefined role gives you exactly the right set — typically when you need a role that spans fewer permissions than the closest predefined option. They come with operational overhead: you have to maintain them as GCP adds new API permissions to services, and you need to track which projects or organizations they are defined at.

### Resource Hierarchy and Policy Inheritance

This is where GCP diverges meaningfully from Azure's subscription/resource group model. GCP has a four-level hierarchy:

```
Organization
  └── Folders (optional, can be nested)
        └── Projects
              └── Resources (buckets, VMs, topics, etc.)
```

IAM policies can be set at any level of this hierarchy. The key behavior: **IAM is additive and inherited downward**. A binding set at the organization level applies to every folder, project, and resource beneath it. A binding set at the folder level applies to all projects and resources within that folder. You cannot override an inherited binding at a lower level — if a principal has `roles/editor` at the organization level, setting a more restrictive policy at the project level does not remove that access.

This inheritance model has a direct security implication. A primitive role granted at organization level is catastrophically broad. Even if your project-level policies are clean, a single misconfigured organization-level binding can give a principal access to everything. Always check what is bound at the organization and folder levels before concluding that a project's policy is the complete picture.

GCP does have a Deny Policies construct (separate from allow policies and relatively newer) that can explicitly block permissions at lower levels of the hierarchy, but that is an advanced pattern and not covered in this post. For most teams, the right approach is simply not putting anything at org-level that should not be there.

## Service Accounts

Service accounts are the GCP identity type for workloads — your application code, your GCE instances, your Cloud Run services, your CI/CD jobs. Understanding the different types and the associated risks is essential before you start managing them with Terraform.

### Types of Service Accounts

**User-managed service accounts** — the kind you create explicitly. They follow the naming pattern `SA_NAME@PROJECT_ID.iam.gserviceaccount.com`. You control them, you bind roles to them, and you manage their lifecycle. These are what you should use for all application workloads.

**Default service accounts** — automatically created by GCP when you enable certain APIs. The most dangerous one is the default Compute Engine service account, which is created when you enable the Compute Engine API and takes the form `PROJECT_NUMBER-compute@developer.gserviceaccount.com`. By default, this service account is automatically bound to `roles/editor` at the project level. Any GCE instance that does not have an explicitly assigned service account will run as this default SA. In practice, that means any code running on a VM that does not have a carefully configured SA gets Editor access to everything in the project. This is almost certainly not what you want. You should block the creation of this default binding using an org policy (`constraints/iam.automaticIamGrantsForDefaultServiceAccounts`) and configure explicit, scoped service accounts for your VMs.

### Key Management Pitfalls

Service accounts can authenticate using two mechanisms: short-lived tokens (generated automatically when code runs on GCP infrastructure) or long-lived JSON key files. Key files are the source of most service account security incidents.

A few facts about SA keys that should inform how you manage them:

- Each SA can have at most 10 active user-managed keys at a time
- Keys do not expire by default — a key created today will still be valid in five years unless you delete it
- Keys are not tracked in any GCP audit log after creation, so if one is leaked, you may not know which of your keys is compromised
- SA keys end up in Terraform state when managed as Terraform resources — if your state is not stored in an encrypted remote backend, you have effectively exposed those keys
- SA deletion is not immediately reversible — once you delete a service account, IAM bindings that referenced it retain a `deleted:` prefix on the member value and can only be cleaned up by removing the binding explicitly

The CIS GCP benchmark requires key rotation within 90 days. For organizations created after May 3, 2024, Google automatically enforces an org policy that disables SA key creation. For everyone else, the right approach is to avoid SA keys entirely for workloads that run on GCP infrastructure or that can use Workload Identity Federation for external workloads.

## Prerequisites

To follow along you will need:

- Terraform 1.3 or later
- The `google` provider version 4.x or later (the resources used in this post are stable in 4.x and 5.x)
- A GCP project with the IAM API enabled
- `gcloud` CLI authenticated and configured with a principal that has `roles/iam.securityAdmin` and `roles/resourcemanager.projectIamAdmin` on your target project

Verify your setup:

{% highlight bash %}
terraform version
gcloud auth list
gcloud config get-value project
{% endhighlight %}

Set your project as the default if it is not already:

{% highlight bash %}
gcloud config set project YOUR_PROJECT_ID
{% endhighlight %}

## Implementing IAM with Terraform

### Creating a Service Account

The starting point for any workload identity is `google_service_account`. Create a file called `iam.tf`:

{% highlight hcl %}
variable "project_id" {
  type        = string
  description = "GCP project ID"
}

resource "google_service_account" "app_sa" {
  account_id   = "my-application-sa"
  display_name = "My Application Service Account"
  description  = "Service account for the application backend — created by Terraform"
  project      = var.project_id
}
{% endhighlight %}

The `account_id` becomes the prefix of the SA's email address: `my-application-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com`. Keep it descriptive and consistent with your naming convention — you will reference this email in IAM bindings and it appears in audit logs, so readability matters.

### `google_project_iam_member` vs `google_project_iam_binding`: Authoritative vs Non-Authoritative

This is where most Terraform configurations go wrong. GCP IAM in Terraform comes in three resource types, and they have fundamentally different semantics. Picking the wrong one either destroys bindings that were set outside Terraform or leaves your configuration in a permanent drift state.

**`google_project_iam_policy`** — Fully authoritative. This resource manages the *entire* IAM policy for the project. When Terraform applies it, it replaces every binding in the project's policy with exactly what is in the resource. This means any binding that exists in the project but is not in your Terraform resource will be deleted. If you accidentally omit your own IAM binding, you can lock yourself out of the project. Do not use this resource. There is no scenario where replacing the entire project IAM policy from a single Terraform resource is the right operational choice.

**`google_project_iam_binding`** — Authoritative *per role*. This resource manages all members for a specific role. If you use it to manage `roles/pubsub.publisher`, Terraform will replace the entire list of members for that role with exactly what is in the resource. Any existing `roles/pubsub.publisher` binding that was set outside Terraform — in the console, via `gcloud`, by another team — will be deleted on the next apply. This is useful when you want strict control over exactly who holds a specific role, but it is destructive to any out-of-band grants.

**`google_project_iam_member`** — Non-authoritative. This resource manages a single principal/role tuple. It adds a binding without touching anything else. If someone manually adds a `roles/pubsub.publisher` binding in the console, Terraform does not remove it. Multiple teams can safely manage bindings in the same project without stepping on each other. This is the resource you should reach for by default in collaborative environments.

A critical constraint: **never mix `google_project_iam_binding` and `google_project_iam_member` for the same role in the same project**. If you manage `roles/pubsub.publisher` with `iam_binding` and also have an `iam_member` for the same role, Terraform will perpetually try to reconcile them — every plan will show changes, every apply will produce drift, and you will never reach a stable state. Pick one approach per role and stick with it.

Here is how to use `google_project_iam_member` to grant a scoped role to the service account we created above:

{% highlight hcl %}
resource "google_project_iam_member" "app_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = google_service_account.app_sa.member
}
{% endhighlight %}

The `google_service_account.app_sa.member` attribute returns the correctly formatted member string (`serviceAccount:my-application-sa@PROJECT_ID.iam.gserviceaccount.com`) directly from the resource, so you do not have to construct it manually.

If you need to grant multiple roles to this service account, add one `google_project_iam_member` block per role:

{% highlight hcl %}
resource "google_project_iam_member" "app_bigquery_reader" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = google_service_account.app_sa.member
}

resource "google_project_iam_member" "app_storage_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = google_service_account.app_sa.member
}
{% endhighlight %}

This is verbose, but it is explicit — you can see exactly what roles have been granted, to which principal, without reading through a potentially long list of members in an `iam_binding` block.

### When to Use `google_project_iam_binding`

`google_project_iam_binding` is appropriate when you are the sole owner of a project's IAM configuration and you want to enforce that a role's membership list is exactly what is in Terraform — no more, no less. A typical scenario is a project that is managed entirely by a platform team where no console access for IAM changes is allowed. Here is how a controlled binding looks:

{% highlight hcl %}
resource "google_project_iam_binding" "cloudbuild_builders" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"

  members = [
    google_service_account.app_sa.member,
    "serviceAccount:another-sa@${var.project_id}.iam.gserviceaccount.com",
  ]
}
{% endhighlight %}

Every time Terraform runs, it will ensure these two service accounts — and only these two service accounts — have `roles/cloudbuild.builds.builder`. Anyone who was granted that role out of band will be removed on the next apply. That behavior is the feature, not a bug, in the right context.

### Controlling Organization Policy for the Default SA

To prevent the dangerous default Compute SA editor binding at the org level, you can enforce the constraint via Terraform:

{% highlight hcl %}
resource "google_organization_policy" "disable_default_sa_grants" {
  org_id     = var.org_id
  constraint = "constraints/iam.automaticIamGrantsForDefaultServiceAccounts"

  boolean_policy {
    enforced = true
  }
}
{% endhighlight %}

This requires the `orgpolicy.googleapis.com` API and `roles/orgpolicy.policyAdmin` at org level. If you cannot enforce this at the org level, you can also set it at the project level using `google_project_organization_policy`.

## Workload Identity Federation

Long-lived SA keys are the main risk vector for service accounts used in external systems — CI/CD pipelines, GitHub Actions, GitLab CI, external monitoring tools. The key gets stored in a secret, the secret gets copied to multiple places, rotation gets deferred indefinitely, and eventually something leaks.

Workload Identity Federation eliminates the need for SA keys by allowing external workloads to exchange a short-lived credential from their own identity provider for a short-lived GCP access token. The exchange produces a token that is valid for about an hour. There is no long-lived secret to rotate or leak.

The Terraform configuration requires two resources: a workload identity pool and a provider within that pool.

{% highlight hcl %}
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions CI/CD"
  project                   = var.project_id
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"
  project                            = var.project_id

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.repository_id" = "assertion.repository_id"
  }

  attribute_condition = "assertion.repository_id == \"${var.github_repository_id}\""
}
{% endhighlight %}

Notice that the `attribute_condition` uses `repository_id` (the numeric GitHub repository ID), not `repository` (the name). This is a critical security detail: repository names can be reassigned if a repo is renamed or deleted and recreated. An attacker who creates a repository with the same name as yours would satisfy a condition that checks `repository`. The numeric `repository_id` is immutable — it is assigned when the repository is created and never changes. Always use the numeric ID in WIF conditions.

Once the pool and provider are created, you bind the external identity to your service account using `google_service_account_iam_member`:

{% highlight hcl %}
resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository_id/${var.github_repository_id}"
}
{% endhighlight %}

This allows any workflow in the specific GitHub repository (identified by its numeric ID) to impersonate your service account during CI/CD runs, without any static key material involved.

## Testing and Validation

After running `terraform apply`, use `gcloud` to verify that the IAM bindings are in place and look exactly as expected.

Check all bindings for a specific service account across the project:

{% highlight bash %}
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:my-application-sa" \
  --format="table(bindings.role)"
{% endhighlight %}

The `--flatten` flag expands the nested `bindings[].members` array so you can filter on individual member values. Without it, the filter would need to match the entire array. The output should list each role that has been granted to the service account — exactly what your Terraform resources specify and nothing more.

Verify no user-managed keys exist on the service account (if you have not created any, there should be none):

{% highlight bash %}
gcloud iam service-accounts keys list \
  --iam-account=my-application-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --filter="keyType=USER_MANAGED"
{% endhighlight %}

System-managed keys (used internally by GCP for token generation) will always exist — those are fine and expected. `USER_MANAGED` keys are the ones you create explicitly, and there should be zero of them unless you have a documented justification.

Check whether the default Compute Engine service account has Editor bound at the project level:

{% highlight bash %}
PROJECT_NUMBER=$(gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)")

gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com AND bindings.role:roles/editor" \
  --format="table(bindings.role, bindings.members)"
{% endhighlight %}

If this returns any results, you have the default Compute SA editor binding in place and it needs to be addressed. If the output is empty, you are clean.

To verify the Workload Identity Federation setup is configured correctly, you can inspect the pool and provider:

{% highlight bash %}
gcloud iam workload-identity-pools describe github-actions-pool \
  --project=YOUR_PROJECT_ID \
  --location=global

gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-actions-pool \
  --project=YOUR_PROJECT_ID \
  --location=global
{% endhighlight %}

Review the `attributeCondition` field in the provider output and confirm it matches what you set in Terraform.

## Best Practices

If you want to enforce these IAM patterns at scale, pairing them with static analysis is worthwhile. [Checkov custom policies for Azure Terraform resources](/checkov-custom-policies-azure-terraform/) shows how to write organization-specific checks for Terraform configurations — the same approach applies to GCP resources. For surfacing IAM misconfigurations that slip through in production, [automating GCP Security Command Center findings with Cloud Functions](/gcp-security-command-center-cloud-functions/) shows how to wire SCC alerts into a response pipeline. If you are managing IAM across multiple clouds, [AWS Security Hub centralized findings with Terraform](/aws-security-hub-terraform/) covers the equivalent pattern on AWS.

**Never use primitive roles in production.** `roles/owner`, `roles/editor`, and `roles/viewer` are deprecated patterns that predate GCP's granular IAM model. They grant access to every service in the project. Start with the most specific predefined role that covers the access you need, and document why if you cannot find one. The extra effort to identify the right predefined role pays for itself the first time you audit a compromise and need to determine what a principal could have accessed.

**Apply least privilege per workload, not per team.** Each service, each application component, and each CI/CD pipeline step should have its own service account with only the roles it actually uses. Sharing a service account across multiple services makes it impossible to scope access correctly — the SA ends up with the union of all roles needed by everything that uses it. Separate SAs are cheap; the blast radius of a compromised shared SA is not.

**Use `google_project_iam_member` for most bindings.** The non-authoritative resource is the safer default in any environment where multiple teams or processes touch IAM. It adds bindings without removing anything out-of-band. Only graduate to `google_project_iam_binding` when you need strict enforcement of a role's membership list and you are the sole manager of that project's IAM configuration.

**Never mix `iam_binding` and `iam_member` for the same role.** This causes a permanent plan diff because Terraform's `iam_binding` will always try to remove the member added by `iam_member`, and the `iam_member` will add it back on the next apply. If you inherit a Terraform configuration in this state, pick one resource type, consolidate all the bindings for that role under it, and remove the other.

**Eliminate SA keys wherever Workload Identity Federation is available.** For any external workload that supports OIDC token exchange — GitHub Actions, GitLab CI, CircleCI, Jenkins with the appropriate plugin — WIF is strictly better than a SA key. The credentials are short-lived, automatically rotated, and there is no secret to manage. Reserve SA keys only for workloads that genuinely cannot use WIF, and enforce key rotation within 90 days using a Cloud Scheduler job or organization policy audit.

**Store remote state with encryption.** Even if you never intentionally create SA keys in Terraform, credentials and sensitive values can end up in state. Use a GCS bucket with CMEK (customer-managed encryption keys) for your Terraform state backend. This is especially important in GCP because service account key files, if you do create them, are stored in plaintext in Terraform state.

**Audit org-level and folder-level bindings regularly.** Project-level IAM policies inherit from above. A clean project-level policy does not mean a principal cannot access resources in that project — they may have inherited access from the folder or organization. Review the full inherited policy with `gcloud projects get-iam-policy` plus `gcloud resource-manager folders get-iam-policy` for each folder in the hierarchy above your project.

## Conclusion

GCP IAM is powerful and consistent once you understand its structure. The resource hierarchy with additive inheritance, the three-tier role system from primitive to predefined to custom, and the clean principal type taxonomy give you a solid foundation to reason about access. The biggest operational challenges are not in the model itself — they are in the common patterns that accumulate over time: primitive roles that were "just for testing," default service accounts that were never scoped down, and SA keys that were created once and never rotated.

On the Terraform side, the authoritative versus non-authoritative distinction in `google_project_iam_member`, `google_project_iam_binding`, and `google_project_iam_policy` is the single most important thing to get right before you start managing production IAM as code. Use `iam_member` as your default, use `iam_binding` when you need strict role membership enforcement, and avoid `iam_policy` entirely.

With the service accounts created, scoped with predefined roles via `iam_member`, keys avoided in favor of Workload Identity Federation, and the whole setup verified with `gcloud`, you have a repeatable, auditable, and principled IAM configuration that you can evolve as your architecture grows. For automated auditing of Cloud Audit Logs against this kind of IAM configuration, see the [GCP automated compliance reporter using Cloud Audit Logs](/gcp-adk-compliance-reporter/).

Happy scripting!
