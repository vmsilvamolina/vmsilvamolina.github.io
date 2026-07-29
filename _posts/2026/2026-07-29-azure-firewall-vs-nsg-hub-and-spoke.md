---
title: 'Azure Firewall vs NSGs: A Defense-in-Depth Security Model'
author: Victor Silva
date: 2026-07-29T21:56:26+00:00
layout: post
permalink: /azure-firewall-vs-nsg-hub-and-spoke/
excerpt: "NSGs and Azure Firewall stop different attacks. Here's the default-rule bypass that lets lateral movement and exfiltration slip past a hub firewall."
categories:
  - Security
  - Azure
tags:
  - Azure Firewall
  - NSG
  - Defense in Depth
  - Hub-and-Spoke
  - Lateral Movement
  - Terraform
  - DevSecOps
---

A single compromised VM in a spoke subnet doesn't need to reach the internet to be a problem. If it can reach every other VM in the same VNet by default, an attacker with a foothold has everything needed for lateral movement — internal reconnaissance, credential harvesting from adjacent hosts, staging data on a less-monitored host before exfiltration — and none of it will ever show up in your "centralized" Azure Firewall logs, because that traffic never leaves the subnet's local SDN fabric to reach the firewall in the first place.

That's the security gap this post is about. Azure Firewall and Network Security Groups (NSGs) get pitched as interchangeable — "we have a firewall in the hub, do we still need NSGs on the spokes?" — but they defend against different threat models. NSGs are the control that actually sees intra-VNet traffic, enforced inline at wire speed by the Azure network fabric on every packet, including the ones a centralized appliance never gets a chance to inspect. Azure Firewall is the control with FQDN awareness, threat intelligence feeds, and (on Premium) IDPS and TLS inspection — but only for traffic you've explicitly routed to it. Neither one covers the other's blind spot. I've seen teams strip NSGs because "the firewall handles it" and lose all visibility into lateral movement between VMs in the same VNet. I've seen the opposite mistake too: routing everything, including harmless spoke-to-spoke chatter, through the firewall, which doesn't buy any additional security for that traffic and just adds cost and latency.

This post covers the threat model each control actually addresses, the specific NSG default-rule behavior that silently defeats firewall-based egress governance, where Azure Firewall's security features (threat intelligence, IDPS, TLS inspection) earn their cost, and a Terraform implementation with the verification commands to prove your segmentation is enforcing what you think it is — not just what the diagram claims.

## Why Azure Firewall Doesn't Replace NSGs

Part of the confusion is that both controls can, in isolation, block the same packet. If you write a rule that says "deny TCP 3389 from the internet," you can express that as an NSG rule or as an Azure Firewall network rule, and both will work. That overlap at the edge case level is what makes people think they're interchangeable. They're not, because the overlap only exists for the narrow slice of traffic that both mechanisms actually see — and security decisions made on that narrow slice ignore the much larger volume of traffic only one of the two controls can observe.

NSGs are enforced by the Azure network fabric itself, at the vNIC and/or subnet level, inline, at wire speed, for every packet that crosses that boundary — including packets that never leave the VNet. Azure Firewall only sees traffic that is explicitly routed to it, which in a hub-and-spoke design means traffic that crosses a user-defined route (UDR) pointing at the firewall's private IP as the next hop. If a packet's path doesn't include that UDR — because it's VM-to-VM within the same subnet, or because the destination is covered by a longer-prefix system route that wins over your UDR — the firewall never sees it, full stop. No log entry, no rule evaluation, nothing.

Map that to an actual incident. A web-tier VM gets compromised — vulnerable dependency, leaked credential, doesn't matter how. The attacker's next move (MITRE ATT&CK T1021, Remote Services / internal lateral movement) is to probe the rest of the VNet: other VMs in the same subnet, the app tier one hop over, anything reachable. If your only control is a hub firewall and every subnet still carries the NSG default rules, that reconnaissance and lateral movement traffic is invisible to you — it never crosses the UDR boundary the firewall depends on. NSGs are the only control positioned to catch it, because they're the only control actually sitting on that traffic's path. That's not a theoretical gap; it's the single most common blind spot in hub-and-spoke deployments that treat the firewall as sufficient on its own.

## Architecture Overview: Where Each Control Actually Sits

Picture a standard hub-and-spoke layout:

