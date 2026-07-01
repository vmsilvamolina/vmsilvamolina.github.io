---
title: "Azure Policy initiatives: grouping and assigning at scale with Terraform"
author: Victor Silva
date: 2023-11-14T10:15:33+00:00
layout: post
permalink: /azure-policy-initiatives-at-scale/
excerpt: "How to group Azure Policy definitions into initiatives, assign them at management group scope, and manage exemptions — all with Terraform and the azurerm provider."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Azure Policy
  - Terraform
  - IaC
  - Compliance
  - Security
---

Individual Azure Policy definitions are useful. Thirty individual policy assignments are an administrative nightmare. Thirty separate compliance reports, thirty assignment histories, thirty places to look when an auditor asks you to prove a control is in place, thirty resources to update when scope needs to change. If you have ever tried to explain the governance posture of a multi-subscription Azure estate to someone outside the team using per-policy compliance reports, you already know the problem.

Policy initiatives solve this by bundling related policy definitions into a single unit — called a policy set definition in the Azure API — with a single assignment. You get one compliance score, one assignment resource to manage, and one place to grant exemptions when a legitimate exception exists. The Azure portal calls this an "initiative", Terraform calls the resource `azurerm_policy_set_definition`, and the ARM API calls it `policySetDefinitions`. All three refer to the same thing.

This post walks through the full workflow with Terraform and the `azurerm` provider ~> 3.75: referencing a built-in initiative, building a custom one, assigning it at management group scope, and managing exemptions with expiration dates so they do not become permanent technical debt.

## Individual Policy vs. Initiative — When to Use Each

Before getting into the implementation, it is worth being explicit about when an initiative actually helps versus when it adds unnecessary layers.

A single policy assignment at subscription scope works fine when you have one rule, one scope, and you only need to track that one control. The compliance dashboard entry is clean, the assignment is self-contained, and there is nothing to group.

An initiative is the right structure when you have three or more related policies that you want to report on together, when you need to measure compliance against an external standard (CIS, NIST, a custom organizational baseline), or when you want to grant exemptions at the group level rather than policy by policy. Assigning thirty policies individually means thirty assignment resources in Terraform, thirty compliance entries in the portal, and thirty places to update if the management group hierarchy changes. An initiative consolidates all of that.

The compliance reporting difference is the most practical argument. An initiative assignment produces a single compliance percentage that rolls up across all member policies. That number is what you put in a governance dashboard or hand to a compliance team. Thirty individual policy compliance scores require someone to manually aggregate them — and nobody does that consistently.

## Using a Built-in Initiative

The fastest path to initiative-based compliance is assigning one of Azure's built-in policy set definitions. Microsoft maintains initiatives for CIS Microsoft Azure Foundations Benchmark, NIST SP 800-53 Rev 5, Azure Security Benchmark, and several others. These come with all the policy definitions pre-wired and parameters already defined — you just reference the initiative and assign it.

{% highlight hcl %}
# Reference a built-in initiative by display name
data "azurerm_policy_set_definition" "cis_benchmark" {
  display_name = "CIS Microsoft Azure Foundations Benchmark v2.0.0"
}

# Assign at management group scope
resource "azurerm_management_group_policy_assignment" "cis_assignment" {
  name                 = "cis-benchmark-mg"
  display_name         = "CIS Azure Benchmark v2.0.0"
  policy_definition_id = data.azurerm_policy_set_definition.cis_benchmark.id
  management_group_id  = var.management_group_id
  description          = "CIS Microsoft Azure Foundations Benchmark assigned at root management group"
  enforce              = false
}
{% endhighlight %}

`enforce = false` is important here. It sets the assignment to audit-only mode — non-compliant resources are reported but operations are not blocked. For a built-in benchmark initiative on a running environment, starting in audit mode lets you baseline what is already non-compliant before any enforcement changes take effect. Flipping to `enforce = true` on a production estate without a prior audit period is a fast path to breaking legitimate workloads.

The `management_group_id` variable should reference your root management group or the highest-level group that covers all target subscriptions. Any subscription under that management group inherits the assignment automatically — no per-subscription configuration needed.

