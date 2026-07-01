---
title: "Azure Security Center: secure score and security recommendations"
author: Victor Silva
date: 2021-06-15T10:44:27+00:00
layout: post
permalink: /azure-security-center-secure-score/
excerpt: "A practical guide to Azure Security Center's secure score: understanding recommendations, remediating findings, and tracking security posture improvements over time."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Azure Security Center
  - Security
  - Secure Score
  - PowerShell
---

When you first enable Azure Security Center, the alert feed is usually the first thing that grabs your attention. Something is misconfigured, something is exposed, something looks suspicious — and the natural instinct is to start chasing those alerts one by one. The problem is that working through individual alerts without a broader view of your posture is a bit like patching holes in a boat while ignoring the waterline.

That's where the secure score comes in. It's the single number that tells you, at a glance, how well your Azure environment is protected against known attack vectors. But more importantly, it's a structured, prioritized backlog. The secure score doesn't just say "things are bad" — it tells you what to fix, in what order, and by how much each fix will move the needle.

In this post I'll walk through how the secure score is calculated, how to navigate it effectively in the portal, and how to pull it programmatically with PowerShell so you can build it into reporting workflows. By the end, you'll have a clear mental model of what drives the score and a repeatable process for improving it over time.

## How Secure Score Works

The formula is straightforward: `(points achieved / max points) × 100`. You start at zero and accumulate points as you remediate findings. The key nuance — and the one that trips up most teams — is that the score is organized into **security controls**, not individual recommendations.

A security control is a logical grouping of related recommendations. Examples you'll encounter frequently:

- **Enable MFA** — covers accounts with owner, write, and read permissions
- **Apply system updates** — applies to VMs that have pending OS patches
- **Remediate security configurations** — catches HTTPS enforcement, disk encryption gaps, and similar hardening items
- **Restrict unauthorized network access** — NSG exposure on management ports (SSH, RDP)

Each control has a maximum point value, and here's the critical mechanic: **the points for a control are awarded only when every recommendation in that control is remediated**. Not partially, not proportionally — all or nothing. If a control is worth 10 points and you have 10 resources flagged, fixing 9 of them earns you 0 points. The tenth resource still blocks the full control.

This changes how you should approach remediation. A control with 2 resources flagged and a high point value is far more valuable to fix than a control with 50 resources flagged and the same point value. The effort-to-impact ratio is completely different.

## Navigating Secure Score in the Portal

In the Azure portal, navigate to **Azure Security Center** and select **Secure score** from the left-hand menu. The main view gives you:

- Your overall score as a percentage, with a trend chart showing change over the past 7 or 30 days
- Score broken down by subscription (useful when you manage multiple subscriptions under a single tenant)
- The full list of security controls, each showing its current score, maximum score, and the number of unhealthy resources

Clicking any control expands it and shows the individual recommendations underneath, along with the specific resources that are failing each check. This is where the actual remediation work happens.

Two UI features that I use constantly:

**Quick Fix** — many recommendations have a "Quick Fix" button that lets Azure Security Center apply the remediation automatically, without you having to go configure each resource manually. Not all recommendations support it (some require architectural decisions), but when it's available it's the fastest path to closing a finding.

**Potential score increase** — the security controls list has a column showing how many points you'll gain by fully remediating that control. Sort by this column descending and you have your prioritized remediation queue.

## Working Through Recommendations

The filter and sort capabilities in the portal are more useful than they look. When I'm working through a backlog, I usually start with controls sorted by **Potential score increase** and filter to show only those with **Quick Fix** available. That combination gives you the highest-impact, lowest-effort remediations first — exactly where you want to start when you're trying to move the score quickly.

For recommendations that don't apply to your specific architecture, Azure Security Center has an **Exempt** option. Exemptions remove the recommendation from your score calculation, which is appropriate when the finding reflects an intentional design decision rather than a gap. For example, if your security model explicitly allows RDP access to certain management VMs through a restricted jumpbox, exempting "Management ports should be closed on your virtual machines" is legitimate — but document the reason in the exemption justification.

There's also a distinction between **Remediate** and **Enforce** that's worth understanding. Remediate fixes existing non-compliant resources. Enforce prevents future non-compliant resources from being created in the first place (it works by deploying Azure Policy in deny mode or deploy-if-not-exists mode). Ideally you do both: close existing gaps and prevent them from recurring.

## Getting Secure Score via PowerShell

The `Az.Security` module exposes the secure score and controls directly, which makes it easy to pull this data into scripts, dashboards, or scheduled reports.

{% highlight posh %}
# Connect to Azure
Connect-AzAccount

# Get secure score for all subscriptions in context
Get-AzSecuritySecureScore | Select-Object Name, CurrentScore, MaxScore, Percentage
{% endhighlight %}

The `Name` field maps to the subscription ID. `CurrentScore` and `MaxScore` are the raw point values, and `Percentage` is what gets displayed in the portal. If you're managing multiple subscriptions, loop over them explicitly:

