---
title: 'Azure Workload Identity Federation for GitHub Actions'
author: Victor Silva
date: 2026-10-18T14:46:31+00:00
layout: post
permalink: /azure-workload-identity-federation-github-actions/
excerpt: "Drop AZURE_CREDENTIALS: set up Azure workload identity federation for GitHub Actions with Terraform, immutable subjects, and AADSTS700213 fixes."
categories:
  - Azure
  - Security
tags:
  - Workload Identity Federation
  - GitHub Actions
  - Azure OIDC
  - Microsoft Entra ID
  - Terraform
  - Managed Identity
  - Federated Identity Credential
  - azure/login
  - AADSTS700213
---

Open the secrets page of almost any GitHub repository that deploys to Azure with GitHub Actions and you'll find the same thing: an `AZURE_CREDENTIALS` JSON blob, or an `ARM_CLIENT_SECRET` sitting next to `ARM_CLIENT_ID`. Somebody ran `az ad sp create-for-rbac --sdk-auth` a few years ago, gave the service principal Contributor on the subscription "just to get it working", pasted the output into GitHub, and nobody has thought about it since. The pipeline works. Right up until the secret expires on a Friday afternoon, or until it shows up in a log, or a fork, or a laptop backup.

That secret is a password for a principal that can probably rewrite your production subscription. It doesn't care which repository, branch or job presents it. Whoever holds the string *is* the pipeline.

Azure workload identity federation removes it. GitHub mints a short-lived OIDC token for the job, Microsoft Entra ID exchanges it for an access token, and the only thing you store in GitHub is a client ID, which isn't a secret. I already walked through the OIDC mechanics in the [GCP version of this post](/gcp-workload-identity-federation-github-actions/), so I won't repeat the token-flow diagram here. This one is about the parts that are specific to Azure, which turn out to be the parts that bite: exact-match subjects, a hard cap of 20 credentials per identity, the subject format change GitHub rolled out in July 2026, and how to make sure the old secrets are actually gone once you're done.

The design I'll build is the one I keep coming back to for Terraform repos: **plan with a Reader identity on pull requests, apply with a write identity that only exists behind a protected GitHub environment.**

## Entra Federated Identity Credentials Have No Condition Language

On GCP, the provider has an `attribute_condition` — a CEL expression where you can say "repository ID equals X and owner ID equals Y" and be done. Entra's standard federated identity credential (FIC) has nothing like that. It is three strings and a match:

| | GCP WIF provider | Entra standard FIC | Entra flexible FIC |
|---|---|---|---|
| Matching | CEL `attribute_condition` over any mapped claim | Exact, case-sensitive match on `iss`, `sub`, `aud` | Expression over `sub`, `job_workflow_ref`, `repository_id`, `repository_owner_id` |
| Wildcards | Yes, via CEL | No | `matches` with `*` and `?` |
| Limit | Pools/providers per project | 20 FICs per app or managed identity | Same 20 |
| Status | GA | GA | **Preview** |

Everything interesting in Azure therefore happens *before* the token reaches Entra: you need to know exactly what `sub` string a given job will present, and you need to spend your 20 slots wisely. A wrong subject isn't rejected when you create the FIC either. Entra will happily store `repo:contoso/Payments-API:environment:prod` and you'll only find out it's wrong when the login fails, because matching is case-sensitive.

## Which GitHub OIDC Subject Will This Job Present?

This is the table I wish someone had shown me the first time. GitHub builds the default `sub` claim from the job context, and there is a precedence order:

| Job context | Default `sub` |
|---|---|
| Job declares `environment:` | `repo:contoso/payments-api:environment:production` |
| `pull_request` event, no environment | `repo:contoso/payments-api:pull_request` |
| Push or dispatch on a branch | `repo:contoso/payments-api:ref:refs/heads/main` |
| Tag | `repo:contoso/payments-api:ref:refs/tags/v1.4.0` |

Environment wins over everything. A job with `environment: production` that runs on a push to `main` presents the environment subject, *not* the branch subject, so a FIC for `ref:refs/heads/main` will never match it. Pull requests come next, and the PR subject carries no PR number and no branch name: every PR in the repo looks identical to Entra. Branch and tag refs are the fallback.

