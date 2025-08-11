---
title: 'GCP Chronicle SIEM Detection Rules with YARA-L 2.0'
author: Victor Silva
date: 2025-08-11T10:00:00+00:00
layout: post
permalink: /gcp-chronicle-siem-detection-rules/
excerpt: "Raw GCP audit logs don't surface threats alone. This post builds Chronicle SIEM detection rules in YARA-L 2.0 for IAM escalation, Secret Manager access, and open firewall creation."
categories:
  - GCP
  - Security
tags:
  - GCP
  - Chronicle SIEM
  - YARA-L 2.0
  - Detection Engineering
  - Chronicle detection engineering
  - GCP SIEM
  - Cloud Audit Logs
  - Security
---

When working with GCP at any meaningful scale, you quickly realize that logs are not your problem — you have plenty of them. Cloud Audit Logs capture every IAM mutation, every API call to Secret Manager, every VPC firewall change. VPC Flow Logs record every accepted and rejected connection. Cloud Armor logs tell you what traffic was blocked at the edge. The problem is that none of those logs, on their own, will tell you that something is wrong. A single `SetIamPolicy` event binding `roles/owner` to an external email address looks exactly like a routine administrative change unless something correlates it, evaluates it against a policy, and raises an alert.

That gap between raw log data and actionable detection is where a SIEM lives. GCP's native answer is Chronicle — a petabyte-scale security analytics platform built on Google's infrastructure, with a normalized data model and a purpose-built detection rule language called YARA-L 2.0. This post covers the full path: ingesting GCP logs into Chronicle, understanding the Unified Data Model (UDM) that normalizes those logs, and writing three concrete detection rules that cover the most common GCP security incidents.

## What Chronicle Is and How It Differs

Chronicle started as an internal Google project called Backstory before becoming a generally available GCP service. It is not a log aggregation tool with a search UI bolted on — it is built specifically for security analytics, and that design decision shows up in a few important ways.

**Unified Data Model (UDM)** is the normalization layer at the center of everything. When a Cloud Audit Log entry arrives in Chronicle, it is parsed and mapped to a standardized schema. An IAM change becomes a `USER_RESOURCE_UPDATE_PERMISSIONS` event with a `principal`, a `target`, and structured `security_result` fields. A network connection becomes a `NETWORK_CONNECTION` event with `network.ip_protocol`, `principal.ip`, and `target.port` fields. Every event type, regardless of the originating product, maps to the same field names. This is what makes detection rules portable and readable — you write rules against UDM fields, not against the raw JSON structure of a specific product's log format.

**Petabyte-scale retention** at a flat rate is the other structural difference. Chronicle's default retention is one year with no per-GB ingestion cost for a set of natively supported log types, including Cloud Audit Logs. The cost model is per-user rather than per-volume, which changes the calculus around what you can afford to keep searchable.

**Google Threat Intelligence** is built in. Chronicle can automatically correlate IOCs — IPs, domains, file hashes — against Google's threat intelligence feed without a separate connector or add-on license.

For readers coming from other SIEMs, here is a quick orientation:

| Feature | Chronicle | Splunk | Microsoft Sentinel |
|---|---|---|---|
| Query language | YARA-L 2.0 (rules) + UDM Search | SPL | KQL |
| Data model | UDM (normalized) | Raw + CIM | ASIM + raw |
| Retention | 1 year default, petabyte-scale | License-dependent | Log Analytics workspace |
| GCP log integration | Native | Via HEC/syslog | Via connector |
| Threat intel | Google TI built-in | ThreatIntelligence add-on | MDTI connector |

YARA-L 2.0 is closer in feel to a structured rule language (like Sigma) than to a query language (like SPL or KQL). You declare what events you are looking for, define how to group them over time, and specify the condition under which the rule fires. If you have written Sigma rules or Snort/Suricata rules before, the pattern will be familiar. If you come from Splunk, the shift from "search and transform" to "declare and match" takes a little adjustment but makes rules easier to audit and version-control.

## Architecture: Getting GCP Logs into Chronicle

The ingestion path from Cloud Logging to Chronicle has two options. The newer path is a direct Chronicle export configured in the Chronicle UI under Settings > Feeds, using Google Cloud Pub/Sub as the transport. The older (and still fully supported) path uses a Log Router sink to push to Pub/Sub, and then a Chronicle Pub/Sub feed pulls from that topic. Both paths land log data in Chronicle as UDM events within a few minutes of the original API call.

