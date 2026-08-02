---
title: 'OCI Unused IAM Permissions: Detecting via Audit Logs'
author: Victor Silva
date: 2026-08-02T13:31:57+00:00
layout: post
permalink: /oci-unused-iam-permissions/
excerpt: "OCI has no IAM Access Analyzer. Detect unused IAM permissions by cross-referencing Audit Service logs against policy statements with the OCI SDK."
categories:
  - OCI
  - Security
tags:
  - oci-iam
  - least-privilege
  - audit-service
  - oci-sdk-python
  - iam-access-analyzer
  - terraform
  - devsecops
  - oci
---

In [an earlier post]({% link _posts/2026/2026-01-09-oci-iam-terraform.md %}), we covered how to grant access in OCI — compartments, dynamic groups, policy statements, all wired up through Terraform so your IAM footprint lives in version control instead of a console click-through. That post answered "how do I give this team what it needs." This post answers a harder question: now that the policies are live, how do you prove that what you granted is actually what people use?

If you've run an OCI tenancy for more than a few quarters, you already know how policies drift. Someone requests `manage instances` because they needed it once for a migration. A service account gets `manage` on a compartment because nobody wanted to debug a `use`-level permission error during an incident. A dynamic group inherited broad access from a template policy that was copy-pasted from another environment. None of this is malicious — it's just how least privilege erodes under deadline pressure. Every one of those statements is now sitting in your tenancy as unreviewed, unverified attack surface.

AWS has IAM Access Analyzer telling you which permissions in a role have gone unused for 90 days. GCP has the IAM Recommender doing the same thing based on Policy Intelligence. OCI has neither. There is no first-party OCI feature that says "this group was granted `manage` on `instances` but has only ever called `ListInstances` and `GetInstance` in the last year." If you want that signal in OCI today, you have to build it yourself from primitives Oracle does provide: the Audit service, the IAM SDK, and the published Policy Reference tables.

That's what this post does. We'll build a Python workflow that cross-references your deployed IAM policy statements against 365 days of OCI Audit events, and produces a per-statement utilization report — not a clean "used/unused" binary, but a much more honest picture of which granted capabilities have actually been exercised. By the end you'll have evidence-backed input for a policy-narrowing change request, which is a fundamentally stronger position than "this permission looks too broad to me."

This also happens to be a direct, scriptable answer to NIST SP 800-53 AC-6(7), "Review of User Privileges" — the control that asks you to periodically verify that assigned privileges are still necessary. Most teams satisfy this control with a spreadsheet and a prayer. We're going to satisfy it with audit data.

## What Already Exists (and What Doesn't)

Before writing any code, it's worth being precise about the landscape, because it's easy to assume a tool already solves this.

**Oracle Access Governance** is a real, separate paid product (oracle.com/security/cloud-security/access-governance) that does access *certification* — it surfaces grants to a human reviewer who attests "yes, this person still needs this." That's a valuable but fundamentally different workflow from what we're building: certification asks a human to remember or investigate; usage-based detection asks the audit trail. They're complementary, not substitutes.

There's also a well-known community project, **OCI Policy Analysis** (a three-part series on blogs.oracle.com/cloud-infrastructure, code at `github.com/agregory999/oci-policy-analysis`), built by an Oracle employee. It does static policy parsing and API simulation — effectively "if I ran this API call as this principal, would the policy allow it?" — plus dynamic group analysis. It's a genuinely useful tool for *understanding* what a policy grants. But it does not touch the Audit service, and it does not tell you what's actually been *used*. It answers "would this be allowed," not "was this ever exercised."

It's also worth distinguishing this from [OCI Security Zones]({% link _posts/2025/2025-08-05-oci-security-zones.md %}), which is a preventive control — it blocks non-compliant actions at apply time, before they happen. What we're building here is detective, not preventive: it looks backward at 365 days of exercised access to find capability nobody has used, which Security Zones has no visibility into by design.

As of this writing, nothing ships from Oracle or the community that closes the AWS Access Analyzer / GCP Recommender gap for usage-based unused-access detection. That's the gap this post fills.

## Technical Background: Why This Is Two Data Sources, Not One

The core difficulty isn't fetching data — the OCI SDK makes that straightforward. It's that the two datasets you need don't join cleanly.

