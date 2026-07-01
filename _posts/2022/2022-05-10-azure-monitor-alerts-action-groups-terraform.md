---
title: "Azure Monitor: deploying alerts and action groups with Terraform"
author: Victor Silva
date: 2022-05-10T13:17:29+00:00
layout: post
permalink: /azure-monitor-alerts-action-groups-terraform/
excerpt: "How to deploy Azure Monitor metric alerts and action groups as code using Terraform — covering the azurerm provider resources, alert severity levels, and email/webhook notification targets."
categories:
  - Azure
  - Terraform
tags:
  - Azure
  - Terraform
  - Azure Monitor
  - IaC
  - DevOps
  - Alerting
---

When you configure Azure Monitor alerts through the portal, they feel solid right up until someone deletes and recreates a resource group. The alerts are gone. The action groups that defined who gets notified — also gone. The next time something goes down, nobody hears about it until a user files a ticket. This is the quiet failure mode of manual alert configuration: it works until the infrastructure changes, and infrastructure always changes.

The fix is straightforward: manage your alerts and action groups the same way you manage the resources they monitor. Put them in Terraform, put that in version control, and deploy them alongside the rest of your infrastructure. When you recreate a resource group, the alerts come back automatically. When you add a new environment, the alert coverage is identical to production from day one.

This post walks through a complete alerting setup using Terraform and the `azurerm` provider 3.x: an action group that routes notifications to email and a Teams webhook, metric alerts for VM CPU and storage account availability, and activity log alerts for the security-relevant control plane events you actually want to know about — RBAC role assignment changes and NSG rule modifications.

## What we are building

The setup has two layers. The first is an action group, which is Azure Monitor's way of defining *who gets notified and how*. Think of it as the notification routing table. The second layer is the alerts themselves: metric alerts that fire when a measurement crosses a threshold, and activity log alerts that fire when a specific Azure operation is recorded.

Metric alerts and activity log alerts behave differently and it is worth being clear on that before writing any code. Metric alerts are continuous — they evaluate on a schedule, fire when the condition is met, and auto-resolve when the condition clears. Activity log alerts are event-based — they fire once when the matching operation hits the activity log, they do not auto-resolve, and they do not re-fire unless the operation happens again. Both types reference an action group to know where to send the notification.

The resources we will use from the `azurerm` provider 3.x:

- `azurerm_monitor_action_group` — notification routing
- `azurerm_monitor_metric_alert` — threshold-based alerts on resource metrics
- `azurerm_monitor_activity_log_alert` — event-based alerts on control plane operations

## Prerequisites

You will need:

- Terraform 1.1.x or 1.2.x (this post was written against 1.2.0)
- The `azurerm` provider `~> 3.0`
- Azure CLI installed and authenticated (`az login`, `az account set`)
- Contributor access (or a custom role with `Microsoft.Insights/*` write permissions) on the target subscription

Verify your setup:

{% highlight bash %}
terraform version
# Terraform v1.2.0

az account show --query "{name:name, id:id}" -o table
{% endhighlight %}

Your `versions.tf` should declare:

{% highlight hcl %}
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
{% endhighlight %}

## Variables

Before getting into the resources, define the inputs. Create a `variables.tf`:

{% highlight hcl %}
variable "resource_group_name" {
  type        = string
  description = "Resource group for monitoring resources"
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for subscription-scoped alerts"
}

variable "teams_webhook_url" {
  type        = string
  sensitive   = true
  description = "Microsoft Teams incoming webhook URL"
}
{% endhighlight %}

The `teams_webhook_url` is marked `sensitive = true` so Terraform will not print it in plan or apply output. Pass it via a `.tfvars` file or an environment variable (`TF_VAR_teams_webhook_url`) rather than hardcoding it.

## Setting Up the Action Group

Action groups are the foundation of the whole setup. Every alert you create will reference one, and getting the routing right before you create alerts means you are not going back to update every alert resource individually later.

Create an `alerts.tf` and start with the action group:

{% highlight hcl %}
resource "azurerm_monitor_action_group" "ops_team" {
  name                = "ag-ops-team-prod"
  resource_group_name = var.resource_group_name
  short_name          = "ops-prod"

  email_receiver {
    name                    = "ops-email"
    email_address           = "ops-team@company.com"
    use_common_alert_schema = true
  }

  webhook_receiver {
    name                    = "teams-webhook"
    service_uri             = var.teams_webhook_url
    use_common_alert_schema = true
  }
}
{% endhighlight %}

A couple of things worth noting here. The `short_name` field is limited to 12 characters — it is used in SMS notifications. The `use_common_alert_schema = true` flag on both receivers standardizes the payload format across all alert types, which matters for the Teams webhook. Without it, metric alerts and activity log alerts send structurally different JSON payloads to the webhook, and your Teams connector either has to handle both formats or you end up with garbled notifications.