```
                         ┌─────────────────────────────┐
                         │           Hub VNet            │
                         │  10.0.0.0/16                   │
                         │                                 │
                         │  ┌──────────────────────────┐  │
                         │  │   AzureFirewallSubnet     │  │
                         │  │   (10.0.1.0/26)           │  │
                         │  │   Azure Firewall Standard │  │
                         │  │   Firewall Policy         │  │
                         │  └──────────────────────────┘  │
                         └───────────┬─────────────────────┘
                                     │  VNet Peering
                    ┌────────────────┼────────────────┐
                    │                                  │
          ┌─────────▼──────────┐          ┌───────────▼─────────┐
          │   Spoke 1 (App)     │          │   Spoke 2 (Data)      │
          │   10.1.0.0/16       │          │   10.2.0.0/16          │
          │                      │          │                        │
          │  Web subnet          │          │  DB subnet              │
          │   10.1.1.0/24        │          │   10.2.1.0/24            │
          │   [NSG: web-tier]    │          │   [NSG: db-tier]          │
          │        │              │          │        ▲                  │
          │        ▼ (NSG allow)  │          │        │ (NSG allow)       │
          │  App subnet           │          │  Mgmt subnet              │
          │   10.1.2.0/24         │          │   10.2.2.0/24              │
          │   [NSG: app-tier]      │          │   [NSG: mgmt-tier]          │
          │   [UDR: 0.0.0.0/0→FW] │          │   [UDR: 0.0.0.0/0→FW]        │
          └───────────────────────┘          └────────────────────────────┘
```

Two things to notice in that diagram. First, every subnet has an NSG — that layer never goes away, regardless of what the firewall does. Second, the UDR pointing `0.0.0.0/0` at the firewall's private IP only governs what happens when traffic *leaves* the subnet toward a destination not covered by a more specific route. Traffic between the web subnet and the app subnet within Spoke 1 is intra-VNet — it's handled by Azure's own SDN routing between subnets in the same VNet, and unless you've added an explicit UDR for that specific spoke CIDR, it will never traverse the firewall. The NSGs on the web and app subnets are the *only* thing enforcing segmentation between those two tiers.

This is also precisely why Microsoft's own hub-and-spoke guidance recommends NSGs, not UDRs, for intra-VNet segmentation — trying to force every subnet-to-subnet flow through the firewall via UDRs is fragile and prone to accidentally capturing same-subnet traffic you never intended to route anywhere.

### The Division of Labor

| | NSG | Azure Firewall |
|---|---|---|
| Layer | L3/L4 (5-tuple) | L3–L7, FQDN, TLS inspection (Premium) |
| Enforcement point | Per-NIC / per-subnet, in the SDN fabric | Centralized in hub, only for routed traffic |
| Cost | Free (cost only from flow logs / Traffic Analytics) | ~$1.25–1.75/hr + $0.016/GB processed (confirm via Azure Pricing Calculator) |
| Latency | None — enforced inline | Adds a hop; noticeable at scale for chatty east-west traffic |
| FQDN / threat intel / IDPS | No | Yes |
| Scope | Distributed, per-workload | Centralized, cross-boundary |
| Good for | Microsegmentation within a spoke, tier-to-tier isolation | Egress allowlisting, ingress DNAT, cross-spoke and internet boundary inspection |

Neither row in that table is optional. The thesis of this post is simple: **Azure Firewall centralizes governance for traffic crossing a trust boundary — hub, internet, cross-spoke. NSGs are the free, zero-latency microsegmentation layer for everything that stays inside that boundary.** A mature hub-and-spoke design uses both, deliberately, not as a redundant belt-and-suspenders gesture but because each one covers a gap the other structurally cannot.

## The NSG Default Rule Bypass Gotcha: AllowVNetOutBound and AllowInternetOutBound

Here's the gotcha that catches almost everyone at least once. Every NSG you create, even an empty one with zero custom rules, ships with these default rules:

- **Inbound**: `AllowVNetInBound` (65000), `AllowAzureLoadBalancerInBound` (65001), `DenyAllInBound` (65500)
- **Outbound**: `AllowVNetOutBound` (65000), `AllowInternetOutBound` (65001), `DenyAllOutBound` (65500)

