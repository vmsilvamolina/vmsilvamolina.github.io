---
title: 'GCP Workload Identity Federation GitHub Actions Terraform'
author: Victor Silva
date: 2025-04-14T10:00:00+00:00
layout: post
permalink: /gcp-workload-identity-federation-github-actions/
excerpt: "Service account keys in CI/CD pipelines are a silent liability. This post shows how to replace them with GCP Workload Identity Federation using google_iam_workload_identity_pool and Terraform."
categories:
  - GCP
  - Security
tags:
  - GCP
  - Workload Identity Federation
  - GitHub Actions
  - Terraform
  - keyless auth GCP
  - WIF Terraform
  - google_iam_workload_identity_pool
  - OIDC
  - Security
---

When you first connect a GitHub Actions pipeline to Google Cloud, the path of least resistance is a service account key. You create the key, base64-encode it, paste it into a GitHub secret, and move on. It works on day one. But it also introduces a problem that grows quietly in the background: a static, long-lived credential that never expires, is stored in plaintext in GitHub's secret store, and often ends up in `.env` files, CI logs, and git history before anyone notices.

Service account keys do not expire by default. When they are compromised — and in CI/CD pipelines they eventually are — the attacker has uninterrupted access until someone manually audits the IAM console, notices an unfamiliar key, and revokes it. That window is measured in days or weeks, not minutes.

Workload Identity Federation eliminates the key entirely. Instead of a stored credential, your pipeline proves who it is using a short-lived OIDC token issued by GitHub, which GCP exchanges for a short-lived access token scoped to a specific service account. The token is valid for about one hour and is never stored anywhere. There is nothing to rotate, nothing to leak, and nothing to revoke after an incident.

This post walks through the complete implementation: how the token exchange works, the Terraform resources you need to build it, the GitHub Actions workflow that uses it, and the one security decision that most tutorials get wrong — the `attribute_condition`.

## How Workload Identity Federation Works

The flow is based on the OIDC standard, and it is worth understanding before writing any Terraform. When a GitHub Actions job runs, GitHub's OIDC provider issues a signed JWT to the workflow. That JWT contains claims that describe the job: the repository name, the repository ID, the branch, the actor, and several others.

Your pipeline sends that JWT to GCP's Security Token Service (STS). STS validates the JWT signature against GitHub's public OIDC discovery document, checks that the claims satisfy any conditions you have defined, and — if everything checks out — issues a short-lived GCP access token. That token is federated into a service account through a workload identity binding, giving the pipeline the same permissions the service account holds.

The data flow looks like this:

```
GitHub Actions runner
        |
        | 1. Request OIDC token from GitHub
        v
GitHub OIDC Provider (token.actions.githubusercontent.com)
        |
        | 2. Return signed JWT with repo/job claims
        v
GitHub Actions runner
        |
        | 3. Exchange JWT for GCP access token (STS)
        v
GCP Security Token Service
        |
        | 4. Validate JWT, check attribute_condition
        | 5. Return short-lived federated token
        v
GitHub Actions runner
        |
        | 6. Impersonate service account using federated token
        v
GCP Service Account (1-hour access token)
```

The critical security boundary is step 4. Without an `attribute_condition`, GCP will accept a valid JWT from *any* GitHub Actions workflow and federate it into your service account. That means any public GitHub repository can impersonate your service account. We will address this properly below.

## Prerequisites

You will need:

- A GCP project with billing enabled
- `gcloud` CLI authenticated with Owner or Editor permissions
- Terraform 1.5 or higher
- A GitHub repository from which you want to deploy

Verify your tools before starting:

{% highlight bash %}
gcloud --version
terraform --version
gh --version
{% endhighlight %}

Enable the IAM and Security Token Service APIs in your GCP project:

{% highlight bash %}
gcloud services enable iamcredentials.googleapis.com \
  sts.googleapis.com \
  --project=YOUR_PROJECT_ID
{% endhighlight %}

## Finding Your Repository ID

Before writing any Terraform you need your GitHub repository's numeric ID. This is the detail most guides skip, and it is the single most important input to a secure WIF setup.

