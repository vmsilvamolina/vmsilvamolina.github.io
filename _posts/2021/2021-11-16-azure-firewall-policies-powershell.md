---
title: "Azure Firewall: managing policies and rules with PowerShell"
author: Victor Silva
date: 2021-11-16T11:08:43+00:00
layout: post
permalink: /azure-firewall-policies-powershell/
excerpt: "How to deploy and manage Azure Firewall policies, DNAT rules, network rules, and application rules using PowerShell — and why Firewall Policy is the right approach over classic rules."
categories:
  - Azure
  - Security
tags:
  - Azure
  - Azure Firewall
  - Security
  - PowerShell
  - Networking
---

When you stand up Azure Firewall for the first time, the portal makes it very easy to start clicking rules into place. A DNAT rule here, a network rule collection there, and you're up and running in twenty minutes. That works fine for a proof of concept, but it falls apart the moment you need to replicate the same configuration across a dev, staging, and production firewall, roll back a change that broke something at 2 AM, or onboard a second team that needs to add their own application rules without touching yours.

The issue with managing rules directly on the firewall — the classic approach — is that the firewall itself becomes the source of truth. There's no version history, no way to share a baseline across multiple firewalls, and no clean separation between a platform team's core rules and a workload team's application-specific rules. Every change is manual, every environment drifts, and audits are painful.

Azure Firewall Policy, which reached GA in March 2020, solves exactly this problem. A policy is a standalone Azure resource that holds all your rule collections. You associate one policy with one or more firewalls, manage the policy in code, and the firewalls just enforce whatever the policy says. In this post I'll walk through the policy hierarchy, then build the full rule set — DNAT, network, and application rules — using PowerShell from scratch. By the end you'll have a scriptable baseline you can store in git and deploy consistently across every environment.

## Understanding the Firewall Policy Hierarchy

Before writing a single line of PowerShell, it's worth being precise about the object model, because the hierarchy directly affects how priority and evaluation work.

Azure Firewall Policy has four levels:

**Policy** is the top-level container. It holds global settings like threat intelligence mode, DNS configuration, and a reference to a parent policy (more on that in a moment). You associate a policy with one or more firewalls, and those firewalls enforce everything the policy defines.

**Rule Collection Group** is the first level of organization inside a policy. Each group has a priority (100–65000, lower number = higher priority). Groups are evaluated in priority order, and the first matching rule anywhere in the evaluation wins — processing stops there.

**Rule Collection** lives inside a group. Each collection has its own priority and an action type: Allow or Deny (for network and application rules) or DNAT (for inbound translation). All rules within a collection must be the same type — you can't mix network rules and application rules in the same collection.

**Rule** is the individual entry: a specific protocol, source, destination, and port combination.

The evaluation order matters: group priority is checked first, then collection priority within that group, then rules within a collection are evaluated top to bottom. If a rule collection group with priority 100 has a Deny collection, it will be evaluated before anything in a group with priority 200 — regardless of what that group contains.

One more concept worth understanding: **parent policies**. A policy can reference another policy as its parent. The child inherits all the parent's rules, and the parent's rules take precedence over the child's. This is exactly what you'd use to have a central platform team publish a base policy (with corporate DNS, threat intelligence settings, and essential network rules) that workload teams extend with their own child policies — without being able to override the platform controls.

## Prerequisites

You'll need the Az PowerShell module installed and a connection to your Azure subscription:

{% highlight posh %}
# Install the Az module if not already present
Install-Module -Name Az -Scope CurrentUser -Force

# Connect to Azure
Connect-AzAccount

# Set the target subscription
Set-AzContext -SubscriptionId "<your-subscription-id>"
{% endhighlight %}

Verify the Az.Network module is available — all the Firewall Policy cmdlets live there:

{% highlight posh %}
Get-Module -Name Az.Network -ListAvailable | Select-Object Name, Version
{% endhighlight %}

You'll also need an existing resource group and, for the association step at the end, an existing Azure Firewall. The firewall itself and its public IP are not covered in this post — the focus is the policy and rules.

