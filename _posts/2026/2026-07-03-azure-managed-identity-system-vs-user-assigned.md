---
title: 'Azure Managed Identity: System-Assigned vs User-Assigned'
author: Victor Silva
date: 2026-07-03T17:05:17+00:00
layout: post
permalink: /azure-managed-identity-system-vs-user-assigned/
excerpt: "The wrong managed identity choice breaks Key Vault access on every Azure redeploy. Terraform for five real system-assigned vs user-assigned scenarios."
categories:
  - Azure
  - Security
tags:
  - azure
  - managed-identity
  - terraform
  - key-vault
  - rbac
  - security
---

It's 3 AM, the pager is going off, and the new VM your pipeline just deployed can't read the connection string from Key Vault. Nothing changed in the application code. Nothing changed in the Key Vault policy — at least nothing anyone touched on purpose. What happened is simpler and more common than anyone wants to admit: the blue/green deployment destroyed the old VM, and with it, the **system-assigned managed identity** that had the `Key Vault Secrets User` role. Terraform dutifully created a brand-new VM with a brand-new identity — new object ID, zero role assignments — and nobody wired the RBAC grant to run again. The app is up. The app has no permissions. This is not a Key Vault problem, and it's not a Terraform bug. It's a managed identity type mismatch, and it's one of the most common self-inflicted outages in Azure environments that rely on immutable infrastructure.

The choice between system-assigned and user-assigned managed identities looks cosmetic — two options in the same `identity` block, both with `SystemAssigned` or `UserAssigned` as a string. In practice it determines three things that matter a great deal in production: whether access is automatically revoked the instant a resource disappears, whether one identity can be shared across a fleet without duplicating RBAC work, and whether your role assignments survive infrastructure being torn down and rebuilt. Most teams pick whichever type the Terraform module they copied from a blog post happened to use, without ever making the trade-off explicit. This post is about making it explicit, with five real decision scenarios, working Terraform for each, and the governance work that keeps user-assigned identities from turning into unmonitored attack surface.

## System-Assigned vs User-Assigned: What Each Type Actually Is

A managed identity is a special kind of service principal in Entra ID where Azure — not you — owns the entire credential lifecycle: creation, silent rotation roughly every 46 days, and (for one of the two types) deletion. There is never a secret or certificate for you to store, rotate, or leak.

**System-assigned** identity is a property of the resource itself. When you enable it on a VM, Azure creates a service principal that is permanently tied to that VM's lifecycle — one identity, one resource, and when the resource is deleted, the identity is deleted automatically and immediately.

**User-assigned** identity is a standalone Azure resource (`Microsoft.ManagedIdentity/userAssignedIdentities`) with its own independent lifecycle. You create it once, attach it to as many VMs, VMSS instances, or Functions as you want, and it keeps existing — with all of its role assignments intact — until someone explicitly deletes it.

That one sentence — "keeps existing until someone explicitly deletes it" — is the whole ballgame. It's simultaneously the feature that saves you during immutable infrastructure deployments and the feature that causes identity sprawl if nobody owns cleanup. Let's work through when each behavior is exactly what you want.

## How Token Acquisition Works (Just Enough to Reason About It)

Both identity types use the same mechanism at runtime, which matters for the security callout later: code running on the VM requests a token from the **Azure Instance Metadata Service (IMDS)** at `http://169.254.169.254/metadata/identity/oauth2/token`, passing a `resource` query parameter (the audience it wants a token for, e.g. `https://vault.azure.net`) and a `Metadata: true` header.

169.254.169.254 is a non-routable link-local address reachable only from inside the VM or its hypervisor — it's not exposed on any network path an external attacker can reach directly. But note what IMDS does *not* do: it doesn't authenticate the caller beyond checking that header is present. It's a minimal SSRF guard, not an identity check. Anything running on the VM — including code executing through a server-side request forgery vulnerability in a web app — can request a token with the VM's full set of permissions. Keep that in your back pocket; it comes back in the gotchas section.

## Decision Scenario 1: The Single VM With One Job

**Situation**: a single VM needs read access to one secret in one Key Vault. It's not part of a fleet, it's not going to be cloned, and when it's decommissioned, you want its access gone with it — no exceptions, no follow-up ticket.

**Decision: system-assigned.** There's no sharing requirement, so the 1:1 lifecycle binding is a feature, not a limitation. You get automatic cleanup for free, and there's no separate identity resource to track, tag, or eventually forget about.

{% highlight hcl %}
resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-app-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  # networking/os fields omitted for brevity

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.app.identity[0].principal_id
}
{% endhighlight %}

Notice the dependency direction: `azurerm_role_assignment.kv_secrets_user` reads `principal_id` off the VM's identity block, so Terraform implicitly orders the role assignment after the VM (and its identity) is created. You cannot grant this role before the identity exists — there's nothing to grant it to. This is exactly the ordering that becomes a liability in scenario 3.

