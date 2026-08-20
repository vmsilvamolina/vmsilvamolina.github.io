---
title: 'OCI Resource Manager Drift Detection: Alerts Without Events'
author: Victor Silva
date: 2026-08-20T12:56:57+00:00
layout: post
permalink: /oci-resource-manager-drift-detection/
excerpt: "OCI Resource Manager drift detection emits no Events service event, so the obvious alert rule never fires. Build a polling sentinel with OCI Functions."
categories:
  - OCI
  - Security
  - Terraform
tags:
  - oci-resource-manager
  - drift-detection
  - terraform-drift
  - oci-functions
  - oci-notifications
  - iac-security
  - terraform
  - devsecops
  - oci
---

At 3 a.m. someone widens a security list to `0.0.0.0/0` on port 22 because the runbook says "get access, restore service, write it up in the morning." Service gets restored. The write-up happens. The rule does not get reverted. Six weeks later your Terraform still says `10.0.0.0/16`, your PR history still says `10.0.0.0/16`, [checkov still passes on every commit]({% link _posts/2024/2024-10-14-checkov-custom-policies-azure-terraform.md %}), and production still says `0.0.0.0/0`.

That is drift, and catching it is what OCI Resource Manager drift detection is for. It belongs in a security post rather than a hygiene post because of the sequence of events. Every drift finding is, by definition, a change that reached production without passing code review, without tripping [checkov or tfsec]({% link _posts/2024/2024-05-14-trivy-github-actions-container-iac-scanning.md %}), and without an approver's name on it. Your policy-as-code pipeline is a gate on one specific door. Drift is everything that came through the window.

Three drift classes map straight onto adversary behaviour:

- **`oci_core_security_list` or `oci_core_network_security_group` MODIFIED** — ingress widened during an incident, never reverted. The report gives you a flattened property path: `ingress_security_rules.0.source`, actual `0.0.0.0/0` against expected `10.0.0.0/16`. MITRE ATT&CK **T1578** (Modify Cloud Compute Infrastructure).
- **`oci_identity_policy` MODIFIED** — a statement broadened from `read` to `manage`, or a compartment scope replaced with `tenancy`. **T1098** (Account Manipulation), and the change most likely to stay invisible, because the policy still exists under the same name.
- **A control resource DELETED** — `oci_cloud_guard_target`, `oci_vulnerability_scanning_host_scan_recipe`, `oci_logging_log`, `oci_cloud_guard_security_zone`. Highest severity, and it deserves its own alert path. Deleting a detective control is **T1562.001** (Impair Defenses), and what makes it dangerous is that nothing else complains: a deleted [Cloud Guard target]({% link _posts/2026/2026-06-09-oci-cloud-guard-threat-intelligence-terraform.md %}) does not page anyone, it just stops producing findings — and silence looks identical to "everything is fine."

Resource Manager has a native drift detection feature that finds all of this, and it works well. It also emits no Events service event, which means the design everyone reaches for first — an Events rule that fires on drift and pushes to Notifications — cannot be built. This post is about what to build instead.

It assumes you already have [IAM compartments, dynamic groups, and policies in Terraform]({% link _posts/2026/2026-01-09-oci-iam-terraform.md %}), some view into [which permissions are actually exercised]({% link _posts/2026/2026-08-02-oci-unused-iam-permissions.md %}), and that you have considered [Security Zones]({% link _posts/2026/2026-03-25-oci-security-zones-part2.md %}) — which *prevents* the non-compliant change, where drift detection *catches* what it did not cover.

## How Resource Manager Drift Detection Actually Works

Resource Manager is Oracle's managed Terraform. If you have only ever run Terraform yourself, these differences matter:

| | Self-managed Terraform | OCI Resource Manager |
|---|---|---|
| State | Your backend | RM-managed `.tfstate`, automatic |
| Locking | Backend-dependent | Built in — one job at a time per stack |
| Terraform version | Anything you can install | **Capped at 1.5.x (CLI 1.5.7)** since 2024-07-30 |
| Drift check | `terraform plan -refresh-only` | `DetectStackDrift` API plus per-resource report |
| Cost | Runner/agent cost | No dedicated charge |

That version cap is not a footnote. Since 30 July 2024 Resource Manager has supported nothing beyond 1.5.x — no `provider::` functions, no ephemeral resources, nothing from 1.6 onward — and on **2026-04-30** it stopped allowing stack creation *and* job creation on stacks below 1.5.x. Old stacks pinned to 1.0 or 1.2 are already inert; you cannot drift-check them until you bump the version.

### The two-level drift status model

Drift status exists at two levels, and conflating them is the most common reading error. **Stack level** is `Stack.stack_drift_status`, alongside `time_drift_last_checked`: `NOT_CHECKED`, `IN_SYNC`, `DRIFTED`. **Resource level** is `StackResourceDriftSummary.resource_drift_status`, one record per managed resource: `NOT_CHECKED`, `IN_SYNC`, `MODIFIED`, `DELETED`.

Each summary carries `stack_id`, `compartment_id`, `resource_name`, `resource_id`, `resource_type`, `resource_drift_status`, `actual_properties`, `expected_properties`, and `time_drift_checked`. The two property maps are `dict[str, str]`, flattened Terraform-style, so a nested block arrives as `options.0.server_type` rather than structured JSON — diffing them is a dictionary comparison, not a tree walk.