One inconsistency worth knowing about: parts of Microsoft's CLI and REST documentation write the PR subject as `:pull-request` with a hyphen. GitHub emits `:pull_request` with an underscore. Use the underscore. The hyphenated one gets created without complaint and never matches anything.

Read that table as a design tool rather than trivia. Each row is a different trust boundary, and they are not equally strong:

- **Environment subjects** are the only ones where GitHub enforces something before the token exists. Required reviewers, deployment branch policies and wait timers all run before the job starts, so before it can request a token.
- **The pull_request subject** is shared by every PR from every branch. Anyone who can open a PR that runs a workflow with `id-token: write` gets that identity.
- **Branch subjects** trust whatever workflow runs on that ref, triggered by whatever event lands there.

So the write identity goes behind an environment, the PR identity gets nothing it could damage, and branch subjects are for cases where neither fits.

## Plan Reads, Apply Writes

Here's the shape:

{% highlight text %}
PR opened ──► job "plan"   (no environment)
              sub = repo:contoso/payments-api:pull_request
              └─► id-gh-payments-plan   Reader on rg-payments-prod
                                         Blob Data Reader on tfstate container

push main ──► job "apply"  environment: production (reviewers + main only)
              sub = repo:contoso/payments-api:environment:production
              └─► gh-payments-api-deploy  Contributor on rg-payments-prod
                                           Blob Data Contributor on tfstate container
{% endhighlight %}

Two identities, two FICs, two role sets. A malicious PR can run `terraform plan` against production with Reader rights, and that's the ceiling.

### App registration or user-assigned managed identity?

Both can hold FICs, and `azure/login` treats them the same way: you pass the client ID and leave `auth-type` at its default. (`auth-type: IDENTITY` is for self-hosted runners sitting on Azure VMs, not for OIDC.) The differences are about governance:

| | App registration + service principal | User-assigned managed identity |
|---|---|---|
| Lives in | Entra (Microsoft Graph) | ARM, inside a resource group |
| Who can add FICs | App owners, Application/Cloud Application Administrator | Anyone with write on the UAMI (Managed Identity Contributor, Contributor) |
| Can hold a client secret | Yes | No |
| Bootstrap needs Entra admin | Yes | No |
| Graph API permissions | Natural fit | Possible, awkward |

My default is a UAMI. It cannot grow a client secret, it's governed by the same Azure RBAC and Azure Policy as everything else, and teams can create one without opening a ticket with the identity team. I covered the UAMI lifecycle in [system vs user-assigned managed identities](/azure-managed-identity-system-vs-user-assigned/). App registrations make sense when the pipeline needs Graph permissions, or when your org already manages pipeline identities in Entra.

In the examples below I deliberately use one of each — a UAMI for plan, an app registration for apply — so you see both shapes. In a real repo, pick one and stick with it.

## Creating Federated Identity Credentials with the Azure CLI

You need Azure CLI 2.30 or newer, rights to create role assignments on the target resource group, and (for the app registration half) an Entra role that can create applications.

{% highlight bash %}
az version --query '"azure-cli"' -o tsv
az account show --query "{subscription:id, tenant:tenantId, user:user.name}" -o json
{% endhighlight %}

First the plan identity, a UAMI trusted by the `pull_request` subject:

{% highlight bash %}
#!/usr/bin/env bash
set -euo pipefail

ORG=contoso
REPO=payments-api
APP_RG=rg-payments-prod
ID_RG=rg-identities
SUB_ID=$(az account show --query id -o tsv)
STATE_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/rg-tfstate/providers/Microsoft.Storage/storageAccounts/sttfstatecontoso/blobServices/default/containers/tfstate"

az identity create -g "$ID_RG" -n id-gh-payments-plan -o none
PLAN_CLIENT_ID=$(az identity show -g "$ID_RG" -n id-gh-payments-plan --query clientId -o tsv)
PLAN_PRINCIPAL_ID=$(az identity show -g "$ID_RG" -n id-gh-payments-plan --query principalId -o tsv)

az identity federated-credential create \
  --name gh-payments-pr \
  --identity-name id-gh-payments-plan \
  --resource-group "$ID_RG" \
  --issuer https://token.actions.githubusercontent.com \
  --subject "repo:${ORG}/${REPO}:pull_request" \
  --audiences api://AzureADTokenExchange

