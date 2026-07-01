---
title: "Azure AD Identity Protection: risk detection and automated remediation"
author: Victor Silva
date: 2021-04-20T14:23:11+00:00
layout: post
permalink: /azure-ad-identity-protection/
excerpt: "How to configure Azure AD Identity Protection to detect risky users and sign-ins, set up risk-based Conditional Access policies, and automate remediation with SSPR."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Azure AD
  - Identity Protection
  - Security
  - Conditional Access
  - PowerShell
---

When a user's credentials get leaked in a third-party breach, the attacker typically doesn't move immediately. They wait, try a few quiet sign-ins from a residential proxy, and by the time someone notices something is wrong, the account has been used as a pivot point for weeks. Traditional security monitoring — alerts on failed sign-ins, reviewing audit logs on a schedule — catches these events after the fact, if it catches them at all.

**Azure AD Identity Protection** is Microsoft's ML-powered answer to this problem. Instead of waiting for you to write a detection query, it continuously evaluates every sign-in and compares it against signals from across the Microsoft identity ecosystem: leaked credential databases, anonymous proxy networks, unusual travel patterns, known malware-linked IP addresses. When something looks off, it assigns a risk score and can automatically enforce a control — require MFA, block access, or force a password reset — without waiting for a human to review the alert.

This post covers how Identity Protection works under the hood, how to configure the built-in risk policies, how to query risky users programmatically via the Microsoft Graph API, and how to integrate it with Self-Service Password Reset so that automated remediation doesn't lock legitimate users out of their accounts.

If you've been following along from the [KQL and Log Analytics post](/log-analytics-kql-seguridad/), I'll also show you how to pull Identity Protection events into your workspace and query them alongside your other security data.

## How Risk Works in Identity Protection

Identity Protection operates on two independent risk dimensions. Understanding the distinction matters because they drive different controls.

**User risk** is a long-lived assessment of whether an identity is compromised. It accumulates over time based on detections like leaked credentials, anomalous behavior patterns, and confirmed compromises in your tenant. A user can have High user risk without any single risky sign-in — for example, if their password shows up in a breach database. User risk persists on the account until it is explicitly remediated or dismissed.

**Sign-in risk** is per-session. It evaluates the probability that the specific authentication event was performed by someone other than the legitimate account owner. Signals include impossible travel (a sign-in from New York followed by one from Tokyo 20 minutes later), anonymous IP addresses (Tor exit nodes, VPNs used to mask location), malware-linked IPs, and unfamiliar sign-in properties.

Risk is expressed in three levels: **Low**, **Medium**, and **High**. You configure your policies to trigger at a threshold — "Medium and above" or "High only" — and everything below that threshold passes through uninterrupted.

One thing that catches people off guard: not all detections are real-time. Some, particularly the offline detections like leaked credentials checks (which run against breach databases) and unfamiliar sign-in properties, can take up to 2 hours to surface. This means a sign-in can appear clean in real time and acquire a risk signal later. Your monitoring queries need to account for this lag.

## Prerequisites

Before you can use Identity Protection at all, one licensing requirement needs to be out of the way: you need **Azure AD Premium P2**. This is the part that frequently surprises people. Identity Protection is not available in P1. If you check the Identity Protection blade and the risk policies are greyed out or the risky users report is empty regardless of what is happening in your tenant, the license tier is almost certainly the reason.

You also need one of these Azure AD roles:
- **Global Administrator**
- **Security Administrator**
- **Security Reader** (for read-only access to the reports)

You can verify your current license assignments from PowerShell:

{% highlight posh %}
Connect-AzureAD
Get-AzureADSubscribedSku | Select-Object SkuPartNumber, ConsumedUnits, @{N="Available";E={$_.PrepaidUnits.Enabled - $_.ConsumedUnits}}
{% endhighlight %}

Look for `AAD_PREMIUM_P2` or `ENTERPRISEPREMIUM` in the output. If you only see `AAD_PREMIUM`, you're on P1 and the Identity Protection risk policies won't be available.

## Navigating to Identity Protection

Identity Protection lives at:

**Azure Active Directory > Security > Identity Protection**

The blade opens to a dashboard with an overview of your risk posture. Three reports form the core of the day-to-day workflow:

- **Risky users** — all users with an active risk state (At risk, Confirmed compromised, or Remediated). Each entry shows the risk level, when the risk was last updated, and what triggered it.
- **Risky sign-ins** — individual sign-in events with an associated risk score. Useful for investigating specific sessions.
- **Risk detections** — the raw detection events that feed into both of the above. This is where you see the specific detection type (leaked credentials, anonymous IP, impossible travel, etc.) and the timestamp.

The policy configuration is at the left side of the same blade: **User risk policy** and **Sign-in risk policy**.

## Configuring the Risk Policies

### User Risk Policy