### It is a work request, not a job

This is the detail that breaks most first attempts at automation. `Job.operation` is an enum of `PLAN`, `APPLY`, `DESTROY`, `IMPORT_TF_STATE`, `PLAN_ROLLBACK`, `APPLY_ROLLBACK`. There is no drift operation in it.

Drift is a **work request** instead. `WorkRequest.operation_type` covers `CHANGE_STACK_COMPARTMENT`, `CREATE_STACK_FROM_COMPARTMENT`, `CREATE_PRIVATE_ENDPOINT`, `UPDATE_PRIVATE_ENDPOINT`, `DELETE_PRIVATE_ENDPOINT`, and `DRIFT_DETECTION`. Status is `ACCEPTED`, `IN_PROGRESS`, `SUCCEEDED`, or `FAILED`.

So `oci resource-manager job list` will **never** show a drift run — not filtered, not with `--all`, never. Tooling that watches the job list is watching the wrong resource. Use `work-request list`.

### The prerequisite, and the async contract

You cannot drift-check an arbitrary stack. It must either have been newly created via compartment resource discovery, or its **last executed job must have been an Apply or an Import State**. If the last job was a Plan, the check will not run — which trips up exactly the workflow you would expect: someone previews a change, decides not to apply it, and the nightly scan fails until somebody applies something. Build that into your alerting, because a check that cannot run is not a stack that is in sync.

`DetectStackDrift` then returns HTTP 202, and the work request OCID is in the **`opc-work-request-id` response header**, not the body. The Python SDK's `detect_stack_drift()` returns a `Response` whose `data` is of type `None`, so `wr_id = resp.data.id` gets you an `AttributeError` with no obvious cause. Read the header.

And `ListStackResourceDriftDetails`, called without `--work-request-id`, returns results from the **latest completed** work request for that stack. Fine in a manual session; in a pipeline where two runs overlap it is a race that silently hands you a stale report. Always pass the OCID your own call returned.

## The Core Finding: There Is No Events Integration

Here is the complete, verified list of event types Resource Manager produces:

{% highlight text %}
com.oraclecloud.oracleresourcemanager.canceljob
com.oraclecloud.oracleresourcemanager.createjob.begin
com.oraclecloud.oracleresourcemanager.createjob.end
com.oraclecloud.oracleresourcemanager.updatejob
com.oraclecloud.oracleresourcemanager.changestackcompartment.begin
com.oraclecloud.oracleresourcemanager.changestackcompartment.end
com.oraclecloud.oracleresourcemanager.createstack
com.oraclecloud.oracleresourcemanager.deletestack
com.oraclecloud.oracleresourcemanager.updatestack
{% endhighlight %}

Nine event types, and no `detectdrift`, no `driftdetection`, no `workrequest.end`. Drift detection produces no event, and neither does completion of the work request that performs it.

Note the namespace segment while that list is in front of you: **`oracleresourcemanager`**, not `resourcemanager`. Every other OCI service uses the short service name; this one does not. Write `com.oraclecloud.resourcemanager.createjob.end` in an Events rule and you get no error, no warning, and no matches — ever. Syntactically valid, semantically dead. I have watched two teams lose an afternoon to that string.

What this kills is the design everyone sketches first:

{% highlight text %}
[Drift detection runs] ──X──► [Events rule] ──► [Notifications topic] ──► [Email/Slack]
                        ▲
                        └── this arrow does not exist
{% endhighlight %}

No filter change or `eventType` string fixes that — the producer side simply is not there. What you build instead is a poller that **publishes its own signal**, making you the event producer:

{% highlight text %}
[Scheduler] ──► [OCI Function] ──► DetectStackDrift ──► poll work request
                      │
                      ├──► ListStackResourceDriftDetails (MODIFIED | DELETED)
                      ├──► ONS PublishMessage ──► [Topic] ──► [Email / Slack / PagerDuty]
                      └──► PostMetricData ──► [Monitoring alarm / dashboard]
{% endhighlight %}

That is the whole architecture. The rest of this post builds it.

## Prerequisites

- An OCI tenancy with at least one Resource Manager stack whose last job was an **Apply** or **Import State**.
- Stack Terraform version at 1.5.x. Anything below has been unable to create jobs since 2026-04-30.
- OCI CLI 3.x configured. Verify with:

{% highlight bash %}
oci resource-manager stack list --compartment-id "$COMPARTMENT_ID" \
  --query 'data[].{name:"display-name",id:id,tf:"terraform-version",drift:"stack-drift-status"}' \
  --output table
{% endhighlight %}

- For the sentinel: an OCI Functions application, an OCIR repo, the Fn CLI, and the Python 3.11 runtime.
- A Notifications topic with at least one confirmed subscription.
- Terraform 1.5.x locally with the `oracle/oci` provider at 5.x or later.

## IAM: Lead With the Least-Privilege Trap

Before the policy statements, the uncomfortable part.

`DetectStackDrift` maps to the permission **`ORM_STACK_UPDATE`**, granted only at the **`manage orm-stacks`** verb level. Reading the results afterwards — `ListStackResourceDriftDetails` — needs only `ORM_STACK_READ`, from `read orm-stacks`.