You can add as many receivers as you need: `sms_receiver`, `azure_function_receiver`, `logic_app_receiver`, `arm_role_receiver` (which routes to all users holding a given RBAC role). For most teams, email plus a webhook to their chat platform covers the majority of use cases.

## Metric Alerts

### VM CPU

The first metric alert fires when a VM's average CPU usage exceeds 90% over a 5-minute window. This is a classic warning-level alert: the VM is not down, but something is consuming an unusual amount of CPU and it warrants investigation.

{% highlight hcl %}
resource "azurerm_monitor_metric_alert" "vm_cpu_high" {
  name                = "alert-vm-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_virtual_machine.main.id]
  description         = "Alert when VM CPU exceeds 90% for 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops_team.id
  }
}
{% endhighlight %}

The `frequency` and `window_size` fields use ISO 8601 duration format. `PT1M` is one minute, `PT5M` is five minutes. `frequency` controls how often Azure evaluates the metric; `window_size` controls how much historical data each evaluation looks at. With `frequency = "PT1M"` and `window_size = "PT5M"`, Azure checks every minute whether the average CPU over the last 5 minutes has been above 90%.

The `severity` field is an integer from 0 to 4:

| Severity | Value | Use case |
|---|---|---|
| Critical | 0 | Service down, data loss risk |
| Error | 1 | Service degraded, action required |
| Warning | 2 | Threshold approaching, monitor |
| Informational | 3 | FYI, audit trail |
| Verbose | 4 | Debug or diagnostic |

Severity does not change what happens when an alert fires — it does not route to a different action group, for example. It is metadata that shows up in the Azure Portal and in the alert notification payload, and it is useful for filtering when you have a lot of alerts and need to triage quickly.

### Storage Account Availability

The second metric alert monitors storage account availability. This is an error-level alert because if availability drops below 99.9%, something is wrong and your applications may be failing storage operations.

{% highlight hcl %}
resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "alert-storage-availability"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_storage_account.main.id]
  description         = "Alert when storage availability drops below 99.9%"
  severity            = 1

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99.9
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops_team.id
  }
}
{% endhighlight %}

Notice the `operator` is `LessThan` here, not `GreaterThan`. The metric goes down when there is a problem, so the condition inverts. Getting this backwards is a common mistake — the alert deploys without errors and then never fires because the condition is evaluated in the wrong direction.

Both metric alerts will auto-resolve when the condition is no longer met. Azure Monitor evaluates the condition continuously, and when CPU drops back below 90% or storage availability climbs back above 99.9%, the alert transitions to a resolved state and sends a resolution notification through the same action group.

## Activity Log Alerts

Activity log alerts are structurally different from metric alerts. They watch the Azure Activity Log for specific operations rather than measuring a time-series metric. This makes them the right tool for security monitoring: you want to know when someone changes an RBAC role assignment or modifies an NSG, regardless of any threshold.

### RBAC Role Assignment Changes

{% highlight hcl %}
resource "azurerm_monitor_activity_log_alert" "rbac_change" {
  name                = "alert-rbac-role-assignment"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Alert on any RBAC role assignment change in the subscription"

  criteria {
    operation_name = "Microsoft.Authorization/roleAssignments/write"
    category       = "Administrative"
    level          = "Informational"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops_team.id
  }
}
{% endhighlight %}

The `scopes` for this alert is the subscription root rather than a specific resource. Any RBAC role assignment write anywhere in the subscription will match. The `operation_name` is the ARM operation that creates or updates a role assignment — this is the same value you would see in the Activity Log under the operation name column.

The `level` field here is the activity log event level, not the same as the alert severity. For administrative operations like RBAC changes, the level is typically `Informational` because the operation itself is not an error — it is just something that happened. Set `level` to match what you see in actual Activity Log entries for the operation you are monitoring.

### NSG Rule Changes

{% highlight hcl %}
resource "azurerm_monitor_activity_log_alert" "nsg_change" {
  name                = "alert-nsg-rule-change"
  resource_group_name = var.resource_group_name
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Alert when NSG rules are modified"

  criteria {
    resource_type  = "Microsoft.Network/networkSecurityGroups"
    operation_name = "Microsoft.Network/networkSecurityGroups/securityRules/write"
    category       = "Administrative"
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops_team.id
  }
}
{% endhighlight %}

This alert adds a `resource_type` filter to narrow the scope. Without it, the `operation_name` alone is usually specific enough, but adding `resource_type` makes the intent explicit and provides an extra filter layer. If someone adds or modifies a security rule on any NSG in the subscription, you hear about it.