```
Cloud Logging (Cloud Audit Logs, VPC Flow Logs, Cloud Armor)
         |
         | Log Router sink
         v
     Pub/Sub topic (chronicle-gcp-logs)
         |
         | Chronicle Pub/Sub feed
         v
    Chronicle (UDM normalization + retention)
         |
         +--- YARA-L 2.0 detection rules
         |
         +--- Alerts / Findings
```

The Log Router sink approach gives you the most control over which log entries flow to Chronicle, because the sink filter is a full Cloud Logging filter expression. You can scope it to specific services, specific resource types, or specific severity levels, and you can tune it later without touching Chronicle's configuration.

## Prerequisites

You will need:

- A GCP project with Owner or Security Admin access
- `gcloud` CLI installed and authenticated
- A Chronicle tenant provisioned (Chronicle is a separate license — contact your Google Cloud rep or check the Chronicle trial program)
- Cloud Audit Logs enabled for the services you want to monitor (Admin Activity is always on; Data Access must be explicitly enabled)

Verify your active project and authentication:

{% highlight bash %}
gcloud config get-value project
gcloud auth list
{% endhighlight %}

Enable the required APIs:

{% highlight bash %}
gcloud services enable \
  logging.googleapis.com \
  pubsub.googleapis.com \
  cloudresourcemanager.googleapis.com \
  secretmanager.googleapis.com \
  compute.googleapis.com \
  --project=PROJECT_ID
{% endhighlight %}

## Setting Up Log Ingestion

### Creating the Pub/Sub Topic and Log Router Sink

The sink filter below covers the three services we will write detection rules for: IAM (via Cloud Resource Manager), Secret Manager, and Compute Engine (for VPC firewall rules). You can extend the filter to include additional services as you add rules.

{% highlight bash %}
# Create the Pub/Sub topic that Chronicle will pull from
gcloud pubsub topics create chronicle-gcp-logs \
  --project=PROJECT_ID
{% endhighlight %}

{% highlight bash %}
# Create the Log Router sink with a filter scoped to the services we care about
gcloud logging sinks create chronicle-sink \
  pubsub.googleapis.com/projects/PROJECT_ID/topics/chronicle-gcp-logs \
  --log-filter='protoPayload.serviceName=("cloudresourcemanager.googleapis.com" OR "secretmanager.googleapis.com" OR "compute.googleapis.com")' \
  --project=PROJECT_ID
{% endhighlight %}

The sink creates a dedicated service account (`serviceAccount:...@gcp-sa-logging.iam.gserviceaccount.com`) that needs publish rights on the topic. Retrieve it and grant the permission:

{% highlight bash %}
# Get the sink's writer identity
SINK_SA=$(gcloud logging sinks describe chronicle-sink \
  --project=PROJECT_ID \
  --format='value(writerIdentity)')

echo "Sink service account: ${SINK_SA}"

# Grant publish rights on the topic
gcloud pubsub topics add-iam-policy-binding chronicle-gcp-logs \
  --member="${SINK_SA}" \
  --role="roles/pubsub.publisher" \
  --project=PROJECT_ID
{% endhighlight %}

### Configuring the Chronicle Pub/Sub Feed

With the topic receiving log data, open the Chronicle UI and navigate to **Settings > Feeds > Add Feed**. Select **Google Cloud Pub/Sub** as the source type, choose **Google Cloud Audit Logs** as the log type, and enter your project ID and the topic name `chronicle-gcp-logs`. Chronicle will use its own service account to subscribe to the topic — copy the Chronicle service account email shown in the UI and grant it the subscriber role:

{% highlight bash %}
# Replace CHRONICLE_SA with the service account shown in the Chronicle feed UI
gcloud pubsub topics add-iam-policy-binding chronicle-gcp-logs \
  --member="serviceAccount:CHRONICLE_SA" \
  --role="roles/pubsub.subscriber" \
  --project=PROJECT_ID
{% endhighlight %}

Once the feed is saved and active, Cloud Audit Log entries will begin arriving in Chronicle within a few minutes. You can validate ingestion in the Chronicle UI via **UDM Search** — search for `metadata.product_name = "Cloud Audit Logs"` and confirm events are appearing.

## YARA-L 2.0 Detection Rules

