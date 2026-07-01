---
title: "Log Analytics Workspace: KQL Queries for Security"
author: Victor Silva
date: 2021-02-09T09:17:34+00:00
layout: post
permalink: /log-analytics-kql-seguridad/
excerpt: "How to use KQL in Log Analytics Workspace to detect critical security events in Azure: failed logons, privileged access, NSG changes, RBAC assignments, and more."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Log Analytics
  - KQL
  - Security
  - Azure Security Center
  - PowerShell
---

When you start working with **Azure Security Center**, the first impression is that the portal gives you everything you need: alerts, recommendations, secure score. That's fine for getting started. But at some point the uncomfortable moment arrives — someone tells you "check the failed sign-ins from last week" or "who assigned that Owner role at 3 AM yesterday" — and the ASC portal doesn't give you that answer directly.

What ASC doesn't make obvious is that behind everything there's a **Log Analytics Workspace** accumulating practically every event in your Azure environment. Control plane activity, Windows events from your VMs, Azure Active Directory logs, network resource changes. It's all there, waiting for you to ask the right questions.

Those questions are written in **KQL** — Kusto Query Language. It's the native query language for Log Analytics, Azure Monitor, and by extension, Azure Sentinel. Once you get comfortable with it, going back to searching things manually in the portal becomes painful. In this post I'll walk through 6 security queries I use regularly, with an explanation of what each one looks for and what signals should raise your attention.

## KQL for People Coming from SQL

If you've ever written a SQL query, KQL will feel structurally familiar even though the syntax is different. The most important difference is that KQL works with **pipes** (`|`) to chain operations — think of it as a pipeline where each step filters or transforms the output of the previous one.

| SQL | KQL | What it does |
|-----|-----|--------------|
| `SELECT` | `project` | Selects columns |
| `WHERE` | `where` | Filters rows |
| `GROUP BY` | `summarize ... by` | Groups and aggregates |
| `ORDER BY` | `sort by` or `order by` | Sorts results |
| `TOP N` | `top N by` | First N records |
| `GETDATE() - 1` | `ago(24h)` | Relative time window |

The `ago()` function is the one you'll use the most — it accepts `1h`, `24h`, `7d`, `30d`. Always starting with a time window is good practice both for performance and for result relevance.

## Prerequisites

Before any query returns useful data, you need three things configured:

**1. An active Log Analytics Workspace**

Verify you have a workspace created. From PowerShell:

{% highlight posh %}
Get-AzOperationalInsightsWorkspace | Select-Object Name, ResourceGroupName, Sku, RetentionInDays
{% endhighlight %}

**2. Azure Security Center connected to the workspace**

In the Azure portal: **Security Center > Pricing & settings > [your subscription] > Data Collection**. Enable *Auto provisioning* for the agent (Log Analytics agent / MMA). This is what causes Windows events (`SecurityEvent`) and VM heartbeats to flow into the workspace.

**3. Azure AD Diagnostic Settings configured — this is the step most people skip**

Azure Active Directory logs (SigninLogs, AuditLogs) **do not arrive automatically** in the workspace. You have to configure them explicitly:

- **Azure Active Directory > Diagnostic settings > + Add diagnostic setting**
- Select: `SignInLogs` and `AuditLogs`
- Destination: **Send to Log Analytics workspace** > pick your workspace
- Save, and within a few minutes the logs start arriving

Without this step, AAD queries simply return no data.

## 6 KQL Queries for Security

### Query 1 — Failed Sign-in Attempts (Azure AD)

This is the first query I run whenever someone reports suspicious behavior on an account.

{% highlight kql %}
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType != 0
| summarize FallosTotal = count() by UserPrincipalName, ResultDescription, ResultType
| sort by FallosTotal desc
{% endhighlight %}

`ResultType != 0` excludes successful logons. The most relevant error codes to investigate:

- **50126** — incorrect credentials (wrong password)
- **50053** — account locked out due to too many attempts
- **50074** — MFA required but failed or was cancelled
- **70011** — invalid scope or expired refresh token

A user with 50+ error 50126 events in an hour from different IPs is a password spray signal. A single user with error 50053 is a candidate for compromise review or a legitimate lockout investigation.

### Query 2 — Failed Logons on Windows VMs (Event 4625)

For VMs, Windows security events land in the `SecurityEvent` table. EventID 4625 is the local/domain failed logon event.

{% highlight kql %}
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4625
| project TimeGenerated, Computer, Account, IpAddress, LogonTypeName, SubStatus
| sort by TimeGenerated desc
{% endhighlight %}

To detect brute force — more than 10 attempts in one hour from the same IP:

{% highlight kql %}
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4625
| summarize Intentos = count() by IpAddress, Computer, bin(TimeGenerated, 1h)
| where Intentos > 10
| sort by Intentos desc
{% endhighlight %}

The `LogonTypeName` column tells you the logon type: *Network*, *Interactive*, *RemoteInteractive* (RDP). A spike in failed *Network* or *RemoteInteractive* logons from an external IP is a direct signal of an attack against an exposed RDP or SMB service.

### Query 3 — Privileged Administrative Access (Event 4672)

EventID 4672 is generated every time an account signs in with special privileges assigned (SeDebugPrivilege, SeTcbPrivilege, among others). In practice: any administrator account opening a session.