The user risk policy defines what happens when Identity Protection flags a user's account as compromised at or above a threshold you set. Navigate to **Identity Protection > User risk policy** and configure as follows:

- **Assignments — Users**: All users, or a specific group if you want to pilot it first
- **Conditions — User risk**: Set the threshold to **High**. Starting at High reduces false positives — the Medium bucket catches more but also generates more noise from legitimate edge cases like users who travel frequently
- **Controls — Access**: Select **Allow access** and check **Require password change**. This is the SSPR trigger — the user is allowed to continue but must reset their password before proceeding
- **Enforce policy**: **On**

Why require password change instead of block? If you block on High user risk, a compromised account gets locked out, which is correct — but it also means the legitimate user can't recover without calling the helpdesk. With SSPR in the loop, the user can self-remediate immediately: prove their identity via the alternate authentication methods they registered, set a new password, and their risk state drops to Remediated automatically.

### Sign-in Risk Policy

The sign-in risk policy evaluates individual sessions. Navigate to **Identity Protection > Sign-in risk policy**:

- **Assignments — Users**: All users
- **Conditions — Sign-in risk**: **Medium and above**. Medium captures things like anonymous IP usage and unfamiliar sign-in properties — patterns that are suspicious enough to warrant a challenge but not certain enough to block outright
- **Controls — Access**: **Allow access** with **Require multi-factor authentication**
- **Enforce policy**: **On**

With this configuration, a sign-in from an anonymous IP triggers an MFA prompt. If the user completes MFA, Identity Protection treats it as a verified sign-in and the session proceeds. If they can't complete MFA — because an attacker is using stolen credentials but doesn't have access to the user's phone — the session is blocked at the MFA step.

### The Conditional Access Alternative

The built-in risk policies are the fast path. They work, but they offer limited flexibility — you can't apply exclusions, use report-only mode, or combine risk conditions with other signals like device compliance.

The recommended path in 2021 is to express the same logic in **Conditional Access policies**. From **Azure Active Directory > Security > Conditional Access**, you can create policies that target sign-in risk or user risk as a condition and configure any available control as the grant requirement. The advantage is full Conditional Access feature parity: named locations, device filters, report-only mode for baselining before enforcement, and the ability to exclude specific service accounts or break-glass accounts from the policy scope.

If you start with the built-in risk policies to get coverage quickly, plan to migrate the logic to Conditional Access as your configuration matures.

## Querying Risky Users via the Microsoft Graph API

The portal reports are useful for investigation, but if you want to automate responses, export data to a SIEM, or build a workflow around risk state changes, you need the Graph API.

In April 2021, the risky users endpoint is available at `https://graph.microsoft.com/v1.0/identityProtection/riskyUsers`. Here is how to query it from PowerShell using a bearer token from your authenticated Azure session:

{% highlight posh %}
# Connect to Azure AD and acquire a Graph token
Connect-AzureAD
$token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