Now that we have log data flowing, let's implement the detection logic. YARA-L 2.0 rules have a fixed structure with five sections. Understanding each section before looking at full rules makes the syntax click faster.

### Rule Structure

{% highlight bash %}
rule rule_name {
  meta:
    author = "Victor Silva"
    description = "What this rule detects"
    severity = "HIGH"      // CRITICAL, HIGH, MEDIUM, LOW, INFORMATIONAL
    priority = "HIGH"
    type = "ALERT"         // ALERT fires in the Alerts view
                           // RULE_TYPE_UNSPECIFIED creates informational findings

  events:
    // UDM field predicates — all must match for the rule to consider an event
    $e.metadata.event_type = "USER_RESOURCE_UPDATE_PERMISSIONS"
    $e.target.resource.type = "GCP_IAM_POLICY"

  match:
    // Optional — used for multi-event rules to define the grouping key and
    // time window. For single-event rules this section is omitted.
    $e.principal.user.userid over 1h

  condition:
    // Specifies when the rule fires. "$e" means "at least one matching event".
    // For multi-event rules you can write "#e > 5" or combine variables.
    $e

  outcome:
    // Variables available in the alert details. These surface in the alert
    // and can be used for triage without opening the raw log.
    $risk_score = 85
    $principal_email = $e.principal.user.userid
}
{% endhighlight %}

A few UDM field namespaces you will use constantly:

- `$e.metadata` — event type, product name, log type, timestamps
- `$e.principal` — who initiated the action (user, service account, IP)
- `$e.target` — what resource was acted on
- `$e.network` — network connection details (protocol, ports, IPs)
- `$e.security_result` — outcome, threat indicators, verdict

Single-event rules match on one event at a time — the `match` section is omitted and `condition` is just `$e`. Multi-event rules correlate multiple events within a time window, grouping them by a key field (for example, `$e.principal.user.userid over 1h` fires when a single user matches the event predicate more than a threshold number of times in an hour).

### Rule 1: IAM Privilege Escalation

This is the highest-priority rule to have active. Granting `roles/owner` or `roles/editor` to any principal — especially an external one or a service account that should not have project-wide permissions — is one of the most reliable signals of a compromised account or an insider threat.

The rule fires on a single event, because even one such IAM binding change is worth immediate investigation.

{% highlight bash %}
rule gcp_iam_privilege_escalation_owner_editor {
  meta:
    author = "Victor Silva"
    description = "Detects when owner or editor role is granted to any principal"
    severity = "HIGH"
    priority = "HIGH"
    type = "ALERT"

  events:
    $e.metadata.event_type = "USER_RESOURCE_UPDATE_PERMISSIONS"
    $e.target.resource.type = "GCP_IAM_POLICY"
    (
      re.regex($e.target.resource.attribute.labels["role"], `roles/owner`) or
      re.regex($e.target.resource.attribute.labels["role"], `roles/editor`)
    )

  condition:
    $e

  outcome:
    $principal_email = $e.principal.user.userid
    $project = $e.target.resource.name
    $role_granted = $e.target.resource.attribute.labels["role"]
}
{% endhighlight %}

The `re.regex()` function is used here rather than a direct equality check because the role value in the UDM label may contain additional context in some log formats. Using a regex anchored to `roles/owner` ensures the rule catches the binding regardless of surrounding characters.

The `outcome` variables `$principal_email`, `$project`, and `$role_granted` will appear directly in the Chronicle alert details, giving the analyst the three facts they need to start triage without having to dig into raw log data.

### Rule 2: Secret Manager Anomalous Access

Secret Manager access patterns are a reliable detection surface. In a well-governed project, the set of service accounts that legitimately read secrets is small and known. Any access from outside that approved set warrants investigation — it could indicate a compromised application service account, lateral movement, or exfiltration of credentials.

This rule uses a `not re.regex()` predicate to implement a simple allowlist approach. You will customize the regex to match your project's naming convention for approved service accounts.

{% highlight bash %}
rule gcp_secret_manager_anomalous_access {
  meta:
    author = "Victor Silva"
    description = "Detects secret access from service accounts not in the approved list"
    severity = "MEDIUM"
    priority = "MEDIUM"
    type = "ALERT"

  events:
    $e.metadata.product_name = "Secret Manager"
    $e.metadata.event_type = "USER_RESOURCE_ACCESS"
    re.regex($e.metadata.product_event_type, `AccessSecretVersion`)
    not re.regex($e.principal.user.userid, `approved-sa@my-project\.iam\.gserviceaccount\.com`)
    not re.regex($e.principal.user.userid, `another-approved-sa@my-project\.iam\.gserviceaccount\.com`)

  condition:
    $e

  outcome:
    $principal_email = $e.principal.user.userid
    $secret_name = $e.target.resource.name
}
{% endhighlight %}