## Creating the Firewall Policy

Let's start with the policy itself. A few variables up front keep the rest of the script clean:

{% highlight posh %}
# Variables
$resourceGroup = "rg-network-security"
$location      = "eastus"
$policyName    = "fw-policy-prod"

# Create the Firewall Policy
$fwPolicy = New-AzFirewallPolicy `
    -Name $policyName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -ThreatIntelMode "Alert"

Write-Host "Firewall Policy created: $($fwPolicy.Name)"
{% endhighlight %}

The `-ThreatIntelMode` parameter controls how the firewall handles traffic matching Microsoft's threat intelligence feed — a continuously updated list of known malicious IP addresses and FQDNs. Setting it to `Alert` means matching traffic is logged but not blocked; it's a safe starting point that lets you validate no legitimate traffic is being flagged before you flip to `Deny`. We'll update this later.

## Adding DNAT Rules for Inbound Traffic

DNAT rules handle inbound traffic destined for the firewall's public IP. The firewall translates the destination to an internal address and forwards the packet. This is the standard pattern for exposing a service behind the firewall without assigning a public IP directly to the resource.

{% highlight posh %}
# Create a DNAT rule (translate inbound HTTP to an internal VM)
$dnatRule = New-AzFirewallPolicyNatRule `
    -Name "allow-http-inbound" `
    -Protocol "TCP" `
    -SourceAddress "*" `
    -DestinationAddress "20.x.x.x" `
    -DestinationPort "80" `
    -TranslatedAddress "10.0.1.4" `
    -TranslatedPort "80"

# Wrap it in a rule collection
$dnatCollection = New-AzFirewallPolicyNatRuleCollection `
    -Name "dnat-inbound-web" `
    -Priority 100 `
    -Rule $dnatRule

# Create a Rule Collection Group and attach it to the policy
$dnatRCG = New-AzFirewallPolicyRuleCollectionGroup `
    -Name "rcg-inbound" `
    -Priority 200 `
    -RuleCollection $dnatCollection `
    -FirewallPolicyObject $fwPolicy

Write-Host "DNAT rule collection group created"
{% endhighlight %}

Replace `20.x.x.x` with the actual public IP of your Azure Firewall and `10.0.1.4` with the private IP of the target resource. The `-DestinationAddress` on a DNAT rule is the firewall's public IP, not the destination you want to reach — this is the most common point of confusion when writing DNAT rules for the first time.

## Adding Network Rules

Network rules operate at layer 4: they match on protocol, source IP, destination IP, and destination port. They don't inspect the payload. Use them for traffic that doesn't need FQDN resolution or TLS inspection.

{% highlight posh %}
# Allow DNS outbound from the VNet to Azure's internal DNS
$dnsRule = New-AzFirewallPolicyNetworkRule `
    -Name "allow-dns-outbound" `
    -Protocol "UDP" `
    -SourceAddress "10.0.0.0/16" `
    -DestinationAddress "168.63.129.16" `
    -DestinationPort "53"