az role assignment create --assignee-object-id "$PLAN_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Reader \
  --scope "/subscriptions/${SUB_ID}/resourceGroups/${APP_RG}"

az role assignment create --assignee-object-id "$PLAN_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Reader" \
  --scope "$STATE_SCOPE"

echo "AZURE_PLAN_CLIENT_ID=${PLAN_CLIENT_ID}"
{% endhighlight %}

Then the apply identity, an app registration trusted only by the `production` environment:

{% highlight bash %}
#!/usr/bin/env bash
set -euo pipefail

ORG=contoso
REPO=payments-api
APP_RG=rg-payments-prod
SUB_ID=$(az account show --query id -o tsv)
STATE_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/rg-tfstate/providers/Microsoft.Storage/storageAccounts/sttfstatecontoso/blobServices/default/containers/tfstate"

APP_ID=$(az ad app create --display-name "gh-${REPO}-deploy" --query appId -o tsv)
APP_OBJ_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
SP_OBJ_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

cat > fic-prod.json <<EOF
{
  "name": "gh-${REPO}-env-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${ORG}/${REPO}:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create --id "$APP_OBJ_ID" --parameters fic-prod.json
az ad app federated-credential list --id "$APP_OBJ_ID" -o table

# Resource group scope. Never subscription Owner or User Access Administrator.
az role assignment create --assignee-object-id "$SP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/${SUB_ID}/resourceGroups/${APP_RG}"

az role assignment create --assignee-object-id "$SP_OBJ_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_SCOPE"

echo "AZURE_DEPLOY_CLIENT_ID=${APP_ID}"
{% endhighlight %}

If the first login fails a minute after you create the FIC with `AADSTS70021`, wait. New FICs take a few minutes to propagate, and Microsoft's own guidance is to retry rather than debug immediately.

### Why Blob Data *Reader* for plan?

The usual advice is to give the plan identity Storage Blob Data Contributor so `terraform plan` can take the blob lease lock. I don't like that. It means every pull request in the repo can overwrite production state. I'd rather run PR plans with `-lock=false` and keep the PR identity read-only on the state container. A plan that races an apply is a stale plan, which you were going to re-run anyway; a PR that rewrites state is an incident. Test this in your setup — if the backend ever needs to create a new workspace blob during `init`, a read-only role will fail there.

Keep in mind that read access to state still means read access to whatever sensitive values your state holds. That's a cost of plan-on-PR in general, not of OIDC.

## Federated Identity Credentials in Terraform (azurerm and azuread)

For anything beyond a one-off, put the identities in a bootstrap Terraform root that a human (or a separate, tightly held pipeline) applies. The runner for this root needs `Application.ReadWrite.OwnedBy` and ownership of the app, or `Application.ReadWrite.All`, to manage the app registration.

{% highlight hcl %}
terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = { source = "hashicorp/azuread", version = "~> 3.10" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 5.10" }
  }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true
}

variable "subscription_id" { type = string }
variable "github_org" {
  type    = string
  default = "contoso"
}
variable "github_repo" {
  type    = string
  default = "payments-api"
}

locals {
  issuer   = "https://token.actions.githubusercontent.com"
  audience = "api://AzureADTokenExchange"
  repo     = "${var.github_org}/${var.github_repo}"
}

data "azurerm_resource_group" "app" {
  name = "rg-payments-prod"
}

data "azurerm_resource_group" "identities" {
  name = "rg-identities"
}

data "azurerm_storage_account" "tfstate" {
  name                = "sttfstatecontoso"
  resource_group_name = "rg-tfstate"
}

locals {
  state_container_scope = "${data.azurerm_storage_account.tfstate.id}/blobServices/default/containers/tfstate"
}

# ---------- Plan identity: UAMI, pull_request subject, read-only ----------

resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-gh-payments-plan"
  resource_group_name = data.azurerm_resource_group.identities.name
  location            = data.azurerm_resource_group.identities.location
}