A few implementation notes for this rule in practice. First, make sure Data Access logs are enabled for Secret Manager — Admin Activity logs do not capture `AccessSecretVersion` calls, only Data Access logs do. Enable them with:

{% highlight bash %}
# Export current IAM policy
gcloud projects get-iam-policy PROJECT_ID --format=json > policy.json
{% endhighlight %}

Add the Secret Manager Data Access audit config to `policy.json` and re-apply:

{% highlight json %}
{
  "auditConfigs": [
    {
      "service": "secretmanager.googleapis.com",
      "auditLogConfigs": [
        { "logType": "DATA_READ" }
      ]
    }
  ]
}
{% endhighlight %}

{% highlight bash %}
gcloud projects set-iam-policy PROJECT_ID policy.json
{% endhighlight %}

Second, the allowlist in the rule above is a starting point. As you expand the rule to cover multiple projects or a more complex service account naming scheme, consider using `re.regex()` with a pattern that matches your entire approved namespace (for example, `^(app-backend|app-worker)-sa@my-project\.iam\.gserviceaccount\.com$`) rather than listing each approved account individually.

### Rule 3: Overly Permissive VPC Firewall Rule

Firewall rules allowing ingress from `0.0.0.0/0` are a routine audit finding that rarely gets caught at creation time. By the time a security reviewer looks at the firewall configuration, the rule has been in place for weeks and removing it requires coordination with application teams. This rule catches the problem the moment the firewall rule is created.

{% highlight bash %}
rule gcp_vpc_firewall_open_ingress {
  meta:
    author = "Victor Silva"
    description = "Detects VPC firewall rules allowing ingress from 0.0.0.0/0"
    severity = "HIGH"
    priority = "HIGH"
    type = "ALERT"

  events:
    $e.metadata.event_type = "USER_RESOURCE_CREATION"
    $e.target.resource.type = "GCP_VPC_FIREWALL_RULE"
    $e.target.resource.attribute.labels["direction"] = "INGRESS"
    $e.target.resource.attribute.labels["source_ranges"] = "0.0.0.0/0"

  condition:
    $e

  outcome:
    $principal_email = $e.principal.user.userid
    $firewall_rule = $e.target.resource.name
    $network = $e.target.resource.attribute.labels["network"]
}
{% endhighlight %}

This rule also captures `USER_RESOURCE_CREATION` events — meaning it fires when the firewall rule is first created, not only on subsequent modifications. If your environment has existing open ingress rules that you want to detect in historical data, the retroactive search approach covered in the next section will surface them without waiting for a new creation event.

One refinement worth considering: if your environment legitimately uses `0.0.0.0/0` ingress for certain ports (like port 80/443 for public-facing load balancers), add a predicate to exclude those specific port combinations, or adjust the severity to `MEDIUM` and route it to an informational finding queue for human review rather than an automated alert.

## Deploying Rules in Chronicle

With the rule text ready, deploying to Chronicle takes a few steps in the UI.

Navigate to **Detection Engine > Rules** and click **New Rule**. Paste the rule text into the YARA-L editor. Chronicle validates the syntax inline — if any field names or function calls are incorrect, the editor highlights the error and shows the expected format. Fix any validation errors before saving.

Once the rule validates cleanly, configure two settings:

**Alert vs. Informational**: Rules with `type = "ALERT"` in the `meta` section create entries in the Alerts view, trigger notification integrations, and are tracked through Chronicle's case management workflow. Rules with `type = "RULE_TYPE_UNSPECIFIED"` create informational findings that appear in the Rules view but do not create alerts. Start new rules as informational until you have validated them against real traffic, then promote them to alert.

**Enabled vs. Disabled**: Rules do not evaluate incoming events until they are explicitly enabled. After saving, toggle the rule to **Enabled** using the status switch in the Rules list.

Chronicle evaluates enabled rules against incoming UDM events in near-real-time — new events that match an enabled rule create findings within a few minutes of the original log event.

## Testing Rules with Retroactive Search