**Grants** come from IAM policy statements: `allow <subject> to <verb> <resource-type> in <location>`. Each verb (`inspect`, `read`, `use`, `manage`) resolves to a fixed set of permissions for that resource type, and each permission maps to one or more concrete API operations. Oracle documents this mapping per service in the Policy Reference pages — Core Services (`corepolicyreference.htm`) and IAM (`iampolicyreference.htm`). There's no machine-readable export of these tables as of 2026, so building a permission map means reading the docs and hand-curating it for the services you actually care about.

**Usage** comes from the OCI Audit service, which records every API call tenancy-wide as an immutable event: `eventName` (the API operation, e.g. `LaunchInstance`), the calling `identity` (principal OCID, type, name), the target compartment and resource, a timestamp, and source IP.

Joining these isn't 1:1, for two reasons:

1. **One audit event can require multiple permissions across multiple resource types.** `LaunchInstance` alone typically needs `INSTANCE_CREATE`, `VNIC_CREATE`, `SUBNET_ATTACH`, and image-read permissions — spanning compute, networking, and possibly Block Volume policy statements simultaneously. A single API call can "satisfy" fragments of several different grants at once.

2. **Verb hierarchy makes "used" a spectrum, not a boolean.** OCI's verbs nest: `inspect` ⊂ `read` ⊂ `use` ⊂ `manage`. If a group has `manage instances`, that statement is technically "used" the moment anyone calls `ListInstances` — even though `LaunchInstance`, `TerminateInstance`, and `ChangeInstanceCompartment` may never have been touched. A binary used/unused flag would call that statement fully used and miss the fact that 80% of its capability is idle, unverified, dangerous surface.

So the right output isn't "used" or "unused" — it's a **utilization ratio per statement**: of the permissions a verb grants for a resource type, how many were actually exercised by the group's members over the observation window, and which specific operations were not.

## Prerequisites

- An OCI tenancy with IAM policies already deployed. If you haven't done that yet, start with [the earlier IAM/Terraform post]({% link _posts/2026/2026-01-09-oci-iam-terraform.md %}) — this post assumes policies exist and focuses purely on auditing them.
- Python 3.9+ and the OCI SDK: `pip install "oci>=2.130"`
- An OCI CLI config profile (`~/.oci/config`) with read access to:
  - Identity: `list_policies`, `list_groups`, `list_user_group_memberships`
  - Audit: `list_events`
  
  at the tenancy level, or scoped to the compartments you're auditing first.
- A decision about scope. Don't attempt full-tenancy coverage on your first run — pick one or two compartments and one or two services (we'll use Compute instances and Block Volume below) and expand from there once the workflow is validated.

Verify your config works before writing anything else:

{% highlight bash %}
oci iam compartment list --compartment-id-in-subtree true --all --query "data[].name"
{% endhighlight %}

If that returns compartment names, your profile has enough access to proceed.

## Step 1: Parse the Deployed Policy Statements

Policies come back from the SDK as raw strings — `list_policies` returns `Policy` objects with a `.statements` list, but there's no structured parse baked into the SDK. You write the regex.

{% highlight python %}
import oci
import re

config = oci.config.from_file()
identity = oci.identity.IdentityClient(config)

STATEMENT_RE = re.compile(
    r"allow\s+(group|dynamic-group)\s+(\S+)\s+to\s+(inspect|read|use|manage)\s+"
    r"([\w-]+)\s+in\s+(tenancy|compartment\s+\S+)",
    re.IGNORECASE,
)

def get_policy_statements(compartment_id):
    policies = oci.pagination.list_call_get_all_results(
        identity.list_policies, compartment_id=compartment_id
    ).data
    parsed = []
    for policy in policies:
        for stmt in policy.statements:
            m = STATEMENT_RE.match(stmt.strip())
            if not m:
                continue  # admin/deny statements, "where" clauses -> handle separately
            subject_type, subject_name, verb, resource_type, location = m.groups()
            parsed.append({
                "policy_name": policy.name,
                "policy_id": policy.id,
                "raw_statement": stmt,
                "subject_type": subject_type.lower(),
                "subject_name": subject_name,
                "verb": verb.lower(),
                "resource_type": resource_type.lower(),
                "location": location,
            })
    return parsed
{% endhighlight %}