## Decision Scenario 2: A Fleet That All Needs the Same Access

**Situation**: you have a VM Scale Set — or a handful of individually managed VMs — that all need identical read access to the same Key Vault and the same storage account. Today it's four instances. Next sprint it might be twelve.

**Decision: user-assigned.** Create the identity once, grant the roles once, and attach the *same* identity object to every instance. RBAC is defined a single time regardless of fleet size.

{% highlight hcl %}
resource "azurerm_user_assigned_identity" "fleet_identity" {
  name                = "id-fleet-keyvault-reader"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_role_assignment" "fleet_kv_access" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.fleet_identity.principal_id
}

resource "azurerm_linux_virtual_machine_scale_set" "app_fleet" {
  name                = "vmss-app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  # sku, instances, os fields omitted

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.fleet_identity.id]
  }
}
{% endhighlight %}

The scaling math is worth spelling out because it's the whole argument for this scenario. If four VMs each need access to two resources (say, a Key Vault and a storage account) and each has its own system-assigned identity, you're maintaining **eight separate role assignments** — two per VM, times four VMs — and that number keeps growing every time you add an instance. With one shared user-assigned identity, it's **two role assignments, period**. Adding VM #5 to the fleet means attaching an existing identity ID to a new resource — zero new RBAC operations. That's the difference between a five-minute scale-out and a change request that touches your Key Vault access policies again.

## Decision Scenario 3: Immutable Infrastructure and Blue/Green Deploys

This is the scenario from the opening paragraph, and it's the one I'd call the core value-add of understanding this distinction at all.

**Situation**: VMs are built by Packer, deployed via blue/green Terraform, and destroyed/recreated on every release. RBAC grants must survive the VM being replaced — the whole point of immutable infrastructure is that the *infrastructure* is disposable, but the *access model* around it shouldn't be.

**Decision: user-assigned, defined in a separate, rarely-touched module or state file from the VM itself.**

Here's what goes wrong with system-assigned identities in this pattern, concretely: every time `terraform apply` destroys `vm_v1` and creates `vm_v2`, the *old* identity is deleted along with the old VM (correct and desired), but the *new* VM gets a brand-new identity with a brand-new object ID and **zero role assignments** — because Terraform has no way to know "this new identity should inherit the old one's grants" unless you explicitly re-run the role assignment against the new principal ID, in the same apply, every single time. If that role assignment lives in the same module and references the VM's identity output correctly, it *should* get recreated too — but in practice, this is exactly the kind of thing that breaks silently: a refactor, a module boundary that separates VM lifecycle from RBAC lifecycle, a partial apply, or a teammate who didn't realize the coupling existed. The failure mode is real and it's common enough that "new VM, same role, no access" is a recognizable incident pattern in any team running frequent blue/green deploys.

Decoupling the identity from the VM's lifecycle entirely removes the failure mode:

{% highlight hcl %}
# Identity + role assignment live in a separate, rarely-touched
# state/module from the VM definition, so terraform destroy/recreate
# of the VM never touches the identity or its RBAC grants.
resource "azurerm_user_assigned_identity" "immutable_app_identity" {
  name                = "id-blue-green-app"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
}

resource "azurerm_role_assignment" "app_storage_access" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.immutable_app_identity.principal_id
}

# In the ephemeral/blue-green VM module, only a reference is passed in:
variable "app_identity_id" {
  type = string
}

resource "azurerm_linux_virtual_machine" "app_v2" {
  # new image built by Packer, replaces app_v1
  identity {
    type         = "UserAssigned"
    identity_ids = [var.app_identity_id]
  }
}
{% endhighlight %}

The VM module never creates or destroys the identity — it only receives an ID as an input variable. `terraform destroy` on the VM module touches exactly the VM. The identity, and every role assignment attached to it, is completely untouched by that operation, in a [separate Terraform state file](/terraform-remote-state-azure-blob-storage/) that nobody applies as part of the routine deploy pipeline. This is the pattern I now default to for anything built with Packer + blue/green Terraform, and it's saved me from re-litigating "why does the new instance have no Key Vault access" more than once.

## Decision Scenario 4: The Compliance Requirement for Automatic Revocation

**Situation**: a security or compliance requirement states, in some form, that when a VM is decommissioned, its access to sensitive resources must be revoked automatically — without depending on a human remembering to also delete a role assignment or an orphaned identity as a separate manual step.