So: **you cannot run drift detection with a read-only identity.** Your auditor automation, whose entire job is to look and report and change nothing, must hold `manage orm-stacks` on the stacks it audits. And `manage` carries `ORM_STACK_CREATE`, `ORM_STACK_MOVE`, and `ORM_STACK_DELETE` alongside it. Your read-only auditor holds delete rights on every stack it inspects.

| Verb | Permissions | APIs fully covered |
|---|---|---|
| `inspect` | `ORM_STACK_INSPECT` | ListStacks, ListResourceDiscoveryServices, ListTerraformVersions |
| `read` | + `ORM_STACK_READ` | GetStack, GetStackTfConfig, GetStackTfState, ListStackAssociatedResources, **ListStackResourceDriftDetails** |
| `use` | + `ORM_STACK_USE` | (no additional APIs) |
| `manage` | + `ORM_STACK_CREATE`, `ORM_STACK_UPDATE`, `ORM_STACK_MOVE`, `ORM_STACK_DELETE` | CreateStack, UpdateStack, ChangeStackCompartment, DeleteStack, **DetectStateDrift** |

For work requests: `orm-work-requests` at `inspect` gives `ORM_WORK_REQUEST_INSPECT` (ListWorkRequests); at `read` it adds `ORM_WORK_REQUEST_READ` (GetWorkRequest, ListWorkRequestErrors, ListWorkRequestLogs).

Look at the last row of that table. The IAM policy reference documents the API as **`DetectStateDrift`**; the API reference, the SDKs, and the CLI all call it **`DetectStackDrift`**. Same operation, two spellings, in Oracle's own docs. That matters in one specific place, coming up next.

### The sentinel's policy set

Assuming a dynamic group `drift-sentinel-dg` matching the function:

{% highlight text %}
# Dynamic group matching rule
ALL {resource.type='fnfunc', resource.compartment.id='<security_compartment_ocid>'}
{% endhighlight %}

{% highlight text %}
Allow dynamic-group drift-sentinel-dg to manage orm-stacks in compartment iac-stacks
Allow dynamic-group drift-sentinel-dg to read orm-work-requests in compartment iac-stacks
Allow dynamic-group drift-sentinel-dg to use ons-topics in compartment security
 where request.operation = 'PublishMessage'
Allow dynamic-group drift-sentinel-dg to use metrics in compartment security
 where target.metrics.namespace = 'iac_governance'
{% endhighlight %}

The ONS and metrics statements are narrowed with `where` conditions. The `orm-stacks` statement is not, and that is the trap.

### Trying to narrow it — flagged as unverified

The obvious move is to condition the `manage` grant on the one operation you need:

{% highlight text %}
# UNVERIFIED — test this in your own tenancy before relying on it
Allow dynamic-group drift-sentinel-dg to manage orm-stacks in compartment iac-stacks
 where request.operation = 'DetectStackDrift'
{% endhighlight %}

**I could not verify that this works, and you should not deploy it as though it does.** The pattern is real — Oracle's docs use `where any request.operation={'CreatePrivateEndpoint'}` for RM private endpoints, and this verified example from the same docs shows the shape on jobs:

{% highlight text %}
Allow group <group> to use orm-stacks in tenancy
Allow group <group> to read orm-jobs in tenancy
Allow group <group> to manage orm-jobs in tenancy
 where any {target.job.operation = 'PLAN', target.job.operation = 'APPLY'}
{% endhighlight %}

The mechanism exists. What I could not confirm is which spelling the policy engine accepts, given the `DetectStateDrift` / `DetectStackDrift` split. Test both in your own tenancy and check Audit for the deny if it fails. If neither works you are stuck with the unconditioned `manage` grant — scope it as tightly as you can by compartment, and treat the sentinel's dynamic group as a privileged identity with the review cadence that implies.

### Reading the underlying resources

Drift refreshes real-world state, so the principal needs read access to every resource type the stack manages, not just to the stack:

{% highlight text %}
Allow dynamic-group drift-sentinel-dg to inspect all-resources in tenancy
Allow dynamic-group drift-sentinel-dg to read virtual-network-family in tenancy
Allow dynamic-group drift-sentinel-dg to read instance-family in tenancy
Allow dynamic-group drift-sentinel-dg to read policies in tenancy
Allow dynamic-group drift-sentinel-dg to read groups in tenancy
{% endhighlight %}

A missing read grant is the most likely cause of a `FAILED` drift work request. I am inferring that from Oracle's general statement about drift refreshing state rather than from drift-specific docs, so check `list-work-request-errors` and let the error tell you.

### The state-file exfiltration path

One more IAM concern. Resource Manager stores `.tfstate` for you, and state files routinely contain resource OCIDs, generated passwords, and private keys. Anyone holding **`ORM_JOB_READ`** can retrieve those state files, and the configurations too via `GetJobTfConfig`. Oracle's guidance is to segregate state into a compartment with a restrictive policy and keep sensitive values out of configurations — use [OCI Vault]({% link _posts/2026/2026-04-06-oci-vault-secrets-management-terraform.md %}) and reference secrets instead. Extending `ORM_JOB_READ` to the sentinel's dynamic group "just for debugging" turns your drift auditor into a credential harvester.

## Running Drift Detection by Hand

Run it by hand first, so you know what a correct result looks like.

{% highlight bash %}
STACK_ID="ocid1.ormstack.oc1.iad.aaaa..."

oci resource-manager stack detect-drift \
  --stack-id "$STACK_ID" \
  --wait-for-state SUCCEEDED \
  --max-wait-seconds 1800 \
  --wait-interval-seconds 15
{% endhighlight %}