This regex is deliberately narrow. It'll cleanly catch the common case — `allow group X to manage Y in compartment Z` — but it will silently skip anything with a `where` clause, `any-user`, multiple resource-types in one statement, or cross-tenancy `endorse` statements. That's fine for a first pass; just be aware that anything not matched falls out of the report entirely rather than showing up as a false negative, so check your policy count against your parsed-statement count and go extend the regex for whatever's missing before you trust the results.

## Step 2: Pull Audit Events and Index by Principal

The Audit service is compartment-scoped per call, not tenancy-wide in one shot — you loop over compartments (get the full list via `list_compartments` with `compartment_id_in_subtree=True`). Retention is 365 days by default, tenancy-wide, and it's not configurable from the Console or CLI — if you need a longer lookback, you forward Audit logs via Service Connector Hub to Logging Analytics or Object Storage for archival before this window rolls off.

{% highlight python %}
import datetime
from collections import defaultdict

audit = oci.audit.AuditClient(config)

def get_audit_events(compartment_id, lookback_days=90):
    end_time = datetime.datetime.utcnow()
    start_time = end_time - datetime.timedelta(days=lookback_days)
    events = oci.pagination.list_call_get_all_results(
        audit.list_events,
        compartment_id=compartment_id,
        start_time=start_time,
        end_time=end_time,
    ).data
    return events

def index_events_by_principal(events):
    usage = defaultdict(set)  # principal_id -> set of eventNames actually called
    for e in events:
        principal_id = e.identity.principal_id
        event_name = e.event_name
        usage[principal_id].add(event_name)
    return usage
{% endhighlight %}

Note `start_time`/`end_time` are RFC 3339 datetimes at minute granularity — the SDK handles the formatting for you here, just pass `datetime` objects. For a real run, push `lookback_days` up to 365 to use the full native retention window, budget for the pagination to take a while on a busy tenancy, and use `list_call_get_all_results` rather than hand-rolling the `opc-next-page` loop — it's easy to get wrong and there's no reason to.

## Step 3: Resolve Group Membership

Policies grant to groups, not individual users, so you need to expand each group to its member principal OCIDs before you can match against Audit's `identity.principal_id`.

{% highlight python %}
def resolve_group_members(compartment_id, group_name):
    groups = oci.pagination.list_call_get_all_results(
        identity.list_groups, compartment_id=compartment_id, name=group_name
    ).data
    if not groups:
        return []
    memberships = oci.pagination.list_call_get_all_results(
        identity.list_user_group_memberships,
        compartment_id=compartment_id,
        group_id=groups[0].id,
    ).data
    return [m.user_id for m in memberships]
{% endhighlight %}

Dynamic groups are a harder case. Their membership isn't a static list — it's evaluated at call time by matching rules against the instance or resource principal certificate presented in the request. There's no clean SDK call that says "here are the current members of this dynamic group" the way there is for regular groups. The practical workaround is empirical: parse the dynamic group's matching rule, then check whether the principals that actually show up in your Audit events for that resource type/compartment plausibly satisfy it. Treat this as something to verify by hand in your own tenancy rather than something the tooling can guarantee — Oracle doesn't document field population for dynamic-group-authorized calls closely enough to trust it blindly.

## Step 4: Build the Permission Map and Cross-Reference

This is the part that has to be hand-curated. Pull the verb-to-permission-to-API-operation mappings from Oracle's Policy Reference docs for whichever services you're scoping into this pass. Start narrow — trying to cover every OCI service on day one guarantees you'll ship a wrong or stale map. Here's a minimal example covering Compute instances and Block Volume:

{% highlight python %}
# Minimal permission map for the services covered in this example.
# Structure: resource_type -> verb -> set of API operations granted
PERMISSION_MAP = {
    "instances": {
        "inspect": {"ListInstances", "GetInstance"},
        "read":    {"ListInstances", "GetInstance"},
        "use":     {"ListInstances", "GetInstance", "UpdateInstance",
                     "InstanceAction", "AttachVolume", "DetachVolume"},
        "manage":  {"ListInstances", "GetInstance", "UpdateInstance",
                     "InstanceAction", "AttachVolume", "DetachVolume",
                     "LaunchInstance", "TerminateInstance",
                     "ChangeInstanceCompartment", "CreateImage"},
    },
    "volumes": {
        "inspect": {"ListVolumes", "GetVolume"},
        "read":    {"ListVolumes", "GetVolume"},
        "use":     {"ListVolumes", "GetVolume", "UpdateVolume",
                     "AttachVolume", "DetachVolume"},
        "manage":  {"ListVolumes", "GetVolume", "UpdateVolume",
                     "AttachVolume", "DetachVolume",
                     "CreateVolume", "DeleteVolume", "ChangeVolumeCompartment"},
    },
}