One of Chronicle's most practical features for detection engineering is the ability to run a rule against historical data. This lets you validate that a new rule would have fired on past events (useful for confirming it catches real threats) and estimate its alert volume before enabling it on live data.

To run a retroactive search, open the rule in the Rules editor and click **Run Retroactive Search**. Set the time range (up to the retention window — one year by default) and submit. Chronicle processes the historical UDM events against the rule and shows you a list of matches with timestamps and outcome variable values.

This workflow is where the `outcome` variables pay off. A retroactive search on the IAM privilege escalation rule will show you every `$principal_email`, `$project`, and `$role_granted` value from the past year — you can immediately see whether the rule would have caught real events or whether it is firing on expected administrative activity that needs to be excluded.

For the Secret Manager rule, run a retroactive search over a 30-day window and review the `$principal_email` values in the results. Any service account identity you do not recognize should be investigated; any known-good identity that appeared should be added to the allowlist in the rule before you enable it on live data.

## Best Practices

**Start with the UDM field reference, not trial and error.** Chronicle's documentation includes a complete UDM field reference that lists every available field, its type, and which event types populate it. Before writing a new rule, look up which UDM event type corresponds to the action you want to detect and which fields are populated for that event type. Writing rules against unpopulated fields produces rules that silently never match — the field predicate evaluates as false because the field does not exist in the event, not because events are not arriving.

**Manage alert fatigue before it becomes a problem.** A detection rule that fires 200 times per day for expected activity is worse than no rule at all — it trains analysts to ignore the alert queue. Before enabling a rule in alert mode, run a retroactive search over two weeks of historical data and count the matches. If the volume is too high, tune the rule with additional predicates, add an allowlist for known-good identities, or run it as an informational finding for a week to collect baseline data before deciding on the right threshold.

**Version-control your rules.** YARA-L rule text is plain text — store it in a Git repository alongside your other infrastructure code. Chronicle's API allows programmatic rule management (create, update, enable, disable) via the Chronicle REST API, so you can integrate rule deployment into a CI/CD pipeline with peer review and change tracking. Treat detection rules with the same engineering discipline as Terraform modules: they have the same blast radius when they go wrong.

**Use `outcome` variables to make alerts self-contained.** Every field you expose in `outcome` appears directly in the Chronicle alert details without requiring the analyst to open the raw log. The more context you surface in outcomes — principal identity, resource name, affected project, IP address — the faster triage goes. Think of `outcome` variables as the executive summary of the alert.

**Separate rule type from severity.** A rule can have `severity = "HIGH"` and `type = "RULE_TYPE_UNSPECIFIED"` — high severity, informational mode. Use this during the tuning phase for rules that detect genuinely high-risk behaviors but have not yet been validated against your specific environment's baseline. It gives you visibility into the events without generating alert noise while you tune.

## Conclusion

What we built here is the foundation of a detection engineering practice on GCP. Cloud Audit Logs flowing through a Log Router sink into Chronicle give you a normalized, petabyte-scale searchable corpus of everything happening in your GCP environment. YARA-L 2.0 rules — one for IAM privilege escalation, one for Secret Manager anomalous access, one for overly permissive firewall creation — give you concrete detections for three of the most common GCP security incidents. Retroactive search lets you validate those rules against real historical data before they start generating live alerts.

The next step is expanding coverage. The same YARA-L pattern applies to Cloud Storage public bucket access, GKE workload identity escalation, service account key creation, and Cloud Run deployments from unverified container images. Each new rule follows the same structure: understand the UDM event type, identify the fields that distinguish the suspicious behavior from normal activity, write the predicate, validate with retroactive search, and enable.

If you are working on the underlying infrastructure security that feeds into these detections, the posts on [GCP Secret Manager with Terraform](/gcp-secret-manager-terraform/) and [GCP VPC Service Controls with Terraform](/gcp-vpc-service-controls-terraform/) cover the preventive controls that reduce the surface area these detection rules are monitoring. For runtime threat detection at the workload layer, [Falco runtime security for Kubernetes](/falco-runtime-security-kubernetes/) complements Chronicle's API-level visibility with in-cluster syscall-level detection. For the GKE workload identity escalation scenario mentioned above, [GCP Binary Authorization for GKE with Terraform](/gcp-binary-authorization-gke-terraform/) provides the admission-time control that pairs with Chronicle's post-deployment detection.

Happy scripting!