The verified flags are `--stack-id` (required), `--resource-addresses`, `--is-provider-upgrade-required`, `--if-match`, `--from-json`, `--wait-for-state` (`ACCEPTED`, `FAILED`, `IN_PROGRESS`, `SUCCEEDED`), `--max-wait-seconds` (default 1200), and `--wait-interval-seconds` (default 30).

That 1200-second default is a **client-side** polling budget, not a documented service timeout for a `DRIFT_DETECTION` work request — and I could not find any published maximum duration for one. Do not build logic assuming drift runs are capped at 20 minutes; raise the flag and observe how long your own stacks take.

### Scoping to what you care about

On a large stack, checking everything is slow and most of the report is noise. `--resource-addresses` narrows the run:

{% highlight bash %}
oci resource-manager stack detect-drift \
  --stack-id "$STACK_ID" \
  --resource-addresses '["oci_core_security_list.prod_public","oci_core_network_security_group.app_nsg","oci_identity_policy.app_policy"]' \
  --wait-for-state SUCCEEDED
{% endhighlight %}

The address format is `{resource_type}.{resource_name}[{optional_index}]` — `oci_core_instance.test_instance[3]` for an indexed resource. These are Terraform addresses exactly as they appear in your configuration.

A genuinely useful optimization and a genuinely dangerous one: every resource you did not name stays `NOT_CHECKED`. More on that in the gotchas.

### Reading the report

{% highlight bash %}
oci resource-manager stack get --stack-id "$STACK_ID" \
  --query 'data."stack-drift-status"' --raw-output
# NOT_CHECKED | IN_SYNC | DRIFTED

oci resource-manager stack list-resource-drift-details \
  --stack-id "$STACK_ID" \
  --resource-drift-status MODIFIED --resource-drift-status DELETED \
  --all \
  --query 'data.items[].{name:"resource-name",type:"resource-type",status:"resource-drift-status"}' \
  --output table
{% endhighlight %}

`--resource-drift-status` is repeatable and accepts `DELETED`, `IN_SYNC`, `MODIFIED`, `NOT_CHECKED`; filtering to `MODIFIED` and `DELETED` gives the actionable set. Other verified flags: `--work-request-id`, `--all`, `--limit`, `--page`, `--page-size`, `--from-json`.

### When a drift run fails

As of **2026-08-12**, Resource Manager provides detailed execution logs for work requests, explicitly including drift detection. Before that a failed drift run was close to undiagnosable — you got `FAILED` and little else.

{% highlight bash %}
WR_ID="ocid1.ormworkrequest.oc1.iad.aaaa..."

oci resource-manager work-request get --work-request-id "$WR_ID"
oci resource-manager work-request list-work-request-errors --work-request-id "$WR_ID"
oci resource-manager work-request get-work-request-log-entries-content --work-request-id "$WR_ID"
{% endhighlight %}

Run `list-work-request-errors` first — that is where a missing IAM permission usually surfaces.

## Building the Sentinel

The sentinel is an OCI Function on a schedule: call `DetectStackDrift` per stack, wait for the work request, pull the `MODIFIED` and `DELETED` records, publish to Notifications if there is anything to say.

{% highlight python %}
import io, json, logging, os
import oci
from fdk import response

STACK_IDS = [s.strip() for s in os.environ["STACK_IDS"].split(",") if s.strip()]
TOPIC_ID  = os.environ["ONS_TOPIC_ID"]
SIGNER    = oci.auth.signers.get_resource_principals_signer()

rm  = oci.resource_manager.ResourceManagerClient(config={}, signer=SIGNER)
ons = oci.ons.NotificationDataPlaneClient(config={}, signer=SIGNER)


def check_stack(stack_id: str) -> dict:
    # 202 -> data is None; the work request OCID lives in the response header
    resp = rm.detect_stack_drift(
        stack_id=stack_id,
        detect_stack_drift_details=oci.resource_manager.models.DetectStackDriftDetails(
            is_provider_upgrade_required=False
        ),
    )
    wr_id = resp.headers["opc-work-request-id"]

    oci.wait_until(
        rm,
        rm.get_work_request(wr_id),
        evaluate_response=lambda r: r.data.status in ("SUCCEEDED", "FAILED"),
        max_wait_seconds=1500,
        max_interval_seconds=15,
    )

    drifted = oci.pagination.list_call_get_all_results(
        rm.list_stack_resource_drift_details,
        stack_id=stack_id,
        work_request_id=wr_id,
        resource_drift_status=["MODIFIED", "DELETED"],
    ).data

    stack = rm.get_stack(stack_id).data
    return {
        "stack": stack.display_name,
        "stack_id": stack_id,
        "stack_drift_status": stack.stack_drift_status,
        "work_request_id": wr_id,
        "findings": [
            {
                "resource": d.resource_name,
                "type": d.resource_type,
                "status": d.resource_drift_status,
                "changed": {
                    k: {"expected": d.expected_properties.get(k), "actual": v}
                    for k, v in (d.actual_properties or {}).items()
                    if (d.expected_properties or {}).get(k) != v
                },
            }
            for d in drifted
        ],
    }