{% highlight kql %}
SecurityEvent
| where TimeGenerated > ago(24h)
| where EventID == 4672
| where SubjectUserName !endswith "$"
| project TimeGenerated, Computer, SubjectUserName, SubjectDomainName, PrivilegeList
| sort by TimeGenerated desc
{% endhighlight %}

The `!endswith "$"` filter excludes computer accounts (which end in `$` by Active Directory convention) and cuts down the noise considerably. What you're left with is human users exercising privileged access — something you want to audit, especially outside business hours.

### Query 4 — Network Security Group Changes

This query uses the `AzureActivity` table, which records all Azure control plane operations. The good news is that `AzureActivity` is available in the workspace **without additional configuration** — it flows in by default once you've connected the subscription to Log Analytics.

{% highlight kql %}
AzureActivity
| where TimeGenerated > ago(7d)
| where CategoryValue =~ "Administrative"
| where OperationNameValue has "Microsoft.Network/networkSecurityGroups"
| where ActivityStatusValue =~ "Succeeded"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, Resource
| sort by TimeGenerated desc
{% endhighlight %}

I used `has` instead of `==` to capture both operations on the NSG itself (`networkSecurityGroups/write`) and on its rules (`networkSecurityGroups/securityRules/write`). The `Caller` column tells you who made the change — it can be a user, a service principal, or a managed identity.

If you see NSG changes affecting production subnets outside an authorized change window, that's a signal worth investigating.

### Query 5 — RBAC Role Assignments

Knowing who assigns Owner, Contributor, or User Access Administrator roles is critical. This query gives you the role assignment history for the last 30 days.

{% highlight kql %}
AzureActivity
| where TimeGenerated > ago(30d)
| where OperationNameValue =~ "Microsoft.Authorization/roleAssignments/write"
| where ActivityStatusValue in ("Start", "Succeeded")
| project TimeGenerated, Caller, ResourceGroup, Resource, OperationNameValue
| sort by TimeGenerated desc
{% endhighlight %}

I included both `Start` and `Succeeded` because sometimes you want to see the attempt even if it didn't complete successfully — for example, if someone tries to assign themselves Owner on a subscription where they don't have permissions to do so. The `Caller` here is the person *assigning* the role, not the person *receiving* it. To see the target principal you need to parse the `Properties` field, which contains the operation detail as JSON.

### Query 6 — Guest Accounts Invited to Azure AD

External user invitations to your Azure AD tenant are a risk vector that frequently goes unmonitored. This query uses `AuditLogs` (which we configured in the prerequisites).

{% highlight kql %}
AuditLogs
| where TimeGenerated > ago(30d)
| where OperationName == "Invite external user"
    or OperationName == "Add user"
| extend TargetUser = tostring(TargetResources[0].userPrincipalName)
| extend InitiatedBy_User = tostring(InitiatedBy.user.userPrincipalName)
| where TargetUser has "#EXT#"
| project TimeGenerated, OperationName, TargetUser, InitiatedBy_User, Result
| sort by TimeGenerated desc
{% endhighlight %}

The `has "#EXT#"` filter is what identifies guest accounts in Azure AD — the UPN of external users always contains `#EXT#` followed by the tenant domain. The `InitiatedBy_User` column tells you who sent the invitation, which is the key piece of information to validate whether it was an authorized action or not.

## Bonus — Verifying Agent Heartbeat

Before trusting that `SecurityEvent` queries are returning complete data, it's worth checking that all agents are reporting correctly:

{% highlight kql %}
Heartbeat
| where TimeGenerated > ago(1h)
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| sort by LastHeartbeat desc
{% endhighlight %}

Any VM that doesn't appear here, or has a stale `LastHeartbeat`, is not sending events to the workspace. It could be a downed agent, a connectivity problem, or a VM that's turned off — but it's something you need to resolve before assuming coverage is complete.

## Data Retention

By default, Log Analytics keeps 30 days of data. For security scenarios that's not enough — incident investigations frequently need to look further back, and some compliance frameworks (SOC 2, ISO 27001) require at least 90 days of online retention.

You can adjust retention from the portal at **Log Analytics workspace > Usage and estimated costs > Data Retention**, or via PowerShell:

{% highlight posh %}
Set-AzOperationalInsightsWorkspace -ResourceGroupName "rg-security" `
    -Name "law-security-prod" `
    -RetentionInDays 90
{% endhighlight %}

The additional cost is per GB/month for days beyond the free 30 — check the Azure pricing calculator for your data volume before bumping up to 365 days.

## Wrapping Up

KQL is the common denominator across the entire Azure security platform. The same queries you write today in Log Analytics will work tomorrow in Azure Sentinel when you roll it out. Azure Monitor alerts are built on KQL. Security Center workbooks too.

Mastering even these 6 basic patterns — failed logons in AAD, events 4625 and 4672 on Windows, NSG changes, role assignments, and guest invitations — gives you visibility that the Azure Security Center dashboard alone cannot provide. The ASC portal tells you *what* is wrong; KQL lets you understand *who*, *when*, and *from where*.

From here, the natural next step is to start turning these queries into scheduled alerts or detection rules in Azure Sentinel. But that's a topic for another post.

Happy scripting!