Read `AllowVNetOutBound` and `AllowInternetOutBound` again. Out of the box, before you've written a single custom rule, every subnet in every spoke can talk directly to every other subnet in the same VNet, and can reach the public internet directly. Both of those defaults sit at a lower priority number (evaluated first) than anything you'd typically add unless you explicitly override them.

Now overlay that onto a UDR-based firewall design. You've carefully built a `0.0.0.0/0 → Virtual Appliance → firewall private IP` route and attached it to your spoke's route table. You assume all outbound internet traffic from that spoke is now inspected by the firewall. But UDRs and NSGs are evaluated independently — a UDR controls *routing*, an NSG controls *whether the packet is allowed to leave the NIC in the first place*, and neither one is aware of the other's existence. If your route table is misapplied — wrong subnet association, a typo in the address prefix, or simply never attached because a new spoke subnet was provisioned outside your IaC pipeline — the `AllowInternetOutBound` default rule is still sitting there happily allowing traffic straight to the internet, completely bypassing the firewall, with no log entry anywhere in Azure Firewall telling you it happened.

This is, in practice, the single most common way organizations discover their "centralized" egress governance was never actually centralized — and it's exactly the kind of gap an attacker doesn't need to find through sophistication. A compromised host attempting command-and-control callback (MITRE ATT&CK T1071, Application Layer Protocol) or staging data for exfiltration (T1041) doesn't care whether your architecture diagram says traffic goes through the firewall; it only cares whether the packet leaves the NIC. A misapplied route table means it does, silently, with your threat intelligence feed and IDPS engine never getting a look at it.

The fix isn't exotic: add an explicit, higher-priority `Deny` rule for direct internet-bound traffic on any subnet that is supposed to be firewall-only, so a missing or broken UDR fails closed instead of failing open. Pair that with Azure Policy to deny subnet creation without a route table association, so the two controls reinforce each other instead of silently diverging.

## Prerequisites

Before implementing the pattern below, confirm you have:

- An Azure subscription with `Owner` or `Contributor` + `User Access Administrator` on the target subscription or resource groups
- Terraform ≥ 1.5 and the `azurerm` provider ≥ 3.90 (Firewall Policy resources have had several breaking changes across major versions — pin your provider)
- Azure CLI ≥ 2.60, authenticated (`az account show` to confirm the active subscription)
- An existing or planned hub VNet with room for a dedicated `/26` for `AzureFirewallSubnet`
- Familiarity with your organization's egress allowlist (FQDNs, ports) before you start writing Application Rules — retrofitting this after the fact is painful

Verify your CLI context before touching infrastructure:

{% highlight bash %}
az account show --query "{subscription:name, tenant:tenantId}" -o table
az provider show --namespace Microsoft.Network --query "registrationState"
{% endhighlight %}

## Implementing the Layered Model

### Step 1: NSGs for Microsegmentation (the layer you should never skip)

Start with the NSG layer regardless of whether the firewall exists yet. Every subnet gets its own NSG, deny-by-default beyond the explicit tier-to-tier rules you need. Here's a web-to-app tier example:

{% highlight hcl %}
resource "azurerm_network_security_group" "app_subnet_nsg" {
  name                = "nsg-spoke1-app"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
}

resource "azurerm_network_security_rule" "allow_web_to_app" {
  name                        = "Allow-Web-To-App-8443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8443"
  source_address_prefix       = "10.1.1.0/24"
  destination_address_prefix  = "10.1.2.0/24"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.app_subnet_nsg.name
}

resource "azurerm_network_security_rule" "deny_all_other_inbound" {
  name                        = "Deny-All-Other-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.app_subnet_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "app_subnet_assoc" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app_subnet_nsg.id
}
{% endhighlight %}

Priority `4096` for the explicit deny is deliberate — it sits below the default `DenyAllInBound` at 65500 but above any accidental low-priority allow rule someone adds later, giving you a documented, intentional deny that shows up clearly in `az network nic list-effective-nsg` output rather than relying on the default rule alone.

If this subnet is meant to be firewall-only for egress, also add the explicit outbound deny mentioned above:

{% highlight hcl %}
resource "azurerm_network_security_rule" "deny_direct_internet_outbound" {
  name                        = "Deny-Direct-Internet-Outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.1.2.0/24"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.app_subnet_nsg.name
}
{% endhighlight %}