def build_report(policy_statements, usage_by_principal, group_members):
    report = []
    for stmt in policy_statements:
        granted_ops = PERMISSION_MAP.get(stmt["resource_type"], {}).get(stmt["verb"])
        if granted_ops is None:
            report.append({**stmt, "status": "UNMAPPED - add to PERMISSION_MAP"})
            continue

        members = group_members.get(stmt["subject_name"], [])
        exercised_ops = set()
        for principal_id in members:
            exercised_ops |= usage_by_principal.get(principal_id, set())

        exercised = granted_ops & exercised_ops
        unused = granted_ops - exercised_ops

        if not exercised:
            status = "FULLY_UNUSED"
        elif unused:
            status = f"PARTIALLY_USED ({len(exercised)}/{len(granted_ops)} ops)"
        else:
            status = "FULLY_USED"

        report.append({
            **stmt,
            "status": status,
            "unused_operations": sorted(unused),
        })
    return report
{% endhighlight %}

Before you trust a single row of output from this, verify every entry in `PERMISSION_MAP` against Oracle's current Policy Reference docs. Oracle adds operations to services over time, and a stale map will produce false "unused" findings for operations you simply forgot to list.

## Wiring It Together

{% highlight python %}
def run_audit(compartment_id, lookback_days=365):
    statements = get_policy_statements(compartment_id)
    events = get_audit_events(compartment_id, lookback_days=lookback_days)
    usage_by_principal = index_events_by_principal(events)

    group_members = {}
    for stmt in statements:
        if stmt["subject_type"] == "group" and stmt["subject_name"] not in group_members:
            group_members[stmt["subject_name"]] = resolve_group_members(
                compartment_id, stmt["subject_name"]
            )

    return build_report(statements, usage_by_principal, group_members)

if __name__ == "__main__":
    tenancy_id = config["tenancy"]
    results = run_audit(tenancy_id, lookback_days=365)
    for row in results:
        print(f"{row['policy_name']:30} {row['subject_name']:20} "
              f"{row['verb']:8} {row['resource_type']:12} -> {row['status']}")
{% endhighlight %}

If you plan to run this on a schedule rather than ad hoc from your workstation — an OCI Function or a cron job on a small compute instance, as recommended below — don't embed the API signing key in the script or its environment file. Store it in [OCI Vault]({% link _posts/2026/2026-04-06-oci-vault-secrets-management-terraform.md %}) and have the scheduled job's instance principal retrieve it at run time instead, the same pattern used for any other credential this blog has covered.

## Testing and Validation

Before you run this against production policies, validate it against a scenario where you already know the answer. Create a scratch compartment, a test group, and a policy granting `manage volumes` to that group. Log in as a member and run exactly two read-only calls (`ListVolumes`, `GetVolume`) — nothing else. Wait a few minutes for the Audit event to land (Audit typically shows events within minutes, not instantly), then run the script against that compartment.

You should see:

{% highlight text %}
test-policy   test-group   manage   volumes   -> PARTIALLY_USED (2/9 ops)
{% endhighlight %}

with `unused_operations` listing `CreateVolume`, `DeleteVolume`, `AttachVolume`, `DetachVolume`, `UpdateVolume`, `ChangeVolumeCompartment`, and `GetVolume`/`ListVolumes` absent from that list (since those two were exercised). If your test doesn't produce that, don't trust the tool on real data yet — work backward from whichever step (parsing, audit query, group resolution, or the map itself) is producing the mismatch.

Once that checks out, run it against one real, low-risk compartment first, sanity-check a handful of `FULLY_UNUSED` results by hand against the Console's Audit log search, and only then widen scope.

## Limitations (Read This Before You Act on Any Output)