GitHub repository *names* are mutable. You can rename a repository. If your `attribute_condition` is based on the repository name and you rename the repository, another user could register the old name and immediately gain the ability to impersonate your service account. Repository *IDs* are assigned at creation time and never change.

Retrieve your repository ID from the GitHub API:

{% highlight bash %}
curl -s https://api.github.com/repos/OWNER/REPO | jq .id
{% endhighlight %}

You can also find it in the GitHub UI under **Settings > General**, scrolled to the bottom of the page where it is labeled "Repository ID".

Store this value — you will pass it to Terraform as a variable.

## Building the Infrastructure with Terraform

The Terraform configuration needs four resources: an identity pool, an OIDC provider inside that pool, a service account for your pipeline to impersonate, and an IAM binding that authorizes the pool to impersonate that service account.

Create a `variables.tf` file first:

{% highlight hcl %}
# variables.tf

variable "project_id" {
  description = "GCP project ID where the WIF pool will be created"
  type        = string
}

variable "github_repository_id" {
  description = "Numeric GitHub repository ID (immutable). Find via: curl https://api.github.com/repos/OWNER/REPO | jq .id"
  type        = string
}
{% endhighlight %}

Now the main configuration:

{% highlight hcl %}
# main.tf

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

# --- Workload Identity Pool ---
# The pool is a container for external identity providers.
# One pool per environment (or one shared pool per org) is a reasonable model.

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions CI/CD pipelines"
}

# --- OIDC Provider ---
# The provider tells GCP where to validate JWTs from and how to map
# JWT claims to Google IAM attributes.

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.actor"               = "assertion.actor"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
  }

  # CRITICAL: Lock down which repositories can use this pool.
  # Use the numeric repository_id — names are mutable and can be taken
  # by another user after a rename, creating a typosquatting vector.
  attribute_condition = "assertion.repository_id == \"${var.github_repository_id}\""
}

# --- Service Account for CI/CD ---
# Grant this SA only the permissions your pipeline actually needs.
# Avoid broad roles like Editor or Owner.

resource "google_service_account" "cicd_sa" {
  project      = var.project_id
  account_id   = "github-actions-deploy"
  display_name = "GitHub Actions Deployment SA"
  description  = "Used by GitHub Actions via Workload Identity Federation"
}

# --- WIF Binding ---
# This grants the workload identity pool permission to impersonate the SA.
# The principalSet targets all identities from the pool whose
# repository_id attribute matches our repository.

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.cicd_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository_id/${var.github_repository_id}"
}

# --- Outputs ---
# The workflow secret WIF_PROVIDER needs the full provider resource name.
# The SA email goes into GCP_SA_EMAIL.

output "workload_identity_provider" {
  description = "Full provider resource name — use this as WIF_PROVIDER in GitHub secrets"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "service_account_email" {
  description = "SA email — use this as GCP_SA_EMAIL in GitHub secrets"
  value       = google_service_account.cicd_sa.email
}
{% endhighlight %}

Apply the configuration:

{% highlight bash %}
terraform init
terraform plan -var="project_id=YOUR_PROJECT_ID" -var="github_repository_id=YOUR_REPO_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID" -var="github_repository_id=YOUR_REPO_ID"
{% endhighlight %}

### Understanding the `attribute_condition`

The `attribute_condition` field deserves extra attention because it is the line that makes the difference between a secure setup and a wide-open one.

Without `attribute_condition`, GCP accepts any JWT signed by `https://token.actions.githubusercontent.com`. Every GitHub Actions workflow in every repository on GitHub.com — public or private — is issued tokens by this same provider. Omitting the condition means any of them can exchange a JWT for access to your service account.

Using `attribute.repository` (the name) is better than nothing, but it is still vulnerable: if you rename or delete the repository, someone else can register the same name and immediately have a valid claim.

Using `assertion.repository_id` (the numeric ID) is correct. The ID is assigned once, tied to the repository's lifetime, and cannot be transferred. Even if the repository is deleted and another repository with the same name is created, the IDs will differ.

If you want to allow multiple repositories to use the same pool — for example, a monorepo and a separate infrastructure repository — you can express this as a logical OR:

{% highlight hcl %}
attribute_condition = "assertion.repository_id in [\"123456789\", \"987654321\"]"
{% endhighlight %}

## GitHub Actions Workflow

Now let's wire this up in your pipeline. Create `.github/workflows/deploy.yml`:

{% highlight yaml %}
name: Deploy with Workload Identity Federation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# The id-token permission is required for the OIDC token request.
# Without it, the auth step fails — often with a misleading error.
permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        id: auth
        uses: google-github-actions/auth@v2
        with:
          # Full provider resource name from Terraform output
          # Format: projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL_ID/providers/PROVIDER_ID
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.GCP_SA_EMAIL }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Verify authentication
        run: gcloud auth list

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-app \
            --image=us-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/my-repo/my-app:${{ github.sha }} \
            --region=us-central1 \
            --platform=managed \
            --quiet
{% endhighlight %}