# Allow HTTPS outbound from the VNet to any destination
$httpsRule = New-AzFirewallPolicyNetworkRule `
    -Name "allow-https-outbound" `
    -Protocol "TCP" `
    -SourceAddress "10.0.0.0/16" `
    -DestinationAddress "*" `
    -DestinationPort "443"

# Group both rules into a single Allow collection
$networkCollection = New-AzFirewallPolicyFilterRuleCollection `
    -Name "network-rules-outbound" `
    -Priority 100 `
    -Rule @($dnsRule, $httpsRule) `
    -ActionType "Allow"

$networkRCG = New-AzFirewallPolicyRuleCollectionGroup `
    -Name "rcg-network-outbound" `
    -Priority 300 `
    -RuleCollection $networkCollection `
    -FirewallPolicyObject $fwPolicy

Write-Host "Network rule collection group created"
{% endhighlight %}

The DNS rule targets `168.63.129.16`, which is Azure's virtual IP for platform services including the internal DNS resolver. If your VMs are configured to use this address for DNS — which is the default for Azure VNets — this rule ensures they can reach it through the firewall when a forced-tunnel or custom route table is in play.

## Adding Application Rules

Application rules operate at layer 7 and match on FQDN. The firewall performs DNS resolution and matches the resolved IP against the rule. This is the right tool for controlling which external services your workloads can reach by name rather than by IP.

{% highlight posh %}
# Allow Windows Update FQDNs from the VNet
$windowsUpdateRule = New-AzFirewallPolicyApplicationRule `
    -Name "allow-windows-update" `
    -SourceAddress "10.0.0.0/16" `
    -Protocol "https:443" `
    -TargetFqdn @(
        "*.update.microsoft.com",
        "*.windowsupdate.com",
        "*.download.windowsupdate.com"
    )

# Allow access to Azure management endpoints
$azureManagementRule = New-AzFirewallPolicyApplicationRule `
    -Name "allow-azure-management" `
    -SourceAddress "10.0.0.0/16" `
    -Protocol "https:443" `
    -TargetFqdn @(
        "management.azure.com",
        "login.microsoftonline.com"
    )

$appCollection = New-AzFirewallPolicyFilterRuleCollection `
    -Name "app-rules-outbound" `
    -Priority 100 `
    -Rule @($windowsUpdateRule, $azureManagementRule) `
    -ActionType "Allow"

$appRCG = New-AzFirewallPolicyRuleCollectionGroup `
    -Name "rcg-application-rules" `
    -Priority 400 `
    -RuleCollection $appCollection `
    -FirewallPolicyObject $fwPolicy

Write-Host "Application rule collection group created"
{% endhighlight %}

Notice that FQDN-based application rules require the firewall to have DNS configured — either the default Azure DNS or a custom DNS proxy setting on the policy. For most environments the defaults work, but if you're using a custom DNS server you'll need to enable the DNS proxy setting on the policy so the firewall can resolve the FQDNs in your rules.

Also worth noting: Azure Firewall ships with built-in FQDN tags for common services — `WindowsUpdate`, `AzureBackup`, `HDInsight`, and others. Instead of enumerating individual FQDNs for Windows Update, you could use the `WindowsUpdate` FQDN tag and let Microsoft keep that list current. The explicit approach above is useful when you need to be precise about exactly which domains are allowed; the FQDN tag approach is easier to maintain for well-known services.

## Associating the Policy with an Azure Firewall

Once the policy and all its rule collection groups are in place, associate it with your firewall:

{% highlight posh %}
# Retrieve the existing firewall
$firewall = Get-AzFirewall -Name "fw-prod" -ResourceGroupName $resourceGroup

# Set the policy reference on the firewall object
$firewall.FirewallPolicy = @{ Id = $fwPolicy.Id }

# Push the update back to Azure
Set-AzFirewall -AzureFirewall $firewall

Write-Host "Policy associated to firewall: $($firewall.Name)"
{% endhighlight %}

After `Set-AzFirewall` completes, the firewall begins enforcing the rules from the policy. The association takes effect within a few minutes — the firewall doesn't restart, but there's a propagation delay while Azure pushes the updated configuration to the firewall instances.

If you're migrating a firewall from classic rules to a policy-based configuration, be aware that a firewall associated with a policy can no longer have classic rules. The migration is one-way: once you associate a policy, the classic rules are removed and management goes through the policy exclusively.

## Tightening Threat Intelligence

Starting with `Alert` mode is sensible for an initial deployment, but once you've confirmed your firewall isn't flagging legitimate traffic, switch threat intelligence to `Deny`:

{% highlight posh %}
# Retrieve the policy and update the threat intelligence mode
$fwPolicy = Get-AzFirewallPolicy `
    -Name $policyName `
    -ResourceGroupName $resourceGroup

$fwPolicy.ThreatIntelMode = "Deny"

Set-AzFirewallPolicy -InputObject $fwPolicy

Write-Host "Threat intelligence mode updated to Deny"
{% endhighlight %}

With `Deny` active, the firewall silently drops traffic to or from addresses and FQDNs in the threat intelligence feed and logs the match. This provides meaningful protection with zero rule authoring effort — Microsoft maintains the feed, you just set the mode.

The three modes to know:

- **Off** — threat intelligence filtering is disabled
- **Alert** — matching traffic is allowed and logged; useful during validation
- **Deny** — matching traffic is blocked and logged; appropriate for production

## Validating with Firewall Logs

Azure Firewall writes diagnostic logs to Log Analytics when you enable the diagnostic setting. Once that's in place, KQL gives you a clear view of what the firewall is actually doing with traffic.

To see what has been denied by network rules in the last hour:

{% highlight kql %}
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated > ago(1h)
| where msg_s contains "Deny"
| project TimeGenerated, msg_s
| sort by TimeGenerated desc
{% endhighlight %}

To summarize denied inbound attempts by source IP — useful for spotting scanning activity:

{% highlight kql %}
AzureDiagnostics
| where Category == "AzureFirewallNetworkRule"
| where TimeGenerated > ago(1h)
| where msg_s contains "Deny"
| extend Parts = split(msg_s, " ")
| extend SourceIP = tostring(Parts[3])
| summarize DeniedAttempts = count() by SourceIP
| sort by DeniedAttempts desc
{% endhighlight %}

To check application rule denials over the past 24 hours:

{% highlight kql %}
AzureDiagnostics
| where Category == "AzureFirewallApplicationRule"
| where TimeGenerated > ago(24h)
| where msg_s contains "Deny"
| project TimeGenerated, msg_s
| sort by TimeGenerated desc
{% endhighlight %}

Run these queries immediately after associating the policy to confirm rules are matching what you expect. If traffic that should be allowed is showing up as denied, the rule hierarchy is the first place to look — a Deny collection with a lower priority number in a higher-priority group will shadow an Allow in a lower-priority group.

## Best Practices

A few observations from working with Firewall Policy at scale:

**One rule collection group per concern, not per team.** It's tempting to give each workload team their own group, but group count is limited and priorities can collide. A better model is to use groups to separate inbound (DNAT), network (layer 4), and application (layer 7) traffic, and use multiple rule collections within each group to separate workloads.

**Keep the base policy minimal.** If you're using parent-child policies, the parent should hold only the rules that must apply everywhere: threat intelligence mode, corporate DNS, and a small set of always-deny rules for high-risk destinations. Everything workload-specific belongs in child policies.

**Name rule collections descriptively.** `rcg-inbound` and `network-rules-outbound` are readable six months later. `RCG1` and `collection3` are not. Firewall rules are among the most dangerous things to get wrong, and readable names reduce the chance of misinterpreting a rule during an incident.

**Store the policy script in git and deploy it via a pipeline.** A PowerShell script in a repository with a CI/CD pipeline is a minimal but effective form of policy-as-code. Changes go through pull request review, the history is auditable, and rollback is a revert away.

**Test DNAT rules before going live.** DNAT rules that translate incorrectly can expose internal resources in unexpected ways. After creating a DNAT rule, verify the translation is working as intended and that traffic not matching the rule is not reaching the internal resource through any other path.

## Closing Thoughts

Azure Firewall Policy turns what would otherwise be a collection of manually managed portal configurations into a versioned, auditable, scriptable resource. The hierarchy — policy, rule collection group, rule collection, rule — takes a few minutes to internalize, but once it clicks, it's a natural way to organize network security rules at any scale. And because the policy is a standalone resource, you can create it, test it, peer review it, and associate it to a firewall in a single coordinated step rather than editing a live firewall rule by rule.

From here, the next logical step is combining this with Azure Policy to enforce that every firewall in your subscription is associated with a compliant Firewall Policy — closing the loop between what your scripts deploy and what actually runs in production.

Happy scripting!