def handler(ctx, data: io.BytesIO = None):
    results = [check_stack(s) for s in STACK_IDS]
    drifted = [r for r in results if r["findings"]]

    if drifted:
        body = json.dumps(drifted, indent=2, default=str)[:60000]   # ONS cap is 64 KB
        ons.publish_message(
            topic_id=TOPIC_ID,
            message_details=oci.ons.models.MessageDetails(
                title=f"[IaC DRIFT] {len(drifted)} stack(s) drifted",
                body=body,
            ),
            message_type="RAW_TEXT",
        )

    return response.Response(
        ctx,
        response_data=json.dumps({"checked": len(results), "drifted": len(drifted)}),
        headers={"Content-Type": "application/json"},
    )
{% endhighlight %}

Three lines carry most of the weight. `resp.headers["opc-work-request-id"]` is the whole async contract; nothing useful comes back in `resp.data`. `work_request_id=wr_id` is the race fix — drop it and you get whatever work request finished most recently, which under concurrency may not be yours. And the `changed` comprehension does the diff: because both property maps are flat string dictionaries, one pass over the keys turns the finding into `ingress_security_rules.0.source: expected 10.0.0.0/16, actual 0.0.0.0/0` rather than two blobs of JSON to eyeball.

The `[:60000]` truncation is not paranoia — the ONS body limit is 64 KB, and a few hundred drifted resources blows past it; publish a summary and put the full report in Object Storage with a link. Set `STACK_IDS` and `ONS_TOPIC_ID` as function configuration values; neither is a secret, and anything that is belongs in Vault.

### Topic, subscription, and schedule in Terraform

{% highlight hcl %}
resource "oci_ons_notification_topic" "iac_drift" {
  compartment_id = var.security_compartment_ocid
  name           = "iac-drift-alerts"
  description    = "Resource Manager drift detection findings"
}

resource "oci_ons_subscription" "iac_drift_email" {
  compartment_id = var.security_compartment_ocid
  topic_id       = oci_ons_notification_topic.iac_drift.id
  protocol       = "EMAIL"
  endpoint       = var.security_team_email
}

# Resource Scheduler cannot act on RM stacks. It CAN invoke a Function.
# Supported actions: BACKUP_RESOURCE | START_RESOURCE | STOP_RESOURCE
resource "oci_resource_scheduler_schedule" "nightly_drift" {
  compartment_id     = var.security_compartment_ocid
  display_name       = "nightly-iac-drift-scan"
  action             = "START_RESOURCE"
  recurrence_type    = "CRON"
  recurrence_details = "0 3 * * *"
  local_time_zone    = "UTC"

  resources {
    id = oci_functions_function.drift_sentinel.id
  }
}
{% endhighlight %}

Read that comment carefully — it is a common wrong turn. **Resource Scheduler is not scheduling the stack.** It has no concept of a Resource Manager stack, and its action verbs are `BACKUP_RESOURCE`, `START_RESOURCE`, and `STOP_RESOURCE`. What it can do is invoke a Function, and `START_RESOURCE` against a `fnfunc` is how. The stack never appears in the schedule at all — the function knows which stacks to check from its own configuration.

The schedule authenticates as itself, so it needs its own dynamic group and policy:

{% highlight text %}
ALL {resource.type='resourceschedule', resource.id='ocid1.resourceschedule.oc1.iad.aaaa...'}

Allow dynamic-group resource-scheduler-drift-dg to manage functions-family in compartment security
{% endhighlight %}

One upside of routing through Resource Scheduler: scheduled invocations are **detached**, giving a longer timeout than a synchronous invoke — which matters, because drift on a large stack can outlast the synchronous window.

### Reading drift status from Terraform

There is a read-only data source, useful for dashboards and for gating other Terraform:

{% highlight hcl %}
data "oci_resourcemanager_stack" "prod_network" {
  stack_id = var.prod_network_stack_ocid
}

output "prod_network_drift" {
  value = {
    status       = data.oci_resourcemanager_stack.prod_network.stack_drift_status
    last_checked = data.oci_resourcemanager_stack.prod_network.time_drift_last_checked
    tf_version   = data.oci_resourcemanager_stack.prod_network.terraform_version
  }
}
{% endhighlight %}

Now the part people find surprising, said outright: **there is no managed Terraform resource for Resource Manager stacks.** The only managed RM resource in the `oracle/oci` provider is `oci_resourcemanager_private_endpoint`. Everything else is read-only — `oci_resourcemanager_stack`, `oci_resourcemanager_stacks`, `oci_resourcemanager_stack_tf_state`. You cannot `terraform apply` a drift check, and you cannot manage stacks as Terraform resources. The data sources let you *read* drift status some other process produced. Any design assuming otherwise falls apart at the first `terraform plan`.

## The GitHub Actions Alternative

If your team already runs CI in GitHub and would rather not operate a Function, the same logic fits a scheduled workflow.

{% highlight yaml %}
name: iac-drift-scan
on:
  schedule: [{ cron: "0 3 * * *" }]
  workflow_dispatch:

jobs:
  drift:
    runs-on: ubuntu-latest
    env:
      OCI_CLI_USER:        ${{ secrets.OCI_CLI_USER }}
      OCI_CLI_TENANCY:     ${{ secrets.OCI_CLI_TENANCY }}
      OCI_CLI_FINGERPRINT: ${{ secrets.OCI_CLI_FINGERPRINT }}
      OCI_CLI_KEY_CONTENT: ${{ secrets.OCI_CLI_KEY_CONTENT }}
      OCI_CLI_REGION:      ${{ secrets.OCI_CLI_REGION }}
    steps:
      - uses: oracle-actions/run-oci-cli-command@v1.3.2
        id: drift
        with:
          command: >-
            resource-manager stack detect-drift
            --stack-id ${{ vars.STACK_ID }}
            --wait-for-state SUCCEEDED

      - uses: oracle-actions/run-oci-cli-command@v1.3.2
        id: report
        with:
          command: >-
            resource-manager stack list-resource-drift-details
            --stack-id ${{ vars.STACK_ID }}
            --resource-drift-status MODIFIED --resource-drift-status DELETED
            --all
          query: 'data.items[].{name:"resource-name",status:"resource-drift-status"}'

      - name: Fail the build on drift
        run: |
          echo '${{ steps.report.outputs.raw_output }}' | jq -e 'length == 0' \
            || { echo "::error::IaC drift detected"; exit 1; }
{% endhighlight %}

The `oracle-actions/run-oci-cli-command` action masks command output from the logs by default — sane for something handling OCIDs and state — so you read `raw_output` rather than the log.

On authentication: this uses an API key in repository secrets, which is what Oracle documents; a session token works too. **Do not** build it around a GitHub OIDC keyless flow — there is no primary OCI documentation for GitHub Actions OIDC federation into OCI, and while the topic comes up periodically it is emerging rather than supported. Plan for key rotation instead of hoping for keyless.

The trade-off against the Function: CI-native visibility and a red build, but the credential now lives in GitHub rather than in a resource principal that never leaves OCI.

## Optional: Custom Metric and Alarm

For a graph and a Monitoring alarm rather than just email, post the drifted-resource count as a custom metric.

{% highlight bash %}
COUNT=$(oci resource-manager stack list-resource-drift-details \
  --stack-id "$STACK_ID" --resource-drift-status MODIFIED --resource-drift-status DELETED \
  --all --query 'length(data.items)' --raw-output)

oci monitoring metric-data post --metric-data '[{
  "namespace": "iac_governance",
  "compartmentId": "'"$COMPARTMENT_ID"'",
  "name": "drifted_resources",
  "dimensions": {"stackId": "'"$STACK_ID"'", "stackName": "prod-network"},
  "datapoints": [{"timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'", "value": '"$COUNT"'}]
}]'
{% endhighlight %}

Two gotchas that cost an hour each if you hit them cold. Metric ingestion uses a **different endpoint** from metric queries — `telemetry-ingestion` rather than `telemetry`, e.g. `https://telemetry-ingestion.eu-frankfurt-1.oraclecloud.com`; the CLI usually handles this, SDK code frequently does not, and the error is unhelpful. And timestamps are validated at no more than 2 hours in the past and 10 minutes in the future, so a container with a skewed clock silently drops every datapoint.

With the metric flowing, an alarm on `drifted_resources[1m].max() > 0` gives you the dashboard tile and the escalation path.

## Testing and Validation

Do not trust any of this until you have watched it catch a drift you created on purpose. This lab takes about fifteen minutes and reproduces the opening scenario exactly.

**Step 1 — Establish a clean baseline.**

{% highlight bash %}
oci resource-manager stack detect-drift --stack-id "$STACK_ID" --wait-for-state SUCCEEDED
oci resource-manager stack get --stack-id "$STACK_ID" \
  --query 'data."stack-drift-status"' --raw-output
# expect: IN_SYNC
{% endhighlight %}

If this returns `NOT_CHECKED`, the check did not run — confirm the last job was an Apply or Import State.

**Step 2 — Introduce drift out of band**, the way an on-call engineer would, bypassing Terraform entirely:

{% highlight bash %}
oci network security-list update --security-list-id "$SL_ID" --force \
  --ingress-security-rules '[{"protocol":"6","source":"0.0.0.0/0","isStateless":false,
    "tcpOptions":{"destinationPortRange":{"min":22,"max":22}}}]'
{% endhighlight %}

**Step 3 — Re-run the check.**

{% highlight bash %}
oci resource-manager stack detect-drift --stack-id "$STACK_ID" --wait-for-state SUCCEEDED
oci resource-manager stack get --stack-id "$STACK_ID" \
  --query 'data."stack-drift-status"' --raw-output
# expect: DRIFTED
{% endhighlight %}

**Step 4 — Inspect the diff.**

{% highlight bash %}
oci resource-manager stack list-resource-drift-details --stack-id "$STACK_ID" \
  --resource-drift-status MODIFIED --all \
  --query 'data.items[].{r:"resource-name",actual:"actual-properties",expected:"expected-properties"}'
# expect: ingress_security_rules.0.source -> actual "0.0.0.0/0" vs expected "10.0.0.0/16"
{% endhighlight %}

**Step 5 — Attribute it.** Drift tells you *what* changed and returns no actor — there is no `principal` field anywhere in `StackResourceDriftSummary`. For *who*, cross-reference `resource_id` against the Audit service:

{% highlight bash %}
oci audit event list --compartment-id "$COMPARTMENT_ID" \
  --start-time "$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)" \
  --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --query 'data[?data."event-name"==`UpdateSecurityList`].{who:data.identity."principal-name",ip:data.identity."ip-address",when:"event-time"}'
{% endhighlight %}