**Decision: system-assigned is the safer default here, specifically for blast-radius reduction.** This is the flip side of scenario 3 — where persistence across VM recreation was the goal, here *guaranteed non-persistence* is the goal. Deleting the VM deletes the identity and, as a direct consequence, invalidates every role assignment that pointed at that identity's principal ID (the assignment becomes orphaned metadata pointing at a principal that no longer resolves, and Entra ID / Azure RBAC will no longer issue tokens for it). There's no decommissioning runbook step to forget, because there's no separate resource to decommission.

If your environment has an auditor asking "show me that access is revoked within X minutes of a VM being deleted," system-assigned identities give you a mechanism you can point to directly rather than a process you have to prove people followed. If the requirement extends beyond a single VM to fleet-wide guardrails, pair this with [enforcing RBAC guardrails through Azure Policy](/azure-rbac-guardrails-azure-policy/) so the same revocation guarantee is checked continuously, not just at deploy time.

## Decision Scenario 5: The Anti-Pattern — Identity Sprawl

**Situation**: over eighteen months, your team has created a user-assigned identity per environment, per feature team, and occasionally per one-off script — "just to be safe," or because someone copied scenario 2's pattern without the fleet to justify it. Nobody owns a decommissioning process. Some of these identities are attached to nothing.

**Decision: this isn't a scenario with a right answer — it's the failure mode both of the other user-assigned scenarios can degrade into if you don't pair them with governance.** The CIS Azure Foundations Benchmark and the Azure Security Benchmark both recommend managed identities over manually created service principals with client secrets, specifically to eliminate stored credentials as an attack vector. That guidance is correct, but it quietly assumes someone is also managing the *identity's* lifecycle. A user-assigned identity with `Key Vault Administrator` at subscription scope, attached to nothing, sitting unmonitored for a year, is arguably worse than the stored secret it replaced — a leaked secret at least has a rotation and expiry story; an orphaned identity with a standing high-privilege role assignment can persist indefinitely with nobody looking at it until an audit or an incident surfaces it.

This is exactly why the next section exists as its own topic, not an afterthought. At scale, it's also worth [grouping and assigning the underlying policies with Terraform](/azure-policy-initiatives-at-scale/) rather than provisioning identities ad hoc per team.

## CLI Equivalents for Ad-Hoc Work

Terraform is the right tool for anything that should persist and be reviewed, but for quick provisioning or fleet expansion during an incident, the CLI equivalents are worth having memorized.

{% highlight bash %}
# System-assigned: enable + grant in one step
az vm identity assign -g myRG -n myVM
PRINCIPAL_ID=$(az vm show -g myRG -n myVM --query identity.principalId -o tsv)
az role assignment create --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" \
  --scope $(az keyvault show -n myKV --query id -o tsv)

# User-assigned: create once, attach to many VMs
az identity create -g myRG -n id-fleet-reader
IDENTITY_ID=$(az identity show -g myRG -n id-fleet-reader --query id -o tsv)
az vm identity assign -g myRG -n vm1 --identities $IDENTITY_ID
az vm identity assign -g myRG -n vm2 --identities $IDENTITY_ID

# Audit: what is this user-assigned identity actually attached to?
az identity list-resources --name id-fleet-reader -g myRG -o table
{% endhighlight %}

That last command is the one most teams never run until an audit forces the question — which brings us to governance.

## Governance and Audit: Finding the Orphans Before Someone Else Does

Here's an uncomfortable fact worth stating plainly: **Azure Resource Graph does not expose role assignments directly.** There is no pure ARG query that answers "show me every orphaned role assignment across my tenant." Resource Graph is an inventory tool — it knows what exists — but role assignment usage has to be cross-referenced separately with `az role assignment list` and `az identity list-resources`.

Start with inventory:

{% highlight sql %}
// Resource Graph: inventory of all user-assigned identities and their tags/age
Resources
| where type =~ 'Microsoft.ManagedIdentity/userAssignedIdentities'
| project name, resourceGroup, subscriptionId, location, tags, id
{% endhighlight %}

Then cross-check each one against live attachments and active role assignments:

{% highlight bash %}
# For each identity, check live attachments
for id in $(az identity list --query "[].name" -o tsv); do
  count=$(az identity list-resources --name "$id" -g <rg> --query "length(@)")
  echo "$id -> $count attached resources"
done

# Cross-check with role assignments held by the identity's principalId
az role assignment list --assignee <principalId> --all -o table
{% endhighlight %}

The rule I apply: **any identity with zero attached resources but one or more active role assignments is a candidate for deletion, reviewed on a fixed cadence** — monthly for most environments, weekly if the identity graph is large or the org has had sprawl problems before. Don't delete on sight; an identity might be intentionally provisioned ahead of a deployment. But it should never sit in that state indefinitely without someone's eyes on it. Bake this loop — inventory via Resource Graph, cross-reference via CLI, flag zero-attachment-with-active-RBAC — into a scheduled runbook or a scripted report, not a one-time cleanup exercise you do once after reading a blog post like this one. If you'd rather not run it by hand, this is close to the exact detection loop I wired into a [compliance-as-code agent](/compliance-as-code-agent/).

