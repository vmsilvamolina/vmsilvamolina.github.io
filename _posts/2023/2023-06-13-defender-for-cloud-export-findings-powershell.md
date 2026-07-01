---
title: "Microsoft Defender for Cloud: exporting security findings with PowerShell"
author: Victor Silva
date: 2023-06-13T11:27:44+00:00
layout: post
permalink: /defender-for-cloud-export-findings-powershell/
excerpt: "How to export Microsoft Defender for Cloud security recommendations, alerts, and secure score data using PowerShell and the Azure Security REST API — for reporting, ticketing, and automation workflows."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Microsoft Defender for Cloud
  - PowerShell
  - Security
  - Automation
---

Microsoft Defender for Cloud's portal is genuinely good for interactive security investigation. You can drill into a specific recommendation, trace affected resources, browse the secure score breakdown, and filter alerts by severity — all without writing a single line of code. The problem starts the moment someone asks you to produce a weekly security report, feed findings into a ticketing system, or trigger remediation workflows automatically. The portal was not built for that. Clicking through blades and copying rows from a grid does not scale, and it does not integrate with anything.

The answer is the API. Microsoft Defender for Cloud exposes its entire data surface — recommendations, alerts, secure score, and assessment details — through the Azure Resource Manager REST API. PowerShell makes it straightforward to call that API, filter and transform the results, and push the data wherever it needs to go: a CSV for the compliance team, a JSON payload for a ServiceNow or Jira webhook, or a Log Analytics workspace for correlation with other signals.

This post walks through the full pattern. We will start with the `Az.Security` module cmdlets for the common cases, move to direct REST API calls where the cmdlets fall short on detail, and end with the multi-subscription pattern and a webhook integration that are the most common real-world needs. By the end you will have runnable scripts that cover the scenarios most teams encounter when operationalizing Defender for Cloud.

## Prerequisites

You need the Az PowerShell module installed and a connection to the target subscription. If you have not set this up yet:

{% highlight posh %}
# Install the Az module (user scope — no admin required)
Install-Module Az -Scope CurrentUser -Force

# Authenticate
Connect-AzAccount

# Set the target subscription
$subscriptionId = "<your-subscription-id>"
Set-AzContext -SubscriptionId $subscriptionId
{% endhighlight %}

The minimum Azure role you need for everything in this post is **Security Reader** on the target subscription. If you are running the multi-subscription pattern later, you need Security Reader on each subscription or at the management group level. Security Reader is a read-only role — it cannot change anything in Defender for Cloud and it does not grant access to workload resources directly, so it is safe to scope broadly for automation accounts.

Verify the Az.Security module is present and responsive:

{% highlight posh %}
Get-Module -Name Az.Security -ListAvailable
Get-AzSecurityTask -ErrorAction SilentlyContinue | Select-Object -First 1
{% endhighlight %}

If the second command returns data, you are connected and the module is working. If it returns nothing but no error, the subscription simply has no open recommendations right now — which would be a pleasant problem to have.

## Exporting Security Recommendations

Recommendations in Defender for Cloud are surfaced through the `Get-AzSecurityTask` cmdlet. Each task represents an assessment result — something Defender for Cloud evaluated and found either needing attention or already remediated. For reporting purposes you generally want the active, open items.

{% highlight posh %}
# Get all open security recommendations
$recommendations = Get-AzSecurityTask

# Filter to active state with a valid recommendation type
$highSeverity = $recommendations | Where-Object {
    $_.State -eq "Active" -and
    $_.RecommendationType -ne $null
}

# Export to CSV with computed columns for readability
$highSeverity | Select-Object `
    RecommendationType, `
    ResourceId, `
    State, `
    @{Name="ResourceName"; Expression={ ($_.ResourceId -split "/")[-1] }}, `
    @{Name="Subscription"; Expression={ ($_.ResourceId -split "/")[2] }} |
Export-Csv -Path "defender-recommendations-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

Write-Host "Exported $($highSeverity.Count) active recommendations"
{% endhighlight %}

The `ResourceId` split expressions are worth explaining. In Azure, every resource ID follows the pattern `/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/<type>/<name>`. Splitting on `/` and taking index `[-1]` gives you the resource name, and index `[2]` gives you the subscription ID. These computed columns make the CSV immediately readable without requiring the consumer to parse ARM resource IDs themselves.

## Exporting Security Alerts

Alerts in Defender for Cloud represent detected threats — active attack signals, suspicious process executions, anomalous network connections, and so on. The `Get-AzSecurityAlert` cmdlet retrieves them directly.

{% highlight posh %}
# Get alerts from the last 30 days
$alerts = Get-AzSecurityAlert | Where-Object {
    $_.StartTimeUtc -gt (Get-Date).AddDays(-30)
}

# Group by severity to build a summary
$alertSummary = $alerts | Group-Object -Property AlertSeverity | 
    Select-Object Name, Count |
    Sort-Object Count -Descending

Write-Host "Alert summary:"
$alertSummary | Format-Table -AutoSize

# Export full alert detail to CSV
$alerts | Select-Object `
    AlertDisplayName, `
    AlertSeverity, `
    AlertType, `
    StartTimeUtc, `
    CompromisedEntity, `
    Status, `
    Description |