The Audit record carries `identity.principalName`, `principalId`, `ipAddress`, `userAgent`, and `authType`. Drift plus Audit is the whole story; either alone is half of it.

**Step 6 — Remediate through IaC, not the console.** The instinct is to click the rule back to `10.0.0.0/16`. Resist it — that fixes the symptom and leaves the process broken. Reapply the stack:

{% highlight bash %}
oci resource-manager job create-apply-job --stack-id "$STACK_ID" \
  --execution-plan-strategy AUTO_APPROVED --wait-for-state SUCCEEDED
{% endhighlight %}

**Step 7 — Confirm you are clean again.**

{% highlight bash %}
oci resource-manager stack detect-drift --stack-id "$STACK_ID" --wait-for-state SUCCEEDED
{% endhighlight %}

### Two negative tests

Positive tests prove the happy path. These two prove the failure modes are real.

**The stale report race.** Kick off a drift run and, while it is still `IN_PROGRESS`, run step 4 *without* `--work-request-id`. You get a complete, plausible, well-formed report from the *previous* work request. Nothing errors, nothing warns. That is what your pipeline does every time two runs overlap, and it is why the sentinel passes the OCID explicitly.

**The read-only wall.** Create a group with only `read orm-stacks`, authenticate as a member, and run `detect-drift`. It fails on authorization. Do this rather than taking my word for the `manage` requirement — seeing the denial makes the trade-off concrete when you explain to a reviewer why the auditor identity holds delete rights.

## State-Based vs Event-Based: You Need Both

If you have implemented the CIS OCI Foundations Benchmark you already monitor much of this. Section 4, Logging and Monitoring (4.x numbering — it was 3.x in the v1.x releases, so state your version), requires a notification topic and subscription (4.2) plus Events-based alerting on Identity Provider changes (4.3), IdP group mappings (4.4), IAM groups (4.5), IAM policies (4.6), user changes (4.7), VCNs (4.8), route tables (4.9), security lists (4.10), NSGs (4.11), and network gateways (4.12).

So if CIS 4.10 already alerts on security list changes, what does drift detection add?

**CIS 4.3 through 4.12 are event-based: they tell you a change happened. Drift detection is state-based: it tells you the change is still there.**

Take one NSG and two stories.

In the first, an engineer widens an NSG rule at 03:12 during an incident, fixes the problem, and reverts the rule at 03:34. CIS 4.11 fires twice — once for the change, once for the revert. Drift detection, running at 04:00, finds nothing, because there is nothing to find. The configuration matches the code. The system is correct.

In the second, the same engineer widens the same rule at 03:12, fixes the problem, and goes back to bed. CIS 4.11 fires exactly **once**, at 03:12, into the same alert channel already saturated with incident traffic, and it is never mentioned again. Drift detection finds that NSG `MODIFIED` at 04:00. And at 04:00 the next day. And every day after that, until somebody fixes it.

That is the asymmetry. Event-based alerting is loudest at the moment you are least able to act on it and goes silent the moment the incident ends. State-based detection is quiet during the incident and stays exactly as loud for as long as the problem persists. The one alert you actually needed and the one alert you were guaranteed to miss are the same alert. Drift detection is what turns a missed notification into a standing finding.

Both are real controls. Events give you the timeline and the actor; drift gives you the persistent divergence. Running only one leaves a gap a patient attacker can walk through.

For the paperwork this maps to NIST SP 800-53 **CM-2** (Baseline Configuration), **CM-3** (Configuration Change Control), **CM-6** (Configuration Settings), **CM-8** (System Component Inventory), **SI-7** (Software, Firmware, and Information Integrity), and **AU-6** (Audit Record Review, Analysis, and Reporting). Drift detection is one of the few controls producing machine-readable evidence for CM-2 and CM-3 rather than a screenshot.

## If You Need Real Time: The Plan-Job-With-Refresh Workaround

Everything above is a poller, with detection latency floored by your scan interval. If you genuinely need an event-driven signal, one workaround trades report quality for immediacy.

Plan jobs **do** emit `com.oraclecloud.oracleresourcemanager.createjob.end`. And a plan job with `terraformAdvancedOptions.isRefreshRequired = true` performs a real state refresh against live infrastructure, so the plan output contains the divergence between code and reality. That is drift, reached by a different route — and the chain that does not exist for drift detection *does* exist for plan jobs:

{% highlight text %}
[Scheduled plan job w/ refresh] ──► createjob.end event ──► [Events rule] ──► [Function] ──► [ONS]
{% endhighlight %}

You still need something to trigger the plan job, so this is not free of scheduling — but the completion signal is a real event, so downstream consumers are event-driven and you can fan out through the Events service like any other OCI service.

The trade-off is that you lose the structured per-resource report: no `StackResourceDriftSummary`, no `MODIFIED` versus `DELETED` classification, no flat property maps to diff. You get plan output, and you parse it — a meaningfully worse input for automated triage. Use drift detection as the primary control on a schedule, and reach for plan-with-refresh only where latency matters more than report structure.

## Limitations and Gotchas