# Get all users currently at risk
$response = Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers" `
    -Headers $headers `
    -Method GET

$response.value | Select-Object userPrincipalName, riskLevel, riskState, riskLastUpdatedDateTime
{% endhighlight %}

The `riskState` field tells you where each user stands in the remediation lifecycle. The values you'll see most often:

- `atRisk` — active risk, no action taken yet
- `confirmedCompromised` — an admin or automated process has confirmed the account was compromised
- `remediated` — the user completed a password reset via SSPR
- `dismissed` — an admin dismissed the risk (used for confirmed false positives)
- `none` — no active risk

To filter down to just High-risk users that are still active:

{% highlight posh %}
$response.value | Where-Object {
    $_.riskLevel -eq "high" -and $_.riskState -eq "atRisk"
} | Select-Object userPrincipalName, riskLastUpdatedDateTime
{% endhighlight %}

## Confirming and Dismissing Risk

Not every detection is a real compromise. A user who regularly signs in from a VPN will trigger unfamiliar sign-in properties detections. A red team exercise will generate detections that need to be cleaned up afterward. When you confirm a detection is a false positive, you dismiss the risk so it doesn't persist on the account.

{% highlight posh %}
# First, get the object ID of the user whose risk you want to dismiss
$user = Get-AzureADUser -UserPrincipalName "user@contoso.com"

# Dismiss user risk via the Graph API
$body = @{
    userIds = @($user.ObjectId)
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers/dismiss" `
    -Headers $headers `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
{% endhighlight %}

The opposite workflow — confirming that a user is genuinely compromised — is done through the `confirmCompromised` endpoint with the same payload structure. Confirming a compromise flags the account in your tenant's risk telemetry, which helps Microsoft improve the detection models across the platform.

## SSPR Integration: Closing the Remediation Loop

The user risk policy's "require password change" control only works if **Self-Service Password Reset** is enabled. Without SSPR, when Identity Protection flags a user and demands a password change, the user hits a wall — the policy requires an action they have no way to complete on their own. The result is a helpdesk call every time a user triggers the policy.

Enable SSPR at: **Azure Active Directory > Password reset**

Set the scope to **All** or a specific group, and configure at least two authentication methods. The methods registered under SSPR are the same ones users will use to prove their identity when Identity Protection triggers a password reset. If users haven't registered their SSPR methods, they can't self-remediate — which brings the helpdesk back into the loop and defeats the automation.

Before enabling the user risk policy in enforcement mode, verify that your SSPR registration campaign has been completed and that registration coverage is at an acceptable level. You can check this at **Azure Active Directory > Password reset > Registration**.

## Monitoring with KQL

Identity Protection events flow into Log Analytics alongside your other Azure AD data, as long as you've configured the Diagnostic Settings for Azure Active Directory (covered in detail in the [KQL for Security post](/log-analytics-kql-seguridad/)).

To see a breakdown of recent detections by type and severity:

{% highlight kql %}
AADUserRiskEvents
| where TimeGenerated > ago(7d)
| summarize count() by RiskEventType, RiskLevel
| sort by count_ desc
{% endhighlight %}

To track users currently at medium or high risk and how long they've been flagged:

{% highlight kql %}
AADRiskyUsers
| where TimeGenerated > ago(30d)
| where RiskLevel in ("high", "medium")
| project UserPrincipalName, RiskLevel, RiskState, RiskLastUpdatedDateTime
| sort by RiskLastUpdatedDateTime desc
{% endhighlight %}

The `AADUserRiskEvents` table gives you the raw detection events — useful for understanding which detection types are firing most frequently in your environment. If you're seeing a lot of `unfamiliarFeatures` or `anonymizedIPAddress` for a specific user population (say, your remote workforce on VPNs), that's a signal to review your named locations configuration in Conditional Access before those users start hitting friction from the sign-in risk policy.

One useful operational query: users who were at risk but have already self-remediated via SSPR, which confirms the automated loop is working:

{% highlight kql %}
AADRiskyUsers
| where TimeGenerated > ago(30d)
| where RiskState == "remediated"
| project UserPrincipalName, RiskLevel, RiskLastUpdatedDateTime
| sort by RiskLastUpdatedDateTime desc
{% endhighlight %}

A healthy Identity Protection deployment should show a steady flow of entries in that last query — risk events triggering the policy, users completing password resets, and risk states moving to `remediated` without manual intervention.

## Best Practices

A few things I've found worth noting from working with Identity Protection configurations:

**Start in Conditional Access, not the built-in policies.** The built-in user risk and sign-in risk policies ship you immediately to enforcement with limited configurability. Conditional Access gives you report-only mode, which lets you see how many users would have been impacted before you turn enforcement on. The extra setup time is worth it.

**Exclude break-glass accounts from risk policies.** Your emergency access accounts — the ones you'd use if your primary admin access is unavailable — should be excluded from both the user risk and sign-in risk policies. If Identity Protection locks those accounts, you may not be able to recover without support escalation. Exclude them by putting them in a named exclusion group in your Conditional Access policies.

**SSPR registration before enforcement.** Check your SSPR registration coverage before enabling the user risk policy. A realistic target is 90%+ of users registered before you go to enforcement. If you flip the policy on with 50% registration, the other 50% will generate helpdesk tickets the first time they're flagged.

**Review dismissed risks periodically.** Dismissals suppress a risk signal without remediating the underlying issue. If the same user accumulates multiple dismissed detections over time, that pattern is worth investigating even if each individual detection looked like a false positive.

**Correlate with MCAS if available.** Microsoft Cloud App Security (now Defender for Cloud Apps) sends session-level signals into Identity Protection for more granular sign-in risk scoring. If your organization is licensed for it, connecting MCAS to Azure AD adds detection types like impossible travel with higher accuracy than the base Identity Protection signals.

## Wrapping Up

Identity Protection is most powerful not as a standalone tool but as the detection layer that feeds your Conditional Access enforcement. The pattern is: Identity Protection detects the anomaly, assigns a risk level, the Conditional Access policy enforces the appropriate control (MFA for sign-in risk, password reset for user risk), and SSPR closes the remediation loop without a helpdesk ticket. For the most common identity attack patterns — credential stuffing, password spray, session hijacking — this covers you without manual intervention.

The KQL queries in the final section mean you can also pull everything into your Log Analytics workspace and build alerts, workbooks, or Sentinel detection rules on top of the same data. Once you've established a baseline of normal detection rates in your environment, a spike in `anonymizedIPAddress` or `leakedCredentials` detections becomes an alert worth acting on immediately.

From here, the logical next step is building Conditional Access policies that combine risk conditions with device compliance requirements — so that a risky sign-in from a managed device gets MFA while the same sign-in from an unmanaged device gets blocked entirely. But that's material for another post.

Happy scripting!
