---
title: 'Enforcing Azure RBAC Guardrails with Azure Policy'
author: Victor Silva
date: 2024-01-15T10:00:00+00:00
layout: post
permalink: /azure-rbac-guardrails-azure-policy/
excerpt: "Over-permissive role assignments are one of the most common misconfigurations in Azure. Azure Policy's deny effect lets you block Owner and Contributor assignments at subscription scope before they are created — not just flag them after the fact. This post walks through building the guardrail with Terraform."
categories:
  - Azure
  - Security
tags:
  - Azure Policy
  - RBAC
  - Terraform
  - Security
  - Governance
---

You open the Access Control (IAM) blade on a subscription that has been running for two years and you start scrolling. There is a contractor from a project that ended in Q2. Three service principals with Owner "just in case we need it." A break-glass account that got used once during an incident and never got scoped back down. A developer who asked for Contributor to debug something six months ago. Nobody removed any of it because removing role assignments feels risky and adding them feels urgent, so the list only ever grows.

Azure RBAC has no built-in mechanism to prevent this at creation time. The portal, the CLI, and the API all let you assign Owner at subscription scope without friction, as long as the caller has User Access Administrator rights. Periodic access reviews help, but they detect violations after they exist. If you want to stop a bad assignment from landing in the first place, you need a deny effect on an Azure Policy.

This post walks through building that guardrail from scratch with Terraform: a custom policy definition that blocks Owner and Contributor assignments at subscription scope, a parameterized effect so you can start in audit mode and flip to deny after baselining, and the validation steps to prove it actually works before you rely on it.

## Why deny and Not audit

Before getting into the implementation, it is worth being precise about what each Azure Policy effect actually does. Teams often start with audit because it feels safer, then forget to switch. The difference matters operationally.

| Effect | Behavior |
|---|---|
| deny | Evaluates at write time. Returns HTTP 403 to the caller. ARM never commits the resource. |
| audit | Allows the write. Marks the resource as non-compliant in the compliance dashboard. |
| auditIfNotExists | Detects the absence of a complementary resource (for example, a missing activity log alert). |
| disabled | Evaluates nothing. Deploy the policy structure without any enforcement - useful for testing the policy definition itself. |

The key nuance for role assignments is that `deny` evaluates `Microsoft.Authorization/roleAssignments` at write time, before ARM persists the object. If the policy evaluates to deny, the assignment is never created. There is no remediation task to run, no stale violation to clean up later. The bad state simply does not exist.

`audit` does the opposite. The assignment is created successfully. A compliance record is written. Someone has to find that record, validate it is a real violation, and remove the assignment manually. That is a workflow problem in addition to a technical one. Audit is useful for baselining - finding out what already exists before you block new additions - but it is not a substitute for deny.

The approach here uses a parameterized effect. You deploy as `audit` first, identify existing violations, remediate them, then flip the parameter to `deny`. This gives you the safety of a gradual rollout without having to touch the policy definition itself.

## Prerequisites

To follow along you will need:

- Azure CLI installed and authenticated to the target subscription (`az login`, `az account set`)
- Terraform 1.3 or later
- The `azurerm` provider 3.x or later (the `azurerm_subscription_policy_assignment` resource was added in 3.x - the older `azurerm_policy_assignment` is deprecated and behaves differently at subscription scope)
- The Owner role or User Access Administrator role on the target subscription - you need both to create the policy definition and to test the deny behavior

## How the Policy Rule Works

The policy targets `Microsoft.Authorization/roleAssignments` and fires when all four conditions are true:

1. The resource type is a role assignment.
2. The `roleDefinitionId` is either Owner (`8e3af657-a8ff-443c-a75c-2fe8c4bcb635`) or Contributor (`b24988ac-6180-42a0-ab88-20f7382dd24c`).
3. The scope of the assignment starts with `/subscriptions/` - meaning it is at subscription scope.
4. The scope does not contain `/resourceGroups/` - meaning resource-group-level Contributor assignments are explicitly allowed through.