{% highlight posh %}
$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id | Out-Null
    
    $score = Get-AzSecuritySecureScore
    
    [PSCustomObject]@{
        Subscription  = $sub.Name
        CurrentScore  = $score.CurrentScore
        MaxScore      = $score.MaxScore
        Percentage    = [math]::Round($score.Percentage, 1)
    }
}
{% endhighlight %}

To drill into the individual controls and see where your points are (or aren't) coming from:

{% highlight posh %}
# Get all security controls with their scores
Get-AzSecuritySecureScoreControl | 
    Select-Object DisplayName, CurrentScore, MaxScore, PercentageScore |
    Sort-Object PercentageScore
{% endhighlight %}

This gives you the same ranked list you see in the portal, but now you can slice it however you want — filter to controls below a threshold, pipe to a reporting function, or compare snapshots over time.

## Exporting All Recommendations to CSV

For reporting to management or tracking remediation progress week over week, I find it useful to export the full recommendation list to CSV. `Get-AzSecurityTask` returns the current outstanding tasks (recommendations) across your subscriptions:

{% highlight posh %}
$recommendations = Get-AzSecurityTask | 
    Select-Object RecommendationType, ResourceId, State, @{
        Name       = "Subscription"
        Expression = { ($_.Id -split "/")[2] }
    }

$outputFile = "asc-recommendations-$(Get-Date -Format 'yyyyMMdd').csv"
$recommendations | Export-Csv -Path $outputFile -NoTypeInformation

Write-Host "Exported $($recommendations.Count) recommendations to $outputFile"
{% endhighlight %}

The `RecommendationType` field tells you which security control the recommendation belongs to, and `State` shows whether it's active or already addressed. This CSV becomes the working document for your remediation sprint — assign resource owners, track progress, and compare exports between weeks to measure what actually moved.

## Tracking Score Over Time with Log Analytics

If you have the Azure Security Center data connector enabled in a Log Analytics workspace, score history gets streamed there and you can query it with KQL. The basic trend query looks like this:

{% highlight kql %}
AzureSecurityCenterSecureScore
| where TimeGenerated > ago(30d)
| summarize MaxScore = max(SecureScore) by bin(TimeGenerated, 1d), SubscriptionName
| render timechart
{% endhighlight %}

This renders a daily line chart of your score over the past 30 days, broken down by subscription. It's the most compelling visualization for security review meetings because it makes progress (or regression) immediately visible. The table name and exact field availability depends on how your workspace was configured and which ASC plans are enabled, so you may need to adjust the field names to match your environment.

## Practical Prioritization Strategy

Rather than trying to work through every recommendation, a more effective approach is to pick your targets deliberately:

**Start with quick wins.** Controls that have high point values, few remaining resources, and Quick Fix available are your best opening moves. In most environments, "Enable MFA for accounts with owner permissions" and "Apply system updates" tend to fall into this category — high impact, and the remediation path is well-understood.

**Don't chase 100%.** Some recommendations reflect architectural decisions that are intentional. A development subscription might legitimately have permissive network access for testing purposes. A recommendation about disabling public access might not apply to a service that's explicitly public-facing. Use Exempt for these cases and don't let them drag down the score in a way that obscures where your real gaps are.

**Revisit the score after every remediation sprint.** The score is a lagging indicator — resources that get fixed today may not be reflected in the score until the next scan cycle (typically every 24 hours). Build a cadence of checking the score weekly rather than expecting instant feedback.

## Azure Defender vs. the Free Tier

It's worth knowing that some recommendations only surface when **Azure Defender** is enabled on a given resource type. The free tier of Azure Security Center covers foundational recommendations, but Azure Defender for Servers unlocks vulnerability assessment findings, adaptive application controls, and file integrity monitoring. Azure Defender for SQL adds data classification and advanced threat detection recommendations.

This matters for two reasons. First, if your score seems lower than expected after enabling Defender, it's because more recommendations are now visible — you didn't get worse, you're just seeing more. Second, some of the highest-value controls (particularly around vulnerability assessment) require Defender to be enabled before they can be remediated at all.

The practical implication: enable Azure Defender on the resource types that matter most to your workloads, accept that your score will temporarily drop as new recommendations appear, and then work the backlog.

## Closing Thoughts

Secure score is most useful when it becomes a shared metric — not just a number the security team tracks, but something that development and operations teams see in their dashboards and understand how to influence. When the team responsible for deploying VMs knows that missing the "Apply system updates" control costs points and that those points have a visible impact on a dashboard their manager reviews, the conversation about patching changes.

The real shift happens when remediation stops being a security team responsibility and becomes a shared engineering practice. Secure score, because it's transparent and action-oriented, is one of the better tools available for making that shift happen. Start with PowerShell to pull the data into your existing reporting workflows, build a weekly review cadence, and treat the score as a sprint metric alongside your other engineering KPIs.

Happy scripting!