Now a broken or missing UDR fails closed — the app tier simply loses internet connectivity entirely instead of silently routing around the firewall.

### Step 2: AzureFirewallSubnet Requirements and Routing Spoke Traffic to the Hub

The `AzureFirewallSubnet` has hard constraints: it must be named exactly `AzureFirewallSubnet`, must be at least a `/26`, and cannot have an NSG attached — Azure blocks this at the platform level "to prevent service interruptions," since the firewall provides its own protection. If you're on the Basic SKU, you also need a separate `AzureFirewallManagementSubnet` (also `/26`); Standard and Premium only need that management subnet if you're using forced tunneling.

For each spoke, build a route table that sends default traffic to the firewall's private IP, plus explicit routes for spoke-to-spoke CIDRs if you actually want that traffic inspected:

{% highlight hcl %}
resource "azurerm_route_table" "spoke_rt" {
  name                = "rt-spoke1-default"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "default-route-to-fw"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "spoke_to_spoke" {
  name                   = "spoke2-via-fw"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_rt.name
  address_prefix         = "10.2.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.hub_fw.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "app_subnet_rt_assoc" {
  subnet_id      = azurerm_subnet.app.id
  route_table_id = azurerm_route_table.spoke_rt.id
}
{% endhighlight %}

Notice the `0.0.0.0/0` route alone does *not* cover spoke-to-spoke traffic — RFC1918 space isn't matched by a default route in the way you might assume, so if you actually want Spoke 1 → Spoke 2 traffic inspected by the firewall, you need the explicit `10.2.0.0/16` route too. This is also exactly the decision point where you should stop and ask: does this specific spoke-to-spoke flow actually need firewall inspection, or is it two microservices in the same trust domain that would be better served by NSG rules alone? More on that tradeoff below.

### Step 3: Deploying Firewall Policy with Terraform (azurerm_firewall_policy)

Use `azurerm_firewall_policy` and `azurerm_firewall_policy_rule_collection_group` rather than the legacy classic rule collections directly on `azurerm_firewall` — Policy is the only path that supports Firewall Manager hierarchy (base policies inherited across multiple child policies), and it's what current Microsoft guidance recommends for anything new.

{% highlight hcl %}
resource "azurerm_firewall_policy" "hub_policy" {
  name                     = "fwpolicy-hub-prod"
  resource_group_name      = azurerm_resource_group.hub.name
  location                 = azurerm_resource_group.hub.location
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
}

resource "azurerm_firewall_policy_rule_collection_group" "egress_allowlist" {
  name               = "rcg-egress-allowlist"
  firewall_policy_id = azurerm_firewall_policy.hub_policy.id
  priority           = 500

  application_rule_collection {
    name     = "allow-approved-fqdns"
    priority = 100
    action   = "Allow"

    rule {
      name = "allow-microsoft-updates"
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.update.microsoft.com",
        "*.windowsupdate.com"
      ]
      source_addresses = ["10.1.0.0/16"]
    }
  }

  network_rule_collection {
    name     = "allow-dns-ntp"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["10.1.0.0/16"]
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }
  }
}
{% endhighlight %}

Two details worth internalizing here. First, rule evaluation order inside the firewall is fixed regardless of how you organize collections: DNAT rules, then Network rules, then Application rules, first match wins, all terminating. Design your rule collection priorities with that fixed order in mind rather than fighting it. Second, wildcard FQDNs are stricter than they look — `*.contoso.com` does **not** match bare `contoso.com`; if you need both you add both explicitly. And a left-anchored wildcard like `*contoso.com` (no leading dot) will also match lookalike domains such as `th3re4lcontoso.com`, which is a subtle way to accidentally widen an allowlist you thought was tight.

#### FQDN Allowlisting for Outbound Traffic

The equivalent as an imperative CLI call, useful for ad hoc changes or scripting outside Terraform state:

{% highlight bash %}
az network firewall policy rule-collection-group collection add-filter-collection \
  --collection-priority 100 \
  --name allow-approved-fqdns \
  --policy-name fwpolicy-hub-prod \
  --resource-group rg-hub \
  --rule-collection-group-name rcg-egress-allowlist \
  --rule-name allow-microsoft-updates \
  --rule-type ApplicationRule \
  --action Allow \
  --collection-name allow-approved-fqdns \
  --target-fqdns "*.update.microsoft.com" "*.windowsupdate.com" \
  --source-addresses "10.1.0.0/16" \
  --protocols Https=443
{% endhighlight %}