That last condition is the practical relief valve. Blocking all Contributor assignments would break most real workloads. The risk you are targeting is the subscription-wide assignment that gives someone broad write access to everything. A developer who needs Contributor on a specific resource group to do their job should not be blocked.

The `roleDefinitionId` field is not just the GUID - it is the fully qualified ARM path including the subscription ID. The policy rule handles this with an ARM `concat()` expression that builds the full path at evaluation time, so the same policy definition works across every subscription without modification.

## Implementation

### Part 1 - Custom Policy Definition

Create a file named `policy.tf` in your Terraform working directory:

{% highlight hcl %}
resource "azurerm_policy_definition" "block_owner_contributor_sub_scope" {
  name         = "block-owner-contributor-subscription-scope"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Block Owner and Contributor assignments at subscription scope"
  description  = "Denies role assignments for Owner and Contributor at the subscription root. Resource-group-scoped assignments are unaffected."

  metadata = jsonencode({
    category = "Authorization"
    version  = "1.0.0"
  })

  parameters = jsonencode({
    effect = {
      type         = "String"
      defaultValue = "deny"
      allowedValues = ["audit", "deny", "disabled"]
      metadata = {
        displayName = "Effect"
        description = "Audit or deny Owner/Contributor at subscription scope"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Authorization/roleAssignments"
        },
        {
          field = "Microsoft.Authorization/roleAssignments/roleDefinitionId"
          in = [
            "[concat('/subscriptions/', subscription().subscriptionId, '/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635')]",
            "[concat('/subscriptions/', subscription().subscriptionId, '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c')]"
          ]
        },
        {
          field = "Microsoft.Authorization/roleAssignments/scope"
          like  = "/subscriptions/*"
        },
        {
          not = {
            field    = "Microsoft.Authorization/roleAssignments/scope"
            contains = "/resourceGroups/"
          }
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}
{% endhighlight %}

A few things are worth calling out here. The `mode` is set to `All` rather than `Indexed`. Policy mode controls which resource types are evaluated. `All` includes resource types that do not support tags and location - role assignments fall into this category, so `All` is required. Using `Indexed` here would cause the policy to skip role assignments entirely and evaluate nothing.

The `defaultValue` for the effect parameter is set to `"deny"` in the definition, but when you assign the policy you will override this with `"audit"` during initial rollout. Setting the default to deny means any assignment that does not explicitly set the effect gets the stricter behavior, which is the safer default for a governance policy.

### Part 2 - Policy Assignment at Subscription Scope

Add the following to `policy.tf` or a separate `assignment.tf`:

{% highlight hcl %}
data "azurerm_subscription" "current" {}

resource "azurerm_subscription_policy_assignment" "block_owner_contributor" {
  name                 = "block-owner-contributor-sub"
  display_name         = "Block Owner/Contributor at subscription scope"
  policy_definition_id = azurerm_policy_definition.block_owner_contributor_sub_scope.id
  subscription_id      = data.azurerm_subscription.current.id

  parameters = jsonencode({
    effect = {
      value = "audit"
    }
  })

  enforce = false
}
{% endhighlight %}

Two decisions here that are easy to get confused.

The `parameters` block sets the effect to `"audit"` for the initial rollout. This overrides the definition's default. Once you have reviewed and remediated existing violations, you will change this to `"deny"`.

The `enforce` property maps to Azure Policy's enforcement mode. `enforce = false` is equivalent to setting enforcement mode to `DoNotEnforce` in the portal. In this mode, the policy evaluates and reports compliance but does not actually deny the operation - the deny or audit logic in the `then` block is bypassed entirely. This is different from setting the effect to `"audit"`. With `enforce = false`, nothing is blocked and nothing is flagged as non-compliant. It is purely for testing that your policy rule syntax is valid and the assignment is targeting the right scope.

During a real rollout: start with `enforce = false` to verify the assignment is wired up correctly, switch to `enforce = true` with `effect = "audit"` to baseline violations, remediate, then switch to `effect = "deny"`.

### Part 3 - Audit Custom RBAC Roles with a Built-in Policy

While you are building out RBAC governance, it is worth adding the built-in policy that flags usage of custom role definitions. Custom roles accumulate the same way custom assignments do, and they are harder to review because the scope is not obvious from the name.

{% highlight hcl %}
data "azurerm_policy_definition" "audit_custom_rbac" {
  name = "a451c1ef-c6ca-483d-87ed-f49761e3ffb5"
}

resource "azurerm_subscription_policy_assignment" "audit_custom_roles" {
  name                 = "audit-custom-rbac-roles"
  display_name         = "Audit usage of custom RBAC roles"
  policy_definition_id = data.azurerm_policy_definition.audit_custom_rbac.id
  subscription_id      = data.azurerm_subscription.current.id
  enforce              = true
}
{% endhighlight %}

The built-in policy ID `a451c1ef-c6ca-483d-87ed-f49761e3ffb5` is the "Audit usage of custom RBAC roles" definition that exists in every Azure tenant. Looking it up by name rather than hardcoding the full resource ID keeps the Terraform readable and handles the fact that the resource ID includes the tenant ID.

## Testing and Validation

### Step 1 - Baseline Existing Violations

Before you flip to deny, you need to know what you are dealing with. Assign the policy with `enforce = true` and `effect = "audit"`, then trigger a compliance scan:

{% highlight bash %}
# List all current Owner assignments at subscription scope
az role assignment list \
  --role "Owner" \
  --scope "/subscriptions/$(az account show --query id -o tsv)" \
  -o table

# Trigger a compliance evaluation scan (takes up to 30 minutes to complete)
az policy state trigger-scan \
  --subscription "$(az account show --query id -o tsv)"

# Review compliance results once the scan completes
az policy state list \
  --policy-assignment "block-owner-contributor-sub" \
  --query "[].{resource:resourceId, compliance:complianceState}" \
  -o table
{% endhighlight %}

The scan can take up to 30 minutes. If you need faster feedback during testing, you can query the compliance state immediately after the trigger command but expect incomplete results. For a baseline exercise, wait for the full scan.

Review the output. Every `NonCompliant` resource ID is a role assignment you need to either remove, scope down to a resource group, or justify as a legitimate exception. Do not flip to deny until this list is clean or you understand every entry.

### Step 2 - Switch to Deny and Test

Once you have remediated, update the Terraform to flip both the enforce flag and the effect:

{% highlight hcl %}
parameters = jsonencode({
  effect = {
    value = "deny"
  }
})

enforce = true
{% endhighlight %}

Apply the change, then test with a dedicated test user. If you do not have a test user available, create a throwaway service principal for this:

{% highlight bash %}
TEST_USER_OBJECT_ID="<test-user-object-id>"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# This should fail with RequestDisallowedByPolicy
az role assignment create \
  --role "Owner" \
  --assignee-object-id "$TEST_USER_OBJECT_ID" \
  --assignee-principal-type "User" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
{% endhighlight %}

When the policy is working correctly you will see:

{% highlight bash %}
(RequestDisallowedByPolicy) Resource 'xxxx' was disallowed by policy.
PolicyDefinitionId: .../block-owner-contributor-subscription-scope
Code: RequestDisallowedByPolicy
{% endhighlight %}

The error message includes the policy definition ID, which makes it easy to explain to a developer why their operation failed and which team owns the policy. This is one of the practical advantages of deny over audit - the error is immediate and traceable.

### Step 3 - Verify Resource Group Scope Still Works

Proving what does not break is as important as proving what does. Run the same assignment at resource group scope to confirm the NOT condition in the policy rule is working:

{% highlight bash %}
# This should succeed - resource-group-scoped assignments are allowed
az role assignment create \
  --role "Contributor" \
  --assignee-object-id "$TEST_USER_OBJECT_ID" \
  --assignee-principal-type "User" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-test"
{% endhighlight %}

This should succeed. If it fails with `RequestDisallowedByPolicy`, your NOT condition is not evaluating correctly - check that the `contains "/resourceGroups/"` field path and value are spelled correctly in the policy rule.

## Best Practices

**Never deploy deny cold.** Always start with `enforce = true` and `effect = "audit"`, baseline the violations, remediate them, then switch to deny. A cold deny on a subscription with existing Owner assignments does not remove those assignments - it blocks new ones but leaves the violations in place. Worse, if your CI/CD pipeline has a legitimate need to assign roles and you have not accounted for it, you will break deployments before anyone realizes what happened.

**deny does not remove existing assignments.** This is the most important misconception to address early. The deny effect evaluates on write operations. Assignments that already existed before the policy was assigned in deny mode remain in place. You have to remediate them separately - either remove them, scope them down to a resource group, or move the principal to an eligible assignment in PIM.

**Carve out your automation service principal if needed.** If your CI/CD pipeline needs to assign roles at subscription scope as part of infrastructure provisioning, you have two options. You can add a `not` condition to the policy rule that excludes the service principal's object ID. Alternatively, use `not_scopes` on the policy assignment to exclude a dedicated resource group used only by automation. The `not_scopes` approach is cleaner because it does not require knowing the service principal's object ID at policy authoring time.

**The roleDefinitionId is a fully qualified path, not a GUID.** When Azure stores a role assignment, the `roleDefinitionId` field contains the full ARM path including the subscription ID - something like `/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/providers/Microsoft.Authorization/roleDefinitions/8e3af657-a8ff-443c-a75c-2fe8c4bcb635`. The `concat()` ARM expression in the policy rule constructs this path at evaluation time using `subscription().subscriptionId`. If you hardcode just the GUID, the `in` condition will never match and the policy will never fire.

**Combine with PIM for just-in-time access.** Azure Policy prevents the permanent subscription-scoped assignment from being created. But your operators still need a path to elevated access for emergencies and scheduled maintenance. Privileged Identity Management handles this: engineers are eligible for Owner, not assigned Owner, and they activate the role for a time-bounded session with a justification. Policy prevents the permanent standing assignment, PIM handles the legitimate temporary elevation. These two controls complement each other directly.

**Useful built-in policies to assign alongside.** Once the deny guardrail is in place, consider adding these built-in assignments to your compliance baseline:
- "Accounts with owner permissions should be MFA enabled" (`e3e008c3-...`) - ensures that any Owner assignments that do exist have MFA configured.
- "Guest accounts with owner permissions should be removed" (`339353f6-...`) - flags external identities with subscription-wide write access, which is almost never intentional.
- "Audit usage of custom RBAC roles" (`a451c1ef-...`) - already covered in Part 3 above, but worth calling out explicitly as a companion.

**Review compliance state regularly.** Azure Policy compliance state is evaluated periodically (every 24 hours by default) and on resource writes. If you are relying on audit to detect violations, set up an Azure Monitor alert on the compliance state metric or query it from a scheduled Azure Automation runbook. Compliance data that nobody looks at is not a control.

## Conclusion

The pattern here is simple in concept: use Azure Policy's deny effect to evaluate role assignment writes before ARM commits them, and block the ones that match the scope and role you are trying to prevent. The implementation is a custom policy definition with a parameterized effect, assigned at subscription scope using the `azurerm_subscription_policy_assignment` resource.

The operational discipline around it matters as much as the technical implementation. Deploy as audit, baseline existing violations, remediate them, then switch to deny. Test both the blocking behavior and the explicit non-blocking behavior for resource-group-scoped assignments. Know that deny is not a retroactive control - it prevents new violations, it does not clean up old ones.

After this is in place, nobody can casually assign Owner at subscription scope. They get an immediate HTTP 403 with a policy reference, not a compliance dashboard entry that gets reviewed in the next quarterly access review cycle. That shift from detection to prevention is the point.

Happy scripting!