resource "azurerm_federated_identity_credential" "plan_pr" {
  name                      = "gh-payments-pr"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan.id
  audience                  = [local.audience]
  issuer                    = local.issuer
  subject                   = "repo:${local.repo}:pull_request"
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                = data.azurerm_resource_group.app.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "plan_state" {
  scope                = local.state_container_scope
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------- Apply identity: app registration, environment subject ----------

resource "azuread_application_registration" "deploy" {
  display_name = "gh-${var.github_repo}-deploy"
}

resource "azuread_service_principal" "deploy" {
  client_id = azuread_application_registration.deploy.client_id
}

resource "azuread_application_federated_identity_credential" "production" {
  application_id = azuread_application_registration.deploy.id
  display_name   = "gh-${var.github_repo}-env-production"
  audiences      = [local.audience]
  issuer         = local.issuer
  subject        = "repo:${local.repo}:environment:production"
}

resource "azurerm_role_assignment" "deploy_rg" {
  scope                = data.azurerm_resource_group.app.id
  role_definition_name = "Contributor" # swap for a narrower custom role when you can
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_state" {
  scope                = local.state_container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

output "AZURE_PLAN_CLIENT_ID" {
  value = azurerm_user_assigned_identity.plan.client_id
}

output "AZURE_DEPLOY_CLIENT_ID" {
  value = azuread_application_registration.deploy.client_id
}
{% endhighlight %}

If you've been on azurerm 3.x or early 4.x, note the argument name: `azurerm_federated_identity_credential` takes `user_assigned_identity_id` now. It was `parent_id` until 4.65, and `resource_group_name` is gone entirely in v5. Old modules copied from blog posts will fail validation on that. Also, the provider creates FICs on the same UAMI one at a time on purpose. ARM returns `409` if you write several in parallel, which matters if you ever do this from an ARM/Bicep loop (use serial mode there).

### The state backend

The application root (the one the workflow runs) authenticates its backend through OIDC too, and with `use_azuread_auth` it uses data-plane RBAC instead of storage account keys:

{% highlight hcl %}
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatecontoso"
    container_name       = "tfstate"
    key                  = "payments/prod.tfstate"
    use_oidc             = true
    use_azuread_auth     = true
    # client_id and tenant_id come from ARM_CLIENT_ID / ARM_TENANT_ID
  }
}
{% endhighlight %}

Once both pipelines use Entra auth for state, set `shared_access_key_enabled = false` on the state storage account (if you're still setting that backend up, start with [Terraform remote state in Azure Blob Storage](/terraform-remote-state-azure-blob-storage/)). Otherwise you've removed the client secret and left a storage key that grants the same state access.

## GitHub Actions Workflow with Azure OIDC

{% highlight yaml %}
{% raw %}name: terraform

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write          # sub = repo:contoso/payments-api:pull_request
    env:
      ARM_USE_OIDC: "true"
      ARM_CLIENT_ID: ${{ vars.AZURE_PLAN_CLIENT_ID }}
      ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    steps:
      - uses: actions/checkout@v5
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init -input=false
      - run: terraform plan -input=false -lock=false -no-color

  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production    # sub = repo:contoso/payments-api:environment:production
    permissions:
      contents: read
      id-token: write
    env:
      ARM_USE_OIDC: "true"
      ARM_CLIENT_ID: ${{ vars.AZURE_DEPLOY_CLIENT_ID }}
      ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    steps:
      - uses: actions/checkout@v5
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init -input=false
      - run: terraform apply -input=false -auto-approve

      # Only needed because the next step uses az, not for Terraform
      - uses: azure/login@v3   # pin to a full commit SHA in production
        with:
          client-id: ${{ vars.AZURE_DEPLOY_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - name: Smoke test
        run: az resource list -g rg-payments-prod --query "length(@)" -o tsv
{% endraw %}{% endhighlight %}

A few things in there are deliberate.

`id-token: write` is granted per job, not at workflow level. Any job you add later can't mint a token unless someone grants it explicitly in review.

Terraform does not need `azure/login`. With `ARM_USE_OIDC=true`, both the azurerm provider and the backend read `ACTIONS_ID_TOKEN_REQUEST_URL` and `ACTIONS_ID_TOKEN_REQUEST_TOKEN` from the runner and do the exchange themselves. I only call `azure/login` in the apply job because the smoke test uses `az`. And it's `@v3` — Microsoft's own Learn tutorial still shows `@v2` at the time of writing, so don't copy the version from there. `azure/login` releases are immutable; pin the full SHA if your org pins actions, or `@v3` if you prefer getting fixes automatically.

The IDs live in `vars`, not `secrets`. A client ID, tenant ID and subscription ID don't grant anything on their own. Microsoft's tutorial puts them in secrets and that's fine too, it just makes logs harder to read. What you should never do is feed {% raw %}`${{ github.event.* }}`{% endraw %} into `client-id`, `tenant-id` or `subscription-id`; the `azure/login` README calls this out specifically.

The `production` environment needs real protection, or the environment subject is just a longer string. In **Settings > Environments > production**, add required reviewers, turn on "prevent self-review", and restrict deployment branches to `main`.

### Testing and validation

Push the workflow and open a PR. In the `azure/login` step (or in any step after it), you're looking for this:

{% highlight bash %}
az account show --query "{subscription:id, principal:user.name, type:user.type}" -o json
# {
#   "principal": "<client ID of the identity>",
#   "subscription": "...",
#   "type": "servicePrincipal"
# }
{% endhighlight %}

`azure/login` also prints a "Federated token details" block with the subject, issuer and audience it presented. When something fails, read that line before anything else.

Then do the negative tests, which matter more than the happy path:

1. Add a throwaway job to a feature branch that uses `AZURE_DEPLOY_CLIENT_ID` without `environment: production`. It must fail with `AADSTS700213`.
2. From a PR, try `terraform apply` with the plan identity. Authentication succeeds and the first write fails with an authorization error from ARM.
3. Push to `main` and confirm the apply job waits for a reviewer before it starts.

If any of those succeed, stop and fix it before you delete a single secret.

## GitHub's 2026 Immutable Subject Claims

On 23 April 2026 GitHub announced immutable subject claims, and since **15 July 2026** they are on automatically for every new repository on github.com — and for every repository that gets renamed or transferred. The subject stops being name-based:

{% highlight text %}
before: repo:contoso/payments-api:environment:production
after:  repo:contoso@1234567/payments-api@821093847:environment:production
{% endhighlight %}

The `@` numbers are the owner ID and the repository ID. This fixes a real problem. A name-based FIC trusts whoever owns the name `contoso/payments-api`, and names get recycled when repos are deleted, renamed or transferred. Microsoft published a page on mutable subjects in FICs this year for exactly that reason. It's the same argument I made for `repository_id` in the GCP post, except that on Azure you can't express it in a condition, so GitHub had to put it in the subject.

Existing repositories keep the old format until they opt in. Once they opt in, there's no going back. This feature isn't on GHES.

Two ways this breaks a working pipeline:

- **Rename or transfer a repo after 15 July 2026** and its subject switches to the immutable format on the next run. Every name-based FIC you had for it stops matching. Nothing in Azure changed; GitHub did. You get `AADSTS700213` with the new subject in the message.
- **The Entra portal now offers optional GitHub owner/repo ID fields** when you create a GitHub FIC, and fills in the immutable subject for you. If that repo hasn't opted in, it's still sending the old format, and the login fails with the same error. The `azure/login` README's troubleshooting section describes exactly this case.

Migration for an existing repo is add, switch, verify, remove — in that order, so there's no window where nothing matches.

First, get the IDs and look at the current template:

{% highlight bash %}
gh api repos/contoso/payments-api --jq '{repo_id: .id, owner_id: .owner.id}'
gh api repos/contoso/payments-api/actions/oidc/customization/sub
{% endhighlight %}

Second, add the immutable-subject FICs *next to* the existing ones. In Terraform that's a second resource per identity:

{% highlight hcl %}
variable "github_owner_id" { type = string } # 1234567
variable "github_repo_id"  { type = string } # 821093847

locals {
  repo_immutable = "${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
}

resource "azurerm_federated_identity_credential" "plan_pr_immutable" {
  name                      = "gh-payments-pr-immutable"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan.id
  audience                  = [local.audience]
  issuer                    = local.issuer
  subject                   = "repo:${local.repo_immutable}:pull_request"
}

resource "azuread_application_federated_identity_credential" "production_immutable" {
  application_id = azuread_application_registration.deploy.id
  display_name   = "gh-${var.github_repo}-env-production-immutable"
  audiences      = [local.audience]
  issuer         = local.issuer
  subject        = "repo:${local.repo_immutable}:environment:production"
}
{% endhighlight %}

Third, opt the repository in:

{% highlight bash %}
gh api -X PUT repos/contoso/payments-api/actions/oidc/customization/sub \
  -F use_default=true \
  -F use_immutable_subject=true
{% endhighlight %}

`use_default` is required on the repository endpoint. I haven't confirmed that `true` together with `use_immutable_subject` is the intended combination for "default claims, immutable format", so check it against the REST reference for the OIDC endpoints before you run it on something that matters. The UI toggle in the repository's Actions settings does the same thing if you'd rather click.

Fourth, run a PR and a deploy, and confirm in the "Federated token details" line that the immutable subject is what's being presented. Only then delete the old name-based FICs. Leaving them behind defeats the point, because the name-based trust is the thing an attacker who claims your old repo name would use.

Each extra FIC counts toward the 20 per identity, which is fine for one repo but adds up fast when one identity serves many repos. If you're doing the org-wide migration, `PUT /orgs/{org}/actions/oidc/customization/sub` with `use_immutable_subject` covers every repo, but I'd do it repo by repo for anything that deploys to production.

If you use a custom subject template (for example `include_claim_keys: ["repo","context","job_workflow_ref"]` to pin the identity to a specific reusable workflow), the owner and repo IDs stay in the `repo` segment and can't be removed. Watch the 600-character subject limit on FICs when `job_workflow_ref` is long.

## Troubleshooting AADSTS700213 and Other OIDC Errors

Almost every failure is the same failure: the `sub` you configured is not the `sub` the job sent. So the first move is always to look at what was sent. `azure/login` logs it, but when you're debugging Terraform alone, drop this step into the job temporarily:

{% highlight yaml %}
- name: Show OIDC claims (debug only, remove after)
  uses: actions/github-script@v7
  with:
    script: |
      const t = await core.getIDToken('api://AzureADTokenExchange');
      const c = JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString());
      const { iss, sub, aud, repository_id, repository_owner_id,
              job_workflow_ref, environment, event_name } = c;
      core.info(JSON.stringify({ iss, sub, aud, repository_id, repository_owner_id,
                                 job_workflow_ref, environment, event_name }, null, 2));
{% endhighlight %}

It prints the claims and never the raw JWT. The token is valid for about fifteen minutes; don't paste it anywhere.

Compare that `sub` character by character with the FIC list (`az ad app federated-credential list --id <app-object-id> -o table` or `az identity federated-credential list -g rg-identities --identity-name id-gh-payments-plan -o table`), then map the error:

| Error | What it means | Usual fix |
|---|---|---|
| `AADSTS70021` | No matching federated identity record for the presented assertion | Brand-new FIC still propagating: wait a few minutes. Otherwise, a general mismatch. |
| `AADSTS700213` | No matching record for the presented assertion **subject** (case-sensitive) | Environment vs branch vs PR mismatch, typo, hyphenated `pull-request`, or the immutable format switch |
| `AADSTS7002138` | Subject matches only if you ignore case | Fix the casing of org, repo or environment name in the FIC |
| `AADSTS700016` | Application not found in the tenant | Wrong `client-id` or `tenant-id` (often the object ID used instead of the client ID) |
| `AADSTS7000215` | Invalid client secret | You're still on the `creds:` / client secret path somewhere |

There are also issuer and audience variants of these errors, typically from a trailing slash on the issuer, a GHE Cloud unique issuer URL, or a custom `audience` input. I haven't confirmed their exact codes and messages, so I'm leaving them out of the table. Sovereign clouds use a different audience (`api://AzureADTokenExchangeUSGov` for US Government).

If `id-token: write` is missing, the failure happens inside the runner when the action asks GitHub for a token. Entra is never called, so there's no AADSTS code at all. Check the job's `permissions` block first.

The sign-in logs tell you the same thing from Entra's side, and they're what you'll use later to prove the secrets are unused. With Entra sign-in logs going to Log Analytics:

{% highlight kusto %}
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(30d)
| summarize count(), lastSeen = max(TimeGenerated)
    by AppId, ServicePrincipalName, ClientCredentialType, FederatedCredentialId, ResultType
| order by ServicePrincipalName asc
{% endhighlight %}

`FederatedCredentialId` is filled in when a FIC was used, which also tells you *which* FIC — handy during the immutable migration. `ClientCredentialType` separates secret, certificate and federated sign-ins, but run `| distinct ClientCredentialType` in your own workspace before writing filters against specific values. For failures only:

{% highlight kusto %}
AADServicePrincipalSignInLogs
| where TimeGenerated > ago(7d)
| where ResultType != "0"
| project TimeGenerated, ServicePrincipalName, ResultType, ResultDescription, FederatedCredentialId
| order by TimeGenerated desc
{% endhighlight %}

UAMI sign-ins are logged as managed identity sign-ins rather than service principal ones, so for the plan identity look in `AADManagedIdentitySignInLogs`. Confirm that in your tenant; I'm going by the Entra documentation here, not a lab run.

## Flexible Federated Identity Credentials (Preview)

Twenty exact strings can get tight: one identity shared by a dozen repos, or "any branch in this repo" for a dev environment. Entra's answer is the flexible FIC, which replaces `subject` with a `claimsMatchingExpression`. **It's in preview** as I write this, so I wouldn't put production write access behind it yet.

For GitHub, the expression has to match on `sub` *and* on at least one of `repository_id` or `repository_owner_id`, so it carries the immutable-ID protection with it. `job_workflow_ref` is also available. On a UAMI it looks like this:

{% highlight bash %}
az identity federated-credential create \
  --name gh-payments-any-branch \
  --identity-name id-gh-payments-dev \
  --resource-group rg-identities \
  --issuer https://token.actions.githubusercontent.com \
  --audiences api://AzureADTokenExchange \
  --cme-version 1 \
  --cme-value "claims['sub'] matches 'repo:contoso/payments-api:ref:refs/heads/*' and claims['repository_id'] eq '821093847'"
{% endhighlight %}

For app registrations it's Graph `beta`, and the azuread provider has had `azuread_application_flexible_federated_identity_credential` since 3.7.0. Two warnings there. The registry example for that resource leaves out `repository_id`, which current Microsoft docs say is mandatory for GitHub, so don't copy it as-is. And the Microsoft page still says there's no Terraform or CLI support — that's out of date. azurerm has no flexible-FIC argument, so for UAMIs you're on the CLI or ARM with the preview API version.

## Where This Can Still Go Wrong

OIDC fixes the stolen-string problem. It doesn't fix bad trust design, and it adds a new thing to protect.

**The pull_request identity is shared by every PR.** Fork PRs don't get `id-token: write` by default, unless an admin has enabled "Send write tokens to workflows from pull requests" in the repository or org Actions settings. Check that it's off. Even with it off, anyone with push access can open a PR from a branch with a modified workflow, which is why that identity gets Reader and nothing else.

**Prefer environment subjects for anything that can write.** Branch subjects trust whatever event lands on the branch. As one example, `pull_request_target` runs in the context of the default branch; I'd expect it to present the `ref:refs/heads/main` subject, so a "main branch" FIC may trust a workflow that checks out PR code. I haven't lab-tested which subject it presents, so verify it in your own setup, but it's one more reason the write identity sits behind an environment.

**Scope roles to the resource group, and never let a pipeline write role assignments freely.** Owner or User Access Administrator on a pipeline identity is a privilege escalation path waiting for one malicious commit. If the pipeline must assign roles, use Role Based Access Control Administrator with conditions that restrict which roles it can hand out. The background is in [Azure RBAC guardrails with Azure Policy](/azure-rbac-guardrails-azure-policy/). One identity per environment, and separate plan and apply identities.

**Whoever can add a FIC can add a backdoor.** Adding a FIC is adding a credential. An attacker with Application Administrator, app ownership or Managed Identity Contributor on a UAMI can point a FIC at a repo they control and get secretless, long-lived access that survives every password reset. Alert on Entra audit events for application credential changes and on ARM writes to `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials`. Check the exact audit operation names in your `AuditLogs` table before you build detections on them.

**Pin your actions.** The same pipeline probably runs [Trivy for container and IaC scanning](/trivy-github-actions-container-iac-scanning/); a compromised third-party action in a job with `id-token: write` can mint a token just like your own step can.

## Removing AZURE_CREDENTIALS and Client Secrets for Good

Migrating the pipelines is half the job. The secret is still valid until you delete it, and Entra will let someone create a new one tomorrow. Same lesson as the [leaked AWS access keys](/leaked-aws-access-keys-detect-remediate/) post: rotation schedules don't save you, removing the credential type does.

Start with an inventory. Azure Resource Graph doesn't index app registrations, so this goes through Graph:

{% highlight bash %}
# App registrations with client secrets (values are never returned, only metadata)
az ad app list --all \
  --query "[?length(passwordCredentials) > \`0\`].{name:displayName, appId:appId, secrets:passwordCredentials[].{keyId:keyId, hint:hint, expires:endDateTime}}" \
  -o json > apps-with-secrets.json

# Secrets on service principals, the ones people forget
az ad sp list --all \
  --query "[?length(passwordCredentials) > \`0\`].{name:displayName, appId:appId}" -o table
{% endhighlight %}

Cross-reference that with the first KQL query. Any app that still shows secret-based sign-ins in the last 30 days has a pipeline (or a person) you haven't migrated yet. When an app shows only federated sign-ins, delete its secrets:

{% highlight bash %}
APP_ID="<client id>"
az ad app credential list --id "$APP_ID" -o table
az ad app credential delete --id "$APP_ID" --key-id "<keyId>"
az ad app credential list --id "$APP_ID"   # expect []
{% endhighlight %}

Then delete `AZURE_CREDENTIALS` and `ARM_CLIENT_SECRET` from the repo, org and environment secrets in GitHub. A dead secret in GitHub is harmless; a live one you forgot about isn't, and you can't easily tell which is which six months from now.

### Stop new secrets from appearing

The tenant default app management policy can block password credentials on applications:

{% highlight bash %}
az rest --method PATCH \
  --uri https://graph.microsoft.com/v1.0/policies/defaultAppManagementPolicy \
  --headers "Content-Type=application/json" \
  --body '{
    "isEnabled": true,
    "applicationRestrictions": {
      "passwordCredentials": [
        {
          "restrictionType": "passwordAddition",
          "maxLifetime": null,
          "restrictForAppsCreatedAfterDateTime": "2026-11-01T00:00:00Z"
        }
      ]
    }
  }'
{% endhighlight %}

That date controls which apps the rule covers: apps *created after* it. I start with a future date so new apps are covered immediately and existing ones keep working, then move the date back once the inventory is clean. Exceptions go into a per-app `appManagementPolicy` rather than weakening the default. You need Application Administrator or Cloud Application Administrator to change it.

Two caveats. The policy blocks create and update operations that violate it; **it does not stop existing secrets from issuing tokens.** It only prevents new ones. Deleting the existing ones is still your job. And app management policies have historically required Microsoft Entra Workload ID Premium licensing. Check the current requirement for your tenant before you count on it.

On the UAMI side, there's no secret to block, but FIC creation is an ARM operation, so Azure Policy can control it. The base rule from Microsoft's considerations doc denies FICs on UAMIs outright:

{% highlight json %}
{
  "if": {
    "field": "type",
    "equals": "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials"
  },
  "then": {
    "effect": "deny"
  }
}
{% endhighlight %}

Assign it broadly and exempt the resource group where your bootstrap Terraform manages pipeline identities. If you'd rather allow FICs but only for your GitHub org, check which aliases exist for the issuer and subject fields first (`az provider show --namespace Microsoft.ManagedIdentity --expand "resourceTypes/aliases"`) and build the condition on those.

## Wrapping Up

The `payments-api` repo now has no Azure secret in GitHub. Pull requests plan with a UAMI that can read the resource group and the state blob. Applies run as an app registration that GitHub only issues a matching token for after a reviewer approves the `production` environment. The FICs use immutable subjects, the old client secret is deleted, the tenant policy blocks new ones, and the sign-in logs show only federated sign-ins.

If you have dozens of repos, start with the KQL inventory rather than the Terraform. It shows which identities still use secrets, which are already federated, and which haven't signed in for months and can just be deleted.

Happy scripting!