Notice the `permissions` block at the top level. This is non-negotiable. GitHub Actions workflows do not request an OIDC token by default — you have to explicitly grant the `id-token: write` permission. If it is missing, the `google-github-actions/auth` step will fail, and the error message is not always obvious about the root cause.

Setting permissions at the job level works too, but it is better to set them at the workflow level for clarity:

{% highlight yaml %}
jobs:
  deploy:
    permissions:
      contents: read
      id-token: write
    runs-on: ubuntu-latest
{% endhighlight %}

### Adding the GitHub Secrets

After running `terraform apply`, retrieve the output values:

{% highlight bash %}
terraform output workload_identity_provider
terraform output service_account_email
{% endhighlight %}

Add them as secrets in your GitHub repository under **Settings > Secrets and variables > Actions**:

- `WIF_PROVIDER` — the full provider resource name (e.g., `projects/123456789/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider`)
- `GCP_SA_EMAIL` — the service account email (e.g., `github-actions-deploy@YOUR_PROJECT_ID.iam.gserviceaccount.com`)

You can also retrieve the provider name directly from `gcloud` if you prefer not to use Terraform output:

{% highlight bash %}
gcloud iam workload-identity-pools providers describe github-provider \
  --workload-identity-pool=github-actions-pool \
  --location=global \
  --project=YOUR_PROJECT_ID \
  --format="value(name)"
{% endhighlight %}

## Testing and Validation

Push the workflow to your repository and watch the Actions tab. The `Authenticate to Google Cloud` step should complete without errors and show output like:

```
Successfully created keyless credential for projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-provider
```

If you want to validate the setup before triggering a full deploy, add a temporary verification step that calls `gcloud auth list`:

{% highlight bash %}
gcloud auth list
# Expected output:
#    Credentialed Accounts
# ACTIVE  ACCOUNT
# *       github-actions-deploy@YOUR_PROJECT_ID.iam.gserviceaccount.com
{% endhighlight %}

To confirm the token exchange is being audited, check GCP's audit logs. In the Cloud Console, navigate to **Logging > Logs Explorer** and filter for:

{% highlight text %}
resource.type="service_account"
protoPayload.methodName="GenerateAccessToken"
protoPayload.authenticationInfo.serviceAccountKeyName:"workloadIdentityPools"
{% endhighlight %}

You will see one entry per workflow run, showing the federated principal that requested the impersonation, the timestamp, and the service account that was impersonated. This gives you a complete audit trail with zero additional configuration.

To verify the `attribute_condition` is doing its job, create a simple workflow in a *different* repository that targets the same provider and service account. The token exchange should fail with a permission denied error, confirming that the numeric ID filter is working correctly.

## Migrating from Service Account Keys

If you already have pipelines using service account keys, the migration is straightforward and can be done with zero downtime.

**Step 1: Deploy the WIF infrastructure.** Apply the Terraform configuration above. Your existing key-based workflows continue to work during this step.

**Step 2: Update the workflow.** Replace the key-based auth step:

{% highlight yaml %}
# Before — key-based auth
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}
{% endhighlight %}

{% highlight yaml %}
# After — keyless WIF auth
- name: Authenticate to GCP
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.GCP_SA_EMAIL }}
{% endhighlight %}

**Step 3: Run the updated workflow and verify** that authentication succeeds and all downstream steps work as expected.

**Step 4: Delete the service account key.** In the GCP Console under **IAM > Service Accounts**, select the service account, go to the **Keys** tab, and delete the key. Alternatively:

{% highlight bash %}
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=github-actions-deploy@YOUR_PROJECT_ID.iam.gserviceaccount.com
{% endhighlight %}

**Step 5: Remove the `GCP_SA_KEY` GitHub secret** from your repository. The old secret is now dead weight, and removing it reduces the attack surface.

## Best Practices and Common Pitfalls

**Always use `repository_id`, never `repository`.** This is the most important rule and the one most commonly violated in tutorials. Repository names are mutable, IDs are not. A typosquatting attack using a mutable name condition is trivial to execute.

**Do not omit `attribute_condition`.** A WIF provider without an `attribute_condition` accepts tokens from any GitHub repository. This is equivalent to issuing a service account key and posting it publicly. Always scope the condition to at least a repository ID, and ideally also an organization owner ID for defense in depth:

{% highlight hcl %}
attribute_condition = "assertion.repository_id == \"${var.github_repository_id}\" && assertion.repository_owner_id == \"${var.github_org_id}\""
{% endhighlight %}

**Scope service account permissions tightly.** The fact that WIF eliminates key management does not change the principle of least privilege. If your pipeline only deploys to Cloud Run, grant `roles/run.developer` — not `roles/editor`. Use the service account as the enforcement boundary it is meant to be.

**Use one pool per environment, not one pool for everything.** A staging pool and a production pool with separate service accounts and separate `attribute_condition` values makes it impossible for a staging workflow to accidentally or maliciously act against production resources. The Terraform module pattern handles this cleanly through workspaces or separate variable files.

**Store `WIF_PROVIDER` as a secret, not a plain variable.** The provider resource name contains your GCP project number, which is low-sensitivity but not public. Treat it as a secret to avoid unnecessary information disclosure.

**The `id-token: write` permission must be present.** Without it, the OIDC token request is blocked by GitHub's token permissions model. The `google-github-actions/auth` action will surface an error, but it may not immediately name the missing permission. Any time WIF auth fails in a new workflow, check this first.

**Org-level CI considerations.** The Workload Identity Pool is project-scoped. If you have dozens of repositories across an organization and want a single centralized WIF configuration, create a dedicated CI project that hosts the pool and provider. Each repository's workflows federate through that project, and cross-project service account impersonation handles the actual resource access. This avoids proliferating pools across every project.

## Conclusion

Workload Identity Federation removes the biggest operational liability in GCP-connected CI/CD pipelines: the service account key. With the Terraform resources and GitHub Actions workflow in this post, you have a keyless authentication setup that issues short-lived tokens, leaves no stored credentials anywhere in your repository, and gives you a full audit trail of every pipeline authentication event in GCP's logging.

The two decisions that matter most are the ones easiest to get wrong: always use `repository_id` (not `repository`) in your `attribute_condition`, and never leave the condition empty. Get those right and the rest follows naturally.

If you are building on this and want to understand the IAM model that underpins everything here, check out the earlier post on [GCP IAM fundamentals with Terraform](/gcp-iam-fundamentals-terraform/). For storing the credentials and secrets your pipeline needs at runtime, [GCP Secret Manager managed with Terraform](/gcp-secret-manager-terraform/) covers the provisioning side. If your pipeline deploys container workloads, pairing WIF with [signing container images with Cosign and Sigstore](/signing-container-images-cosign-sigstore/) closes the supply chain loop. For broader GCP security posture on what your pipeline deploys into, [GCP Security Command Center with Cloud Functions](/gcp-security-command-center-cloud-functions/) covers the detection layer.

Happy scripting!