1. **No Events integration.** Verified against the complete published event list above. Every "wire drift to an Events rule" design is wrong at the producer.
2. **It is a work request, not a job.** `job list` never shows a drift run. Use `work-request list`.
3. **Terraform is capped at 1.5.x**, and since 2026-04-30 stacks below that cannot create jobs. Check `terraform_version` before debugging anything else.
4. **No Terraform resource for stacks.** Data sources only, plus the private endpoint resource.
5. **The stack must be in the right state.** Last job Apply or Import State, or newly created from compartment discovery.
6. **One job at a time per stack.** Drift contends with an in-flight apply, so in a busy CI environment the nightly scan can lose that race. Handle the conflict rather than assume the scan ran.
7. **`ListStackResourceDriftDetails` silently defaults to the latest completed work request.** Always pass `--work-request-id` in automation.
8. **Resource Scheduler cannot touch Resource Manager.** Schedule a Function, with its own dynamic group and policy.
9. **`NOT_CHECKED` is not `IN_SYNC`.** This is the one that will burn you. If you scoped a run with `--resource-addresses`, every resource you did not name stays `NOT_CHECKED` — which means "I have no idea," not "clean." A dashboard counting anything-other-than-`MODIFIED` as healthy shows a reassuring green tile over a stack you last fully checked in March. If you scope scans, either alert on the `NOT_CHECKED` count directly or run a full unscoped check on a slower cadence. Treat `NOT_CHECKED` as a finding in its own right.
10. **ONS has hard limits.** 64 KB body, 60 messages/minute per HTTPS endpoint, 10/minute for email, 60 TPM per topic. A few hundred drifted resources exceeds the body limit — summarize and link out.
11. **The feature is free; the API calls have consequences.** A drift check makes read calls against every managed resource — on a very large stack that is a throttling risk against the underlying services, not against RM.
12. **`ORM_JOB_READ` is a state-file and configuration exfiltration path.** Segregate state into a restrictive compartment; keep secrets in Vault.
13. **Detailed drift logs only landed 2026-08-12.** Depending on regional rollout, older failures may still be opaque; if `get-work-request-log-entries-content` returns nothing useful, fall back to `list-work-request-errors`.

Three things I am explicitly **not** asserting, because I could not verify them:

- **No documented maximum duration or service-side timeout exists for a `DRIFT_DETECTION` work request.** The CLI's 1200-second default is client-side polling; do not present it as a service limit.
- **Oracle publishes no list of resource types unsupported by drift detection.** I could not find one and will not invent one. Validate coverage empirically by drifting a resource of each type you care about and confirming it is reported.
- **Numeric Resource Manager service limits** for stacks or jobs per tenancy are not published. "Premium jobs" shipped 2026-07-07 with no accompanying numbers.

## Best Practices

**Scan security-relevant stacks more often than the rest.** A stack managing security lists, NSGs, IAM policies, and Cloud Guard configuration earns an hourly scan; one managing a static Object Storage bucket earns a weekly one. Use `--resource-addresses` to keep the frequent scans cheap — then follow gotcha #9 and run a full unscoped scan on a slower cadence so nothing lives at `NOT_CHECKED` forever.

**Give DELETED its own alert path.** A `MODIFIED` security list is a ticket. A `DELETED` Cloud Guard target, [vulnerability scanning recipe]({% link _posts/2026/2026-05-16-oci-vulnerability-scanning-terraform.md %}), or logging configuration is a page. Branch on `resource_drift_status == "DELETED"` in the function and publish to a second topic. Deleting a detective control is the loudest thing an attacker can do that makes no noise.

**Pair every drift alert with an Audit query.** Drift says what, Audit says who. Build the lookup into the sentinel — you have `resource_id` right there, so a `list_events` filtered on it turns an anonymous finding into an attributable one before a human reads it.

**Remediate by reapplying the stack, never in the console.** A console fix removes the drift and preserves the process failure that created it. An apply job removes the drift, leaves an auditable correction, and makes it obvious in the job history how often this happens.

**Track drift-days, not just drift-count.** How many resources are drifted matters less than how long. A stack that drifts every Tuesday and self-corrects on Wednesday has a process problem; a single resource `MODIFIED` for ninety days is an unowned production system. The custom metric gives you the time series to tell them apart.

**Layer drift behind prevention, not instead of it.** [Security Zones]({% link _posts/2026/2026-03-25-oci-security-zones-part2.md %}) refuses the non-compliant change at the API, and catching it six hours later is strictly worse. If a drift class keeps recurring, the fix is a Security Zone policy, not a better alert.

**Alert on the check itself failing.** A `FAILED` work request and a stack unchecked for eleven days both look like silence. Publish a heartbeat from the sentinel and alarm on its absence, or `time_drift_last_checked` goes quietly stale while you believe you have coverage you do not have.

## Wrapping Up

Resource Manager's drift detection is a good feature with one architectural gap: it produces no event, so the obvious automation path is closed. Build a poller that publishes its own signal and everything downstream works as you would expect — because you are the producer now.

The parts worth carrying away: it is a work request, not a job. The OCID is in a response header, not the body. Pass it explicitly to the details call or you will read stale reports under concurrency. `manage orm-stacks` is required to run the check, so your read-only auditor is not read-only — know that going in rather than discovering it in a security review. And `NOT_CHECKED` is not `IN_SYNC`, which has probably caused more false confidence than every other item on the list combined.

Start with one stack. Run the deliberate-drift lab, run both negative tests so you have seen the failure modes rather than read about them, then wire in the Function and let it watch your security-critical stacks for a month before widening scope. What you learn in that month — which stacks drift, how often, and who is doing it — is usually worth more than the alerts themselves.

Happy scripting!