These activity log alerts fire once per matching event. They do not auto-resolve because there is no ongoing condition to resolve — the event happened, the notification fired, done. If the same operation happens again tomorrow, a new alert fires. Keep this in mind when you configure your Teams channel or email inbox: you should expect one notification per event, not a "firing / resolved" pair like you get with metric alerts.

## Testing and Validation

### Verify the action group

After `terraform apply`, confirm the action group was created correctly:

{% highlight bash %}
az monitor action-group show \
  --name "ag-ops-team-prod" \
  --resource-group "<your-resource-group>" \
  -o json
{% endhighlight %}

You can also send a test notification directly from the action group to confirm the routing works before you ever see a real alert:

{% highlight bash %}
az monitor action-group test \
  --name "ag-ops-team-prod" \
  --resource-group "<your-resource-group>" \
  --alert-type "servicehealth"
{% endhighlight %}

This sends a test payload to all configured receivers. Check your email and your Teams channel to confirm both arrived and the formatting looks correct.

### Verify the metric alerts

List the metric alerts in the resource group:

{% highlight bash %}
az monitor metrics alert list \
  --resource-group "<your-resource-group>" \
  -o table
{% endhighlight %}

To trigger the CPU alert manually without actually stressing a VM, you can temporarily lower the threshold in your Terraform to something like 5%, apply, wait a few minutes for the metric to breach, and then restore the real threshold. Not elegant, but effective for a quick smoke test in a dev environment.

### Verify the activity log alerts

Trigger the RBAC alert by creating a role assignment:

{% highlight bash %}
# Assign a role at subscription scope (this will trigger the alert)
az role assignment create \
  --role "Reader" \
  --assignee "<your-user-objectid>" \
  --scope "/subscriptions/<subscription-id>"
{% endhighlight %}

The activity log alert fires within a few minutes of the operation being recorded. Check your email or Teams channel, then clean up the test assignment:

{% highlight bash %}
az role assignment delete \
  --role "Reader" \
  --assignee "<your-user-objectid>" \
  --scope "/subscriptions/<subscription-id>"
{% endhighlight %}

## Best Practices

**Start with action groups, not alerts.** You need to know where notifications go before you can create alerts that send them. Define and validate your action groups first, then reference them from every alert resource. This keeps the notification routing logic in one place and makes it easy to update — changing the on-call email address means touching one `email_receiver` block, not hunting through every alert resource.

**Use `use_common_alert_schema = true`.** The common alert schema standardizes the JSON payload structure across all alert types. Without it, webhook receivers get structurally different payloads depending on whether the alert came from a metric alert or an activity log alert. Most webhook targets — Teams connectors, PagerDuty, custom functions — are much easier to build and maintain when the payload format is consistent.

**Scope metric alerts to the resource, not the resource group.** The `scopes` field on `azurerm_monitor_metric_alert` accepts resource IDs. Scoping to a specific VM or storage account gives you a precise alert that fires for the right resource. Scoping to a resource group and filtering by resource type is possible but adds complexity; prefer explicit resource scoping.

**Scope activity log alerts to the subscription for security monitoring.** The RBAC and NSG alerts above use subscription scope intentionally. A resource-group-scoped alert would miss operations that happen on resources in other resource groups, which defeats the purpose of security monitoring. For control plane security events, subscription scope is almost always the right choice.

**Name your resources predictably.** Using a consistent naming convention (`alert-vm-cpu-high`, `alert-storage-availability`, `alert-rbac-role-assignment`) makes it easy to find alerts in the portal and to understand what they are from a Terraform state list. Pair this with meaningful `description` values — the description shows up in the alert notification and is the first thing on-call engineers read when they are paged at 2am.

**Auto-resolution is a metric alert feature only.** Activity log alerts do not auto-resolve. If your runbooks or on-call procedures assume every alert has a "resolved" notification, add documentation clarifying which alerts do and do not resolve automatically. Failing to account for this leads to on-call engineers waiting for a resolution notification that will never arrive.

## Conclusion

Alert configuration as code means every environment gets the same coverage from day one. When a new VM is deployed via Terraform, the CPU alert is already defined alongside it in the same pull request. When someone recreates a resource group, the alerts come back automatically with the next apply. There is no "we forgot to set up monitoring" conversation after the fact.

The activity log alerts for RBAC and NSG changes pair naturally with Azure Sentinel or Log Analytics KQL queries — they are different layers of the same security visibility story. The activity log alert gives you an immediate notification; the KQL query gives you the investigation context. Building both as code keeps them in sync with each other and with the infrastructure they are watching.

Happy scripting!