## Building a Custom Initiative

Built-in initiatives are the right starting point for external compliance standards, but for organizational baselines — your own set of rules that every subscription must meet regardless of which standard they are also being measured against — you want a custom initiative that you control.

### Referencing the Member Policy Definitions

Start by pulling in the individual policy definitions you want to bundle. These can be built-in definitions, custom definitions you have already deployed, or a mix of both. In this example we are using four built-in definitions:

{% highlight hcl %}
data "azurerm_policy_definition" "require_tags" {
  display_name = "Require a tag on resources"
}

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition" "storage_https" {
  display_name = "Secure transfer to storage accounts should be enabled"
}

data "azurerm_policy_definition" "sql_auditing" {
  display_name = "Auditing on SQL server should be enabled"
}
{% endhighlight %}

Looking up by `display_name` is readable but has one operational risk: display names are not guaranteed to be unique across tenants, and they can change between provider versions if Microsoft updates a built-in policy. For production use, look up by `name` (the GUID) instead. The GUID is stable and unambiguous. For this post, display names keep the examples clear.

### Creating the Policy Set Definition

Now create the initiative itself with `azurerm_policy_set_definition`:

{% highlight hcl %}
resource "azurerm_policy_set_definition" "baseline_security" {
  name         = "baseline-security-initiative"
  display_name = "Baseline Security Controls"
  description  = "Core security controls applied across all subscriptions"
  policy_type  = "Custom"
  management_group_id = var.management_group_id

  parameters = jsonencode({
    allowedLocations = {
      type = "Array"
      metadata = {
        displayName = "Allowed locations"
        description = "Regions where resources can be deployed"
      }
    }
  })

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.require_tags.id
    reference_id         = "require-env-tag"
    parameter_values = jsonencode({
      tagName = { value = "environment" }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
    reference_id         = "allowed-locations"
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.storage_https.id
    reference_id         = "storage-https-only"
  }

  policy_definition_reference {
    policy_definition_id = data.azurerm_policy_definition.sql_auditing.id
    reference_id         = "sql-auditing-enabled"
  }
}
{% endhighlight %}

A few things worth understanding here.

The `management_group_id` on the resource definition controls where the policy set definition itself lives in the hierarchy. A custom initiative must be defined at or above the scope where it will be assigned — you cannot assign an initiative from a child management group to a parent. If you are assigning at the root management group, define the initiative there.

The `reference_id` in each `policy_definition_reference` block is the string you use later when granting exemptions to a specific policy within the initiative. Choose descriptive, stable identifiers. These reference IDs show up in exemption resources and in the compliance API, and renaming them after deployment creates drift.

The `parameters` block at the initiative level defines parameters that can be filled in at assignment time. The `allowedLocations` parameter is intentionally left open — its value will be provided when you create the assignment, which means the same initiative definition can be assigned with different region lists to different management groups.

The `listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }` expression in the `allowed-locations` reference block is the ARM template expression syntax that passes the initiative-level parameter down to the individual policy at evaluation time. This is a common confusion point and it is worth being precise: the initiative parameter and the policy parameter are separate things. The initiative parameter is the one callers set at assignment time; the policy parameter is what the individual policy definition consumes. The `[parameters('allowedLocations')]` expression is the bridge between them.

## Assigning the Custom Initiative at Management Group Scope

With the initiative defined, assign it using `azurerm_management_group_policy_assignment`:

{% highlight hcl %}
resource "azurerm_management_group_policy_assignment" "baseline_assignment" {
  name                 = "baseline-security"
  display_name         = "Baseline Security Controls"
  policy_definition_id = azurerm_policy_set_definition.baseline_security.id
  management_group_id  = var.management_group_id
  enforce              = true

  parameters = jsonencode({
    allowedLocations = {
      value = ["eastus", "eastus2", "westeurope"]
    }
  })

  non_compliance_message {
    content = "This resource does not comply with the baseline security initiative. Refer to the security runbook for remediation steps."
  }
}
{% endhighlight %}

The `non_compliance_message` is underused in most Terraform configurations but genuinely valuable for operators. When a `Deny` effect policy blocks an operation, the message in the HTTP 403 response body includes this text. Engineers get a clear explanation of why their deployment failed and where to look for remediation steps, rather than an opaque policy ID string that requires a portal lookup.

The `parameters` block here provides the value for the `allowedLocations` initiative parameter we defined earlier. If you are assigning the same initiative to multiple management groups with different region sets, each assignment gets its own `parameters` block. The initiative definition stays unchanged — only the assignment differs. This is the operational advantage of leaving parameters open at the initiative level.

## Managing Exemptions

Exemptions are how you handle legitimate exceptions without removing the policy assignment or weakening its scope. An exemption applies at a specific resource scope and can target the entire initiative or specific policies within it.

{% highlight hcl %}
resource "azurerm_resource_group_policy_exemption" "legacy_app_exemption" {
  name                 = "legacy-app-storage-exemption"
  resource_group_id    = azurerm_resource_group.legacy_app.id
  policy_assignment_id = azurerm_management_group_policy_assignment.baseline_assignment.id
  exemption_category   = "Waiver"
  display_name         = "Legacy app storage - HTTPS upgrade in Q1 2024"
  description          = "Storage account requires HTTP for legacy integration. Tracked in ticket #12345. Expires Q1 2024."
  expires_on           = "2024-03-31T00:00:00Z"

  policy_definition_reference_ids = [
    "storage-https-only"
  ]
}
{% endhighlight %}

The `exemption_category` has two valid values: `Waiver` and `Mitigated`. A `Waiver` means the organization accepts the risk — the control does not apply here, or the cost of applying it outweighs the benefit in this specific case. A `Mitigated` exemption means the risk is addressed through a compensating control that is not captured by the policy rule itself — for example, the storage account is not accessible from the public internet so the HTTPS enforcement is redundant in context.

The `expires_on` date is the most important field from a governance standpoint. Exemptions without expiration dates accumulate silently. Within six months of deploying a policy initiative, most environments have a small collection of "temporary" exemptions that have quietly become permanent. Setting `expires_on` puts an expiration in the resource itself — when the date passes, the Azure compliance engine resumes evaluating the resource against the exempted policies, and it will show up as non-compliant again. That surfaces the technical debt and forces a conscious decision: either remediate the root cause or renew the exemption with an updated justification.

The `policy_definition_reference_ids` list lets you exempt the resource group from a specific policy within the initiative rather than the entire initiative. In this case, only the `storage-https-only` policy is waived. The resource group is still evaluated against `require-env-tag`, `allowed-locations`, and `sql-auditing-enabled`. Scoping exemptions this tightly keeps the compliance surface accurate and avoids unintentional gaps.

## Checking Compliance with Azure CLI

After deploying the initiative and assignment, trigger a compliance evaluation and inspect the results:

{% highlight bash %}
# Get compliance summary for the initiative at management group scope
az policy state summarize \
    --management-group $MANAGEMENT_GROUP_ID \
    --policy-assignment baseline-security \
    --query "{compliant: results.compliantResources, nonCompliant: results.nonCompliantResources}"
{% endhighlight %}

The summarize command returns aggregate counts. For a detailed view of which specific resources are non-compliant:

{% highlight bash %}
# List non-compliant resources with policy context
az policy state list \
    --management-group $MANAGEMENT_GROUP_ID \
    --filter "complianceState eq 'NonCompliant' and policyAssignmentName eq 'baseline-security'" \
    --query '[].{Resource:resourceId, Policy:policyDefinitionName, State:complianceState}' \
    --output table
{% endhighlight %}

The `policyDefinitionName` column in the output identifies which policy within the initiative flagged each resource. This is how you map a non-compliant resource back to the specific control it violates — useful both for remediation work and for exemption scoping.

Compliance state is not evaluated instantly after assignment. A full scan across a large management group can take up to 30 minutes. If you need results faster during testing, trigger a manual scan:

{% highlight bash %}
# Trigger an on-demand compliance scan
az policy state trigger-scan \
    --management-group $MANAGEMENT_GROUP_ID
{% endhighlight %}

This kicks off a background job. You can re-run the summarize query after a few minutes to see updated results.

## Initiative vs. Assignment Parameters — A Common Confusion Point

Parameters defined in an initiative can be either hardcoded at initiative creation or left open for callers to fill at assignment time. The decision matters for how you reuse the initiative.

If a parameter value is universal — it will be the same for every assignment of this initiative regardless of scope — hardcode it in the `policy_definition_reference` block. There is no reason to surface it to assignment callers if the value never changes.

If a parameter value varies per assignment — different allowed regions per management group, different tag names per business unit — leave it open as an initiative-level parameter. Assignment callers provide the value. The same initiative definition can then be assigned a dozen times with different parameter values, with no changes to the definition itself.

The worst outcome is accidentally hardcoding a value that should vary and then having to update the initiative definition every time scope changes. Treat initiative-level parameters the same way you would treat Terraform module input variables: expose what is genuinely variable, hardcode what is constant.

## Structuring Initiatives for Scale

A few organizational patterns that hold up well as the number of policies and subscriptions grows.

**One initiative per compliance domain.** Group policies by the control domain they address — network security, identity, data protection, logging and monitoring — rather than by resource type or policy effect. When an auditor asks about your data protection controls, you can point to a single initiative assignment and its compliance score. When they ask about network controls, same thing. The grouping reflects how compliance requirements are actually organized, which makes the mapping from control requirement to policy implementation direct.

**Assign at the highest applicable scope.** Management group assignment covers every subscription and resource group underneath it automatically. A policy that should apply everywhere belongs at the root management group. A policy that only makes sense for production workloads belongs at the management group that contains production subscriptions. Resist the temptation to assign the same initiative at multiple scopes to cover gaps — that creates redundant evaluations and conflicting compliance scores. Fix the hierarchy first.

**Use `enforce = false` for the first two weeks.** After any significant policy rollout, audit mode gives you a baseline of existing violations without blocking in-flight deployments. Engineers can continue deploying while you identify and remediate violations. Switch to `enforce = true` only after the compliance score is at or near 100% for the control domains you are actively enforcing. For audit-only controls — "Audit" effect policies, or policies you plan to report on but never enforce — leave `enforce = true` on the assignment (the audit effect does not block) but keep the policy effect set to `Audit` in the definition.

**`DeployIfNotExists` policies need a managed identity.** If any member policy in your initiative uses the `DeployIfNotExists` or `Modify` effect, the policy assignment needs a system-assigned managed identity with the permissions required to remediate non-compliant resources. Add a `identity` block to the assignment and grant the identity the appropriate roles using `azurerm_role_assignment`. Missing this step means the remediation tasks will fail silently — the compliance dashboard will show non-compliant resources but no automatic remediation will happen.

## Conclusion

Policy initiatives turn a collection of individual rules into a governable unit. One assignment covers all subscriptions under the management group, produces a single compliance score, and gives you a single surface for exemption management. When the compliance score is 98%, you know exactly where to look. When an auditor asks for evidence of your data protection controls, you have a dashboard entry that maps directly to the control domain rather than a spreadsheet of individual policy assignments.

The combination here — custom initiative at management group scope, parameters left open at the initiative level for per-assignment variation, and time-bounded exemptions — scales from a handful of subscriptions to hundreds without requiring per-subscription configuration. Every piece of this lives in Terraform: the initiative definition, the assignment, and the exemptions all go through version control and get reviewed in pull requests the same way any other infrastructure change does. That audit trail is itself part of the compliance evidence.

From here, look at deploying a built-in initiative like NIST SP 800-53 Rev 5 alongside your custom baseline — the two assignments complement each other and the compliance scores are tracked separately in the portal. If you are also using [Azure Policy's deny effect to block RBAC assignments at subscription scope](/azure-rbac-guardrails-azure-policy/), both the deny policy and the initiative assignment can coexist in the same Terraform configuration without conflict.

Happy scripting!