This tool produces a signal, not a verdict. Be explicit about what it can't tell you:

- **Partial use is the norm, not the exception.** A `manage` grant "used" via one `ListInstances` call still leaves the destructive operations — `LaunchInstance`, `TerminateInstance`, `ChangeInstanceCompartment` — as unexercised, dangerous idle capability sitting behind a low-friction verb.
- **This doesn't address scope.** `manage instances in tenancy` vs. `manage instances in compartment dev` is a completely separate risk axis from the verb. Narrowing `manage` to `use` does nothing to fix a grant that's scoped far wider than it needs to be.
- **Dynamic group resolution is empirical, not exact.** Verify matching-rule-to-principal mapping in your own tenancy rather than trusting it blindly.
- **Object Storage object-level operations are not Audit-logged at all** — only bucket-level events are captured. Any policy statement scoped to `objects` inside a bucket is a hard blind spot for this technique; Audit alone cannot validate it.
- **365-day retention caps your native lookback.** Beyond that window, you need Service Connector Hub forwarding to Logging Analytics or Object Storage already in place — retroactively, there's nothing to query.
- **Break-glass and emergency-access groups will show as `FULLY_UNUSED` by design.** That's an expected false positive, not a finding. Exclude these from any automated remediation candidate list and flag them for manual review instead.
- **The regex parser is intentionally minimal.** Real tenancies have `where` conditions, `any-user`, `all-resources`, multiple resource-types per statement, and cross-tenancy `endorse` statements. Extend the parser to cover whatever your policies actually contain before trusting statement counts.

## Remediation: From Finding to Change

Once you have a statement flagged `FULLY_UNUSED` or heavily `PARTIALLY_USED`, resist the urge to fix it in the Console. Narrow it in Terraform, the same way you deployed it — this keeps the change reviewable, revertible, and consistent with the IaC approach from the earlier IAM post.

For a partial-use finding, the typical move is dropping a verb tier: `manage volumes` becomes `use volumes` if none of the create/delete/change-compartment operations were ever exercised. Apply the narrower statement, but don't delete the broader one immediately — run both in parallel for a shadow period (two weeks is a reasonable default) while continuing to poll Audit for the same principal set. Specifically watch for denied-API attempts during that window: Audit still logs failed calls, so filter on response status to catch anyone who actually needed the wider grant before you remove it for good.

This is a different layer of defense than [Cloud Guard's threat detection]({% link _posts/2026/2026-06-09-oci-cloud-guard-threat-intelligence-terraform.md %}), worth being clear about: Cloud Guard watches for anomalous or malicious *behavior* happening now, in near-real time. What we've built here looks backward at a full year of *legitimate* access to find capability nobody exercises at all — reducing the blast radius available to an attacker before anything anomalous ever happens. One is detective for incidents, the other is preventive hygiene for standing privilege.

Finally, treat this as a recurring hygiene ritual, not a one-time cleanup. Schedule it quarterly — it maps cleanly to CIS OCI Foundations Benchmark's audit-log-retention control and general least-privilege guidance, and it directly operationalizes NIST 800-53 AC-6(7)'s periodic privilege review requirement. A cron job or an OCI Function on a schedule is enough; the cost of running this is trivial compared to the cost of an idle `manage` grant nobody remembers approving.

## Wrapping Up

OCI doesn't have an Access Analyzer or a Policy Intelligence equivalent, and that's worth stating plainly rather than working around quietly — it's a real gap in the platform's native tooling. But the raw materials to close it yourself are already there: the Audit service records everything, the Policy Reference docs define what every verb actually grants, and the SDK gives you everything you need to join the two. What you get out of a script like this isn't a clean, trustworthy used/unused list — verb hierarchy and partial use make sure of that — but it is a real utilization signal per statement, backed by actual evidence instead of a hunch. "I think this grant is too broad" becomes "here's the audit trail showing this `manage`-level capability has never been exercised in 365 days," and that's a materially stronger basis for a change request.

Run it on a narrow scope first, verify your permission map against Oracle's docs, watch for break-glass groups skewing your unused list, and treat the whole thing as a recurring ritual rather than a one-off audit. Least privilege isn't a state you reach once — it's a drift you have to keep correcting for.

Happy scripting!