If you're using FQDN-based network rules (not just application rules), make sure the Firewall's DNS proxy is enabled and your spoke VNets are actually pointed at the firewall's private IP for DNS resolution. Without that, the firewall resolves the FQDN one way for its rule matching and the client resolves it another way for the actual connection — a mismatch that manifests as traffic getting blocked (or allowed) in ways that don't match your rule intent.

### Step 4: SNAT Port Exhaustion and NAT Gateway Scaling

Azure Firewall SNATs outbound traffic to public IPs only — it doesn't SNAT RFC1918 or RFC6598 destinations. Each backend instance gets roughly 2,496 SNAT ports per configured public IP. For high-connection-count workloads (think: a fleet of VMs making many outbound HTTPS calls per second), that pool exhausts faster than people expect. Pairing the firewall's public IP configuration with a NAT Gateway (use the StandardV2 SKU if your firewall is zone-redundant) scales you up to roughly 64,512 ports per IP. One caveat: NAT Gateway isn't supported when the firewall is deployed as a Secured Virtual Hub in Virtual WAN, so factor that into your topology choice early — retrofitting is disruptive.

## Where Azure Firewall's Security Features Earn Their Cost: Threat Intelligence, IDPS, TLS Inspection

This is the part of the comparison that NSGs simply cannot participate in, at any SKU, and it's where Azure Firewall's cost stops being a networking line item and starts being a security control in its own right.

**Threat intelligence-based filtering** cross-references every session against Microsoft's threat intelligence feed of known-malicious IPs and domains, updated continuously. Set `threat_intelligence_mode` to `Deny` (as in the Terraform example above) and the firewall drops the connection before it completes — this is Basic SKU's biggest limitation: Basic can only alert on threat intel matches, not block them, so if a compliance requirement or your own risk tolerance demands blocking known-malicious destinations outright, Basic SKU is not sufficient regardless of the cost savings. There is no NSG equivalent to this at all — an NSG has no concept of reputation, only static IP/port rules you maintain yourself.

**IDPS (Intrusion Detection and Prevention System)**, available on Standard (detection/alert only) and Premium (detection and prevention), inspects payloads against a signature ruleset for known exploit patterns, not just the 5-tuple. This is the layer that catches an attacker exploiting a vulnerable service on a port your NSG rules correctly allow — NSGs validate that a connection *should* be permitted by policy, they say nothing about what's actually inside the payload once it's allowed through.

**TLS inspection (Premium only)** terminates and re-establishes outbound TLS sessions so the firewall can apply application rules, IDPS, and URL filtering to encrypted traffic instead of blindly forwarding it based on SNI alone. Without TLS inspection, an attacker exfiltrating data over HTTPS to an allowed FQDN — or abusing a legitimate SaaS domain your allowlist already permits — is invisible to payload-level inspection. This is also the feature with the highest operational cost: it requires distributing a trusted CA certificate to every client that needs to trust the re-signed sessions, and it has real compliance implications (some regulated workloads explicitly prohibit TLS interception) that are worth raising with your compliance team before enabling it, not after.

None of this replaces NSGs — TLS inspection and IDPS only apply to traffic that's already been routed to the firewall, so a same-subnet lateral movement attempt still sails past all three of these features untouched. But it's the honest answer to "why pay for Premium" and it's worth being specific about, since teams often either skip Premium entirely without understanding what they're giving up, or enable it everywhere without accounting for the certificate distribution and compliance overhead.

## The Cost and Latency Tradeoff of Hub-Centric Spoke-to-Spoke Traffic

This is where the architecture decision actually earns its keep. It's tempting, especially early in a hub-and-spoke build-out, to route every single subnet's traffic — including all spoke-to-spoke traffic — through the firewall by default. It feels safer: "everything gets inspected." In practice this is usually the wrong default for two concrete reasons.