Export-Csv -Path "defender-alerts-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
{% endhighlight %}

The `CompromisedEntity` field is often the most useful for triage — it gives you the resource name that triggered the alert. The `AlertType` is the internal classification string (for example, `VM_SuspectProcessTermination`) that maps to specific detection logic. If you are integrating this with a ticketing system, `AlertType` is the field to use for deduplication and routing rules.

## Getting Secure Score via REST API

The `Az.Security` module includes `Get-AzSecuritySecureScore` but the REST API gives you more precise numeric detail — the raw current score and max score that the percentage is calculated from. This is the approach I use when building compliance dashboards because you want the numbers, not just the percentage.

{% highlight posh %}
$subscriptionId = (Get-AzContext).Subscription.Id
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token
$headers = @{ Authorization = "Bearer $token" }

# Get the subscription secure score
$scoreUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Security/secureScores/ascScore?api-version=2020-01-01"
$score = Invoke-RestMethod -Uri $scoreUri -Headers $headers -Method GET

$current = $score.properties.score.current
$max = $score.properties.score.max
$percentage = [math]::Round(($current / $max) * 100, 1)

Write-Host "Secure Score: $current/$max ($percentage%)"
{% endhighlight %}

`Get-AzAccessToken` is the clean way to get a bearer token for ARM API calls from within an authenticated Az session. The token is scoped to `https://management.azure.com` — the same resource the Az module itself uses — so no separate service principal registration or client secret is needed. The token is valid for one hour, which is more than enough for a reporting script.

## Getting Recommendations with Full Detail via REST

This is where it gets useful. The `Get-AzSecurityTask` cmdlet returns a limited field set. The assessments API endpoint returns the full assessment object including remediation description, display name, metadata severity, and the exact status cause — the "why" behind an unhealthy state. For compliance reporting, you almost always need this additional detail.

{% highlight posh %}
# Get all assessments — these are the full recommendation objects
$assessmentsUri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Security/assessments?api-version=2021-06-01"
$assessments = Invoke-RestMethod -Uri $assessmentsUri -Headers $headers -Method GET

# Filter to unhealthy assessments only
$unhealthy = $assessments.value | Where-Object {
    $_.properties.status.code -eq "Unhealthy"
}

# Build a flat report object
$report = $unhealthy | ForEach-Object {
    [PSCustomObject]@{
        DisplayName            = $_.properties.displayName
        Severity               = $_.properties.metadata.severity
        ResourceId             = $_.properties.resourceDetails.id
        RemediationDescription = $_.properties.metadata.remediationDescription
        StatusCode             = $_.properties.status.code
        StatusCause            = $_.properties.status.cause
    }
}

$report | Sort-Object Severity | 
    Export-Csv -Path "defender-unhealthy-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

Write-Host "Unhealthy assessments exported: $($unhealthy.Count)"
{% endhighlight %}

The `RemediationDescription` field is the most valuable addition here. It is the human-readable remediation guidance from Defender for Cloud — the same text you see in the portal when you expand a recommendation. Including this in a CSV means the compliance team or resource owner can open the report and immediately understand what they need to do, without having to cross-reference the portal.

Note that the assessments API response is paginated. If your subscription has a large number of resources, you will get a `nextLink` property in the response. For subscriptions with hundreds of resources, add pagination handling:

{% highlight posh %}
$allAssessments = @()
$uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.Security/assessments?api-version=2021-06-01"

do {
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method GET
    $allAssessments += $response.value
    $uri = $response.nextLink
} while ($uri)

Write-Host "Total assessments retrieved: $($allAssessments.Count)"
{% endhighlight %}

## Multi-Subscription Export

Platform and security teams managing large Azure estates routinely need a consolidated view across every subscription in the tenant. This pattern iterates over all accessible subscriptions, collects recommendations from each, and outputs a single CSV with a subscription name column so the consumer knows where each finding lives.

{% highlight posh %}
$subscriptions = Get-AzSubscription
$allRecommendations = @()

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    Write-Host "Processing: $($sub.Name)"

    $recs = Get-AzSecurityTask | Where-Object { $_.State -eq "Active" }
    $recs | Add-Member -NotePropertyName "SubscriptionName" -NotePropertyValue $sub.Name -Force
    $allRecommendations += $recs
}

$allRecommendations | 
    Select-Object SubscriptionName, RecommendationType, ResourceId, State |
    Export-Csv -Path "defender-all-subscriptions-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation

Write-Host "Total recommendations across $($subscriptions.Count) subscriptions: $($allRecommendations.Count)"
{% endhighlight %}

`Set-AzContext` switches the active subscription context mid-loop, which is the key that makes this work. The `Az.Security` cmdlets always operate against the current context's subscription. The `| Out-Null` suppresses the context object that `Set-AzContext` outputs, which keeps the console readable during a long run. The `Add-Member` call patches a `SubscriptionName` property onto each task object before it gets added to the aggregate array — this is the cleanest way to carry that metadata through without restructuring the objects.