## Testing and Validation

Before you trust either identity type in production, verify token acquisition actually works from inside the VM:

{% highlight bash %}
# Confirm token acquisition works from inside the VM
curl -s -H "Metadata: true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" | jq .
{% endhighlight %}

You should get back JSON containing `access_token`, `expires_on`, and a `resource` field matching the audience you requested. If you get a 403 when calling the target service (Key Vault, Storage, whatever) shortly after creating a fresh role assignment, don't assume it's misconfigured — RBAC propagation can take up to roughly 10 minutes, and it's a far more likely explanation than a bad role definition or scope. Wait, retry, and only start debugging the assignment itself if it's still failing well past that window.

It's also worth directly confirming the lifecycle behavior each type promises, rather than taking it on faith:

{% highlight bash %}
# After deleting a VM with a system-assigned identity, the principal should be gone immediately
az vm delete -g myRG -n myVM --yes
az ad sp show --id <principalId>
# Expect: "not found" — the identity was deleted along with the VM

# A user-assigned identity's principal persists even after every VM
# that referenced it has been deleted
az vm delete -g myRG -n vm1 --yes
az vm delete -g myRG -n vm2 --yes
az ad sp show --id <userAssignedPrincipalId>
# Expect: still resolves — it must be deleted explicitly with `az identity delete`
{% endhighlight %}

Running this once in a sandbox subscription is a cheap way to build real confidence in the lifecycle guarantees this whole post is built around, instead of trusting documentation you read once.

## Gotchas: Before You Ship This

A short list of things that will bite you in production if you don't account for them up front, regardless of which identity type you choose:

- **Propagation delay vs. token caching are two different problems that look identical.** A fresh role assignment can take up to ~10 minutes to propagate through Azure RBAC. Separately, the managed identity token cache backing IMDS holds tokens per resource URI for up to ~24 hours. If a token was cached *before* you fixed a permissions problem, the app may keep failing with a stale "no access" error long after the RBAC fix landed, because it's reusing an old token rather than requesting a new one. Add retry/backoff around first token acquisition in bootstrap scripts, and don't assume a fix "didn't work" without checking whether you're looking at a cached failure.
- **No cross-tenant support, full stop.** Managed identities — system- or user-assigned — do not work across Entra ID tenants. If your architecture involves cross-tenant access (multi-tenant SaaS, acquired subsidiaries in separate tenants), you need a different mechanism entirely; don't design around managed identities for that path.
- **There's no documented hard cap on user-assigned identities per VM** — only tenant/subscription-level rate limits on create and assignment operations (roughly 80 create ops per 20 seconds per subscription/region, 400 per tenant/region; 300 assignment ops per 20 seconds per subscription/region, 400 per tenant/region). If you're doing extreme fan-out — hundreds of identities attached to a single resource — that's a conversation to have with Azure support ahead of time, not a number to guess at.
- **IMDS is an SSRF target, not just a convenience endpoint.** Any SSRF vulnerability in an application running on the VM can be used to pull the managed identity's token and act with its full privileges. This is an argument for minimal scope regardless of identity type — the blast radius of an SSRF bug is exactly the blast radius of whatever role you assigned.
- **A managed identity is only as safe as the role you gave it.** Assigning `Contributor` or `Key Vault Administrator` at subscription scope to a managed identity defeats the entire purpose of this exercise — the identity mechanism removes the stored-secret risk, but it does nothing to enforce least privilege on its own. Always scope role assignments to the narrowest role, at the narrowest resource, that the workload actually needs. Writing [custom Checkov policies for Azure Terraform resources](/checkov-custom-policies-azure-terraform/) is a cheap way to catch overly broad `azurerm_role_assignment` scopes in CI, before they ever reach `apply`.

## Wrapping Up

The system-assigned vs. user-assigned decision isn't about which one is "better" — it's about matching the identity's lifecycle to the lifecycle of the access you're trying to control. Single VM, one job, automatic cleanup on decommission: system-assigned. Shared fleet or infrastructure that gets destroyed and rebuilt on every deploy: user-assigned, decoupled into its own module. Either way, the identity mechanism only removes the *stored-secret* risk — it's still on you to scope roles narrowly and to actually audit user-assigned identities on a schedule, or you'll trade "leaked secret" for "orphaned high-privilege identity nobody's looked at in a year," which is not the upgrade it looks like on paper.

Go pick one production VM or scale set in your environment right now, run `az identity list-resources` or check its `identity` block, and confirm the type actually matches the lifecycle you need. It's a five-minute check that either confirms you're fine or catches the next 3 AM page before it happens.

Happy scripting!