**Cost.** Azure Firewall bills on data processed, roughly $0.016/GB on Standard and Premium on top of the hourly SKU charge (treat these as directional — confirm current numbers on the Azure Pricing Calculator, Microsoft's public pricing page has historically shown placeholder values). NSGs, by contrast, cost nothing to enforce — you only pay if you turn on flow logs or Traffic Analytics for observability. If two services in adjacent spokes exchange high-volume internal API traffic, database replication, or bulk data transfer, routing all of that through the firewall for inspection adds a real, ongoing data-processing bill for traffic that never crosses your actual trust boundary.

**Latency.** Every packet forced through the firewall takes an extra hop and gets processed by a stateful L3-L7 inspection engine before continuing to its destination. For chatty microservice-to-microservice communication, especially synchronous request/response patterns, that added latency compounds. NSGs, being enforced inline in the SDN fabric at wire speed, add effectively zero latency.

The better default: reserve firewall inspection for traffic that actually crosses a trust boundary — hub-to-internet, internet-to-hub (via DNAT), and cross-spoke traffic where the spokes genuinely belong to different trust domains (e.g., a shared-services spoke talking to a regulated workload spoke). For spoke-to-spoke traffic where both spokes are effectively the same trust domain split for organizational or blast-radius reasons, let VNet peering handle the transport directly and use NSGs (or, at scale, Azure Virtual Network Manager security admin rules, which are evaluated before any local NSG and centrally enforced across many VNets) to govern it. You get the segmentation without the extra hop or the processing bill.

## Validating the Setup: list-effective-nsg and show-effective-route-table

Don't take the architecture on faith — verify what's actually happening on the wire.

Confirm the effective NSG rules on a given NIC (this merges subnet-level and NIC-level NSGs and shows you what's really being enforced, not just what you think you deployed):

{% highlight bash %}
az network nic list-effective-nsg \
  --name nic-app-vm01 \
  --resource-group rg-spoke1
{% endhighlight %}

Confirm the effective route table — this is the single most important check after any UDR change, because it tells you what Azure is actually using, not what your route table object says in isolation:

{% highlight bash %}
az network nic show-effective-route-table \
  --name nic-app-vm01 \
  --resource-group rg-spoke1
{% endhighlight %}

Enable diagnostic settings on the firewall and send Network and Application rule logs to Log Analytics, then confirm expected traffic is actually arriving:

{% highlight bash %}
az monitor diagnostic-settings create \
  --name diag-hub-fw \
  --resource $(az network firewall show -g rg-hub -n hub-fw --query id -o tsv) \
  --workspace $(az monitor log-analytics workspace show -g rg-hub -n law-hub --query id -o tsv) \
  --logs '[{"category":"AzureFirewallNetworkRule","enabled":true},{"category":"AzureFirewallApplicationRule","enabled":true}]'
{% endhighlight %}

From a spoke test VM, confirm a blocked FQDN actually fails at the connection level, not just times out ambiguously:

{% highlight bash %}
curl -v https://blocked-example.com
{% endhighlight %}

You should see a TLS handshake failure or connection reset if your application rule deny is in effect and doing its job.

Here's the check people skip and shouldn't: confirm that same-subnet VM-to-VM traffic does **not** show up in the firewall's logs at all. If you see it there, something is misconfigured — you've accidentally routed intra-subnet traffic through the firewall. If you don't see it, that's expected and correct; it validates that your NSG-only microsegmentation is doing exactly what it's supposed to, invisibly, at wire speed, without the firewall in the loop.

Finally, since Terraform applies can silently reorder rule collection priorities across state refreshes if you're not pinning them explicitly, periodically diff what's actually deployed against intent:

{% highlight bash %}
az network firewall policy rule-collection-group list \
  --policy-name fwpolicy-hub-prod \
  --resource-group rg-hub \
  --query "[].{name:name, priority:priority}" \
  -o table
{% endhighlight %}

## Common Misconfigurations: Missing UDRs and Asymmetric Routing

A few hard-earned observations from building and auditing these environments:

**Fail closed on egress.** Don't rely on the UDR alone to guarantee firewall inspection. Pair every firewall-mandatory subnet with an explicit NSG deny for direct internet-bound traffic, so a missing or misapplied route table breaks connectivity loudly instead of quietly routing around your governance.

**Guard against missing route tables with policy, not process.** A new spoke subnet provisioned without its route table association is the single most common way teams discover, after the fact, that traffic bypassed the firewall. Use an Azure Policy `deny` or `deployIfNotExists` effect to enforce route table association on subnet creation, or manage the association centrally with Azure Virtual Network Manager so it can't drift. See [Enforcing Azure RBAC Guardrails with Azure Policy]({% link _posts/2024/2024-01-15-azure-rbac-guardrails-azure-policy.md %}) for the same deny-effect pattern applied to a different guardrail.

**Watch for asymmetric routing.** A UDR forcing outbound traffic through the firewall doesn't guarantee the return path follows the same route — routes propagated via ExpressRoute or VPN gateways can pull return traffic around the firewall entirely, breaking the stateful connection tracking the firewall relies on. Validate both directions, not just egress.

**Never try to attach an NSG to `AzureFirewallSubnet`.** It's unsupported and will fail — the platform manages protection for that subnet itself.

**Manage NSG sprawl at scale, don't just hope it stays consistent.** Dozens of spokes each with several NSGs drifts fast. `deployIfNotExists` Azure Policies for NSG association, Azure Virtual Network Manager security admin rules for org-wide guardrails that are evaluated before any local NSG, and periodic `az network nic list-effective-nsg` audits keep this honest.

## NSG Flow Logs Retirement (2027): Migrating to VNet Flow Logs

Microsoft has announced retirement of NSG Flow Logs for September 30, 2027, and new NSG flow logs could not be created after June 30, 2025. Anything you're deploying or writing in 2026 should use VNet Flow Logs via Network Watcher instead — don't build new observability on a deprecating feature.

**Pin your rule collection priorities explicitly in Terraform** rather than letting implicit ordering emerge from resource declaration order — this is exactly the kind of thing that silently reorders across applies and creates a gap between your intended DNAT → Network → Application evaluation order and what's actually deployed.

## Mapping This to Your Compliance and Zero Trust Posture

If you're tracking CIS Microsoft Azure Foundations Benchmark controls, this two-layer model isn't just good practice, it's what the controls actually expect:

- **NSG rules restricting RDP/SSH exposure to `Any`** map to NIST SP 800-53 **SC-7 (Boundary Protection)** and **AC-4 (Information Flow Enforcement)** — and SC-7 is explicit about enforcing boundaries at *internal* segments, not just the network perimeter, which is precisely the case for microsegmentation NSGs make and a perimeter-only firewall cannot.
- **Threat intelligence-based deny and IDPS** map to **SI-4 (System Monitoring)** — the requirement to detect indicators of compromise and known attack signatures, which is functionally what those Azure Firewall Premium features do.
- **VNet Flow Logs / effective-route audits** map to **AU-2/AU-12 (Audit Events / Audit Generation)** — you need to be able to reconstruct what actually happened on the network, not just what your Terraform said should happen.

This is also the practical shape of a Zero Trust argument for this architecture: Zero Trust doesn't mean "no perimeter," it means "verify explicitly, everywhere, not just at the edge." A hub firewall alone gives you edge verification. NSGs extend that verification to every internal segment boundary, which is the part of Zero Trust that a perimeter-only design structurally can't deliver — no matter how good the perimeter control is.

## Wrapping Up

The question "do we need NSGs if we have Azure Firewall" has a clean answer once you separate the threat model each control actually addresses. NSGs are enforced inline, at wire speed, for free, on every packet that crosses a NIC or subnet boundary — including lateral movement and reconnaissance traffic that never leaves the VNet and that a hub firewall structurally cannot see. Azure Firewall's value is different and complementary: threat intelligence, IDPS, TLS inspection, and FQDN-based governance for traffic that crosses an actual trust boundary — into or out of the internet, or between spokes that don't share a trust domain.

Treating the firewall as a replacement for NSGs leaves same-subnet and unrouted intra-VNet traffic — exactly the traffic an attacker who's already landed a foothold will generate — completely unmonitored. Treating NSGs as a replacement for the firewall leaves you with no FQDN awareness, no threat intelligence, and no centralized egress governance against C2 and exfiltration. And routing everything through the hub regardless of whether it crosses a real boundary just burns budget and adds latency without covering any additional threat.

Build both layers deliberately, and validate them the way you'd validate any other security control: don't trust the diagram, trust `list-effective-nsg` and `show-effective-route-table` output, and confirm your firewall logs show exactly the traffic they should — no more, no less. That's the difference between an architecture that looks secure and one an attacker actually has to work for.

Happy scripting!