## Sending Findings to a Webhook

Once you have findings in memory, integrating with a ticketing or alerting system is a single `Invoke-RestMethod` call per item. This pattern works for Microsoft Teams, ServiceNow, PagerDuty, Jira Service Management — anything that accepts an HTTP POST with a JSON body.

{% highlight posh %}
$webhookUrl = $env:TEAMS_WEBHOOK_URL  # set as an environment variable — never hardcode

$criticalAlerts = Get-AzSecurityAlert | 
    Where-Object { $_.AlertSeverity -eq "High" -and $_.Status -eq "Active" }

foreach ($alert in $criticalAlerts) {
    $payload = @{
        title = "Defender for Cloud: $($alert.AlertDisplayName)"
        text  = "**Resource:** $($alert.CompromisedEntity)<br>**Severity:** $($alert.AlertSeverity)<br>**Description:** $($alert.Description)"
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $webhookUrl -Method POST -Body $payload -ContentType "application/json"
    Write-Host "Sent alert: $($alert.AlertDisplayName)"
}
{% endhighlight %}

Keep the webhook URL in an environment variable or, better, in an Azure Key Vault secret retrieved at runtime. Hardcoding URLs that contain tokens or secrets into scripts is how credentials end up in source control. If you are running this from Azure Automation, use the `Get-AutomationVariable` or Key Vault reference approach instead of `$env`.

## Scheduling with Azure Automation

The natural next step after validating these scripts locally is to schedule them. Azure Automation Runbooks with a daily schedule cover the most common use case: an overnight report that lands in a storage account or gets emailed to the security team each morning.

The credential story here is important. Create an Automation Account with a system-assigned Managed Identity, then assign the **Security Reader** role to that identity on the target subscriptions. Inside the runbook, authenticate with:

{% highlight posh %}
Connect-AzAccount -Identity
{% endhighlight %}

That single line replaces the `Connect-AzAccount` interactive login and eliminates every stored credential, certificate, or service principal secret from the equation. The Managed Identity's token is retrieved from the Azure Instance Metadata Service at runtime — nothing to rotate, nothing to leak. Pair the Automation Account with a schedule set to run at 06:00 UTC daily and you have a fully unattended export pipeline with no credential management overhead.

## Best Practices

**Use the REST API for report-grade exports.** The `Az.Security` cmdlets are convenient for quick queries but the `assessments` API endpoint returns significantly more metadata per finding. If the output is going to a compliance team, a ticketing system, or a dashboard, go straight to REST — the remediation description alone is worth it.

**Paginate when you paginate.** The assessments API paginates for large subscriptions. The cmdlets handle this internally, but `Invoke-RestMethod` does not. If you skip pagination handling and the subscription has many resources, you will silently miss findings. Always check for and follow `nextLink`.

**Filter at the source, not at the consumer.** It is tempting to pull all findings and let the downstream tool (the CSV reader, the ticket system) filter. That adds latency, increases the payload size, and puts processing burden on the consumer. Filter on `State`, `AlertSeverity`, and `properties.status.code` in your script before you emit anything.

**Scope the Managed Identity as narrowly as possible.** Security Reader on the specific subscriptions you are reporting on — not Owner or Contributor on the management group. The export scripts in this post never need write access to anything. If the Automation Account's Managed Identity ever gets compromised, a Security Reader scope limits the blast radius to read-only access to security metadata.

**Timestamp your output files.** The `$(Get-Date -Format 'yyyyMMdd')` pattern in every `Export-Csv` call above ensures you never overwrite a previous day's report. This is particularly important when outputs go to a shared storage account — you want the full history, not just the latest snapshot.

**Combine with continuous export for real-time coverage.** The scripts in this post are pull-based — you call the API and get the current state. Defender for Cloud's continuous export feature (available in the portal under Environment Settings) streams findings to an Event Hub or Log Analytics workspace in near-real-time as they occur. For operational workflows like incident response, continuous export to Event Hub and an alert rule on the workspace gives you sub-minute detection. The PowerShell export approach is better suited for scheduled compliance reporting, not real-time alerting. Use both together.

## Conclusion

The Defender for Cloud API is stable and well-documented, and once you have the PowerShell patterns in place, you can build any reporting or automation workflow on top of them without touching the portal again. The secure score via REST, the full-detail assessments endpoint, and the alert export cover the three data domains that security teams need most. The multi-subscription pattern is what makes this useful at scale — a single script producing a consolidated CSV across a large Azure estate is far more actionable than manual per-subscription portal reviews.

Combined with the Defender for Cloud continuous export feature, you have both real-time streaming and on-demand pull covered. Pull for compliance reports and scheduled exports; stream for operational alerting and SIEM integration. The PowerShell patterns here are the on-demand half of that picture — straightforward to automate, easy to extend, and deployable without infrastructure beyond an Automation Account.

Happy scripting!
