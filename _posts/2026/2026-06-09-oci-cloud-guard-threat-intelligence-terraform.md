---
title: 'OCI Cloud Guard Terraform: Threat Intelligence and Auto-Remediation'
author: Victor Silva
date: 2026-06-09T23:40:16+00:00
layout: post
permalink: /oci-cloud-guard-threat-intelligence-terraform/
excerpt: "Enable OCI Cloud Guard with Terraform: clone detector and responder recipes, wire automated remediation via OCI Events and Functions, and query Threat Intelligence IOCs from the CLI."
categories:
  - OCI
  - Security
tags:
  - oci-cloud-guard
  - cloud-guard
  - threat-intelligence
  - terraform
  - oracle-cloud
  - oci
  - security-posture
  - cspm
  - oci-functions
  - security-zones
  - devsecops
---

OCI Cloud Guard is the continuous CSPM service that catches misconfigurations before they become incidents. A public Object Storage bucket created by a developer who didn't read the documentation. An IAM user provisioned without MFA because it was "just for testing". A database with a public endpoint because the private subnet setup was skipped to save time. These aren't exotic attack scenarios — they are the Monday morning findings in most cloud security reviews. Cloud Guard monitors your tenancy for exactly these issues, scores your security posture, and can remediate problems automatically.

Paired with OCI Threat Intelligence, it adds ML-driven detection of indicators of compromise: IP addresses, domains, and file hashes associated with known malicious activity.

In this post we will provision the complete security stack from scratch with Terraform: OCI Cloud Guard enabled at the tenancy root, custom detector and responder recipes, automated remediation via OCI Events and OCI Functions, and the CLI commands to query Threat Intelligence IOCs and your security score. By the end you will have infrastructure-as-code for your OCI security posture that you can version, review, and apply consistently across environments. If you have not yet set up your IAM foundations, the [OCI IAM Terraform post](/oci-iam-terraform/) covers compartments, dynamic groups, and policies as a prerequisite.

## OCI Security Stack: How Cloud Guard, Threat Intelligence, and Events Fit Together

Before opening Terraform it is worth being clear about the four services involved, because the OCI documentation treats each independently and the integration points are not always obvious.

**Security Advisor** acts at resource creation time. It constrains what resources you can create inside [OCI Security Zones](/oci-security-zones-part2/) by enforcing a set of security policies — for example, preventing a bucket from being created with public access in a production compartment. Think of it as a preventive guardrail.

**Cloud Guard** acts continuously, post-creation. It evaluates existing resources against detector rules and raises Problems when it finds issues. It also runs ML-based threat detection using behavioral signals. Where Security Advisor prevents, Cloud Guard detects and responds.

**OCI Threat Intelligence** is the IOC feed that Cloud Guard's Threat Detector recipe consumes automatically. It provides IP addresses, domains, URLs, and file hashes with confidence scores — sourced from Oracle security researchers, abuse.ch, Tor exit relay lists, and partner feeds. No additional wiring is needed beyond enabling the Threat Detector recipe on a target.

**OCI Events + Functions** is where automated remediation lives. Cloud Guard emits events when it detects Problems. You define event rules that filter on those events and route them to OCI Functions. The function receives the event payload, inspects the resource involved, and takes action — making a bucket private, stopping an instance, or filing a ticket.

{% highlight text %}
┌─────────────────────────────────────────────────────────┐
│                    OCI Tenancy                          │
│                                                         │
│  ┌──────────────┐    creates secure    ┌─────────────┐  │
│  │  Security    │─────resources──────▶ │  Security   │  │
│  │  Advisor     │                      │  Zones      │  │
│  └──────────────┘                      └──────┬──────┘  │
│                                               │detects   │
│                                               │violations│
│  ┌────────────────────────────────────────────▼──────┐  │
│  │              Cloud Guard                          │  │
│  │  ┌────────────────┐  ┌─────────────────────────┐ │  │
│  │  │ Detector       │  │  Responder Recipes      │ │  │
│  │  │ Recipes        │  │  - Notification         │ │  │
│  │  │ - Config       │  │  - Remediation          │ │  │
│  │  │ - Activity     │  │    (Make Bucket         │ │  │
│  │  │ - Threat       │  │     Private, Stop       │ │  │
│  │  │ - Instance Sec │  │     Instance, etc.)     │ │  │
│  │  │ - Container    │  └────────────┬────────────┘ │  │
│  │  └───────┬────────┘               │              │  │
│  └──────────│───────────────────────-│──────────────┘  │
│             │                        │                  │
│  ┌──────────▼──────────┐   ┌─────────▼──────────┐      │
│  │  Threat Intelligence│   │  OCI Events +      │      │
│  │  (IOC feeds,        │   │  Notifications +   │      │
│  │   confidence scores)│   │  Functions         │      │
│  └─────────────────────┘   └────────────────────┘      │
└─────────────────────────────────────────────────────────┘
{% endhighlight %}

Cloud Guard organizes its logic around **recipes** and **targets**. Detector recipes define what to look for. Responder recipes define what to do when something is found. A target applies both to a scope — a compartment or the tenancy root. Oracle provides managed Oracle-maintained recipes that you cannot modify directly; you clone them, then customize the clone.

## Prerequisites

You will need:

- OCI CLI installed and configured (`oci --version` should return 3.x or higher)
- Terraform >= 1.5 with the OCI provider (`hashicorp/oci >= 6.0`)
- IAM administrator access on the tenancy, or at minimum `manage cloud-guard-family in tenancy`
- A chosen reporting region — this decision is permanent. Cloud Guard stores all problem history in the reporting region. Once set, it cannot be changed without disabling Cloud Guard and losing all existing data. Choose the region where your audit and compliance teams work, not just the region closest to your workloads.

Verify the OCI CLI can reach Cloud Guard before starting:

{% highlight bash %}
# Confirm CLI is configured
oci --version
oci iam region list --query 'data[*].name' --output table

# Check current Cloud Guard status (may return an error if not yet enabled)
oci cloud-guard configuration get \
  --compartment-id $TENANCY_OCID
{% endhighlight %}

If Cloud Guard has never been enabled in the tenancy, the last command returns a 404. That is expected and exactly what the Terraform configuration will fix.

## Implementing the Stack with Terraform

We will build the configuration across three files: `cloud_guard.tf` for the main Cloud Guard resources, `iam.tf` for the required policies, and `events.tf` for the automated remediation plumbing.

### Step 1: Enable Cloud Guard

Cloud Guard is enabled at the tenancy level via `oci_cloud_guard_cloud_guard_configuration`. This is a singleton resource — there is only one per tenancy.

Create `cloud_guard.tf` and start with enabling the service:

{% highlight hcl %}
resource "oci_cloud_guard_cloud_guard_configuration" "tenancy_cloud_guard" {
  compartment_id        = var.tenancy_ocid
  reporting_region      = var.reporting_region
  status                = "ENABLED"
  self_manage_resources = false
}
{% endhighlight %}

The `self_manage_resources = false` setting tells Cloud Guard to use Oracle-managed detector and responder recipes as the base. If you set this to `true`, Oracle's managed recipes are not provisioned and you must supply every recipe from scratch — a footgun that leaves Cloud Guard not functioning without immediately obvious errors. Leave it `false`.

### Step 2: Clone and Customize the Detector Recipe

Oracle's managed recipes are read-only. To customize rules, you clone a managed recipe into your own compartment and override the specific rules you care about. The data source fetches the list of Oracle-managed recipes; you reference the first active one as the source.

{% highlight hcl %}
data "oci_cloud_guard_detector_recipes" "oracle_config_recipe" {
  compartment_id = var.tenancy_ocid
  state          = "ACTIVE"
}

resource "oci_cloud_guard_detector_recipe" "custom_config_recipe" {
  compartment_id            = var.security_compartment_ocid
  display_name              = "Custom-OCI-Config-Detector"
  source_detector_recipe_id = data.oci_cloud_guard_detector_recipes.oracle_config_recipe.detector_recipe_collection[0].items[0].id

  detector_rules {
    detector_rule_id = "BUCKET_IS_PUBLIC"
    details {
      is_enabled = true
      risk_level = "CRITICAL"
    }
  }

  detector_rules {
    detector_rule_id = "USER_WITHOUT_MFA"
    details {
      is_enabled = true
      risk_level = "CRITICAL"
    }
  }

  freeform_tags = {
    "environment" = "production"
    "managed-by"  = "terraform"
  }
}
{% endhighlight %}

A critical point about this block: only override the rules you are explicitly changing. The OCI Terraform provider has a known ordering issue ([provider bug #2509](https://github.com/oracle/terraform-provider-oci/issues/2509)) where non-deterministic rule ordering causes spurious diffs on every `terraform plan`. If you enumerate all rules in the recipe here, you will fight constant apply failures. List only the rules you are customizing — the rest inherit their settings from the Oracle-managed source.

The two rules above cover the most common critical findings:

- `BUCKET_IS_PUBLIC` — detects Object Storage buckets with `ObjectRead` or `ObjectReadWithoutList` public access set
- `USER_WITHOUT_MFA` — detects IAM users that have never configured a TOTP or FIDO2 authenticator

For reference, other high-value rules to consider enabling at `CRITICAL` level:

| Rule ID | Service |
|---|---|
| `INSTANCE_IS_PUBLICLY_ACCESSIBLE` | Compute |
| `DB_SYSTEM_IS_PUBLIC` | Database |
| `POLICY_ALLOWS_TOO_MANY_PRIVS` | IAM |
| `API_KEY_IS_TOO_OLD` | IAM |
| `LOAD_BALANCER_WEAK_SSL` | Networking |

### Step 3: Clone the Responder Recipe

Responders are what Cloud Guard does when a Problem is confirmed. Clone the Oracle-managed responder recipe and override the rules you want to run automatically:

{% highlight hcl %}
data "oci_cloud_guard_responder_recipes" "oracle_responder" {
  compartment_id = var.tenancy_ocid
  state          = "ACTIVE"
}

resource "oci_cloud_guard_responder_recipe" "custom_responder" {
  compartment_id             = var.security_compartment_ocid
  display_name               = "Custom-OCI-Responder"
  source_responder_recipe_id = data.oci_cloud_guard_responder_recipes.oracle_responder.responder_recipe_collection[0].items[0].id

  responder_rules {
    responder_rule_id = "MAKE_BUCKET_PRIVATE"
    details {
      is_enabled = true
      mode       = "AUTOACTION"
    }
  }

  responder_rules {
    responder_rule_id = "CLOUD_EVENTS"
    details {
      is_enabled = true
      mode       = "AUTOACTION"
    }
  }
}
{% endhighlight %}

`MAKE_BUCKET_PRIVATE` is a built-in remediation action that sets the bucket's `publicAccessType` to `NoPublicAccess` automatically — no Function needed. `CLOUD_EVENTS` triggers an OCI Event when Cloud Guard creates a Problem, which is the hook used by the Events + Functions pipeline we will wire up shortly.

`mode = "AUTOACTION"` means the responder fires without waiting for human approval. For remediation actions that affect production resources, you may prefer `mode = "USERACTION"` — it creates a recommendation that a human must approve in the Cloud Guard console before the action executes. For a public bucket in production, `AUTOACTION` is almost always the right choice: the remediation is safe to run automatically and delay creates risk.

### Step 4: Create the Cloud Guard Target

A target applies the detector and responder recipes to a scope. Targeting the tenancy root compartment covers everything:

{% highlight hcl %}
resource "oci_cloud_guard_target" "tenancy_target" {
  compartment_id       = var.tenancy_ocid
  display_name         = "Tenancy-Root-Target"
  target_resource_id   = var.tenancy_ocid
  target_resource_type = "COMPARTMENT"

  target_detector_recipes {
    detector_recipe_id = oci_cloud_guard_detector_recipe.custom_config_recipe.id
  }

  target_responder_recipes {
    responder_recipe_id = oci_cloud_guard_responder_recipe.custom_responder.id
  }

  depends_on = [oci_cloud_guard_cloud_guard_configuration.tenancy_cloud_guard]
}
{% endhighlight %}

The `depends_on` is necessary. Terraform cannot automatically detect the dependency between Cloud Guard being enabled and the target being created, because both reference `var.tenancy_ocid` and the dependency flows through the API state rather than through a resource attribute. Without the explicit `depends_on`, Terraform may try to create the target before the service is enabled and fail with a 409.

One more thing to be aware of: if you have previously enabled OCI Security Zones, Cloud Guard may have auto-created a target during that process. Terraform cannot update auto-created targets ([issue #1618](https://github.com/oracle/terraform-provider-oci/issues/1618)). If you run `terraform apply` and get a conflict on the target resource, import the existing target into Terraform state with `terraform import oci_cloud_guard_target.tenancy_target <target_ocid>` before proceeding.

### Step 5: IAM Policies

Cloud Guard requires two sets of policies: one for the service principal (`cloudguard`) to read resources across the tenancy, and one to allow your security team to manage Cloud Guard configuration.

Create `iam.tf`:

{% highlight hcl %}
resource "oci_identity_policy" "cloud_guard_service" {
  name           = "cloud-guard-service-policies"
  description    = "Required policies for Cloud Guard service principal"
  compartment_id = var.tenancy_ocid

  statements = [
    "allow service cloudguard to read audit-events in tenancy",
    "allow service cloudguard to read authentication-policies in tenancy",
    "allow service cloudguard to read compartments in tenancy",
    "allow service cloudguard to read compute-management-family in tenancy",
    "allow service cloudguard to read database-family in tenancy",
    "allow service cloudguard to read dynamic-groups in tenancy",
    "allow service cloudguard to read groups in tenancy",
    "allow service cloudguard to read instance-family in tenancy",
    "allow service cloudguard to read keys in tenancy",
    "allow service cloudguard to read load-balancers in tenancy",
    "allow service cloudguard to read log-groups in tenancy",
    "allow service cloudguard to read object-family in tenancy",
    "allow service cloudguard to read policies in tenancy",
    "allow service cloudguard to read tenancies in tenancy",
    "allow service cloudguard to read users in tenancy",
    "allow service cloudguard to read vaults in tenancy",
    "allow service cloudguard to read virtual-network-family in tenancy",
    "allow service cloudguard to read volume-family in tenancy",
    "allow service cloudguard to use network-security-groups in tenancy",
    "allow service cloudguard to manage cloudevents-rules in tenancy where target.rule.type='managed'",
    "allow service cloudguard to manage buckets in tenancy",
    "allow service cloudguard to manage instances in tenancy",
  ]
}

resource "oci_identity_policy" "security_admin_cloud_guard" {
  name           = "security-admin-cloud-guard"
  description    = "Allows SecurityAdmins to manage Cloud Guard"
  compartment_id = var.tenancy_ocid

  statements = [
    "allow group SecurityAdmins to manage cloud-guard-family in tenancy",
  ]
}
{% endhighlight %}

The `manage buckets` and `manage instances` policies are what makes automatic remediation work. Without them, Cloud Guard can detect problems but cannot execute responders — and the failure mode is silent: the Problem appears, the responder fires, and nothing happens. These two verbs are worth the risk because Cloud Guard only acts on resources where it has detected a confirmed problem, not arbitrarily.

## Automated Remediation with OCI Events and Functions

The `CLOUD_EVENTS` responder emits an OCI Event whenever Cloud Guard creates or updates a Problem. You can intercept these events and route them to an OCI Function for custom remediation logic. This is the right pattern for anything beyond the built-in responder actions.

Create `events.tf`:

{% highlight hcl %}
resource "oci_events_rule" "cloud_guard_critical_to_function" {
  compartment_id = var.reporting_compartment_ocid
  display_name   = "cloud-guard-critical-to-function"
  is_enabled     = true

  condition = jsonencode({
    eventType = ["com.oraclecloud.cloudguard.problemdetected"]
    data = {
      additionalDetails = {
        riskLevel = ["CRITICAL"]
      }
    }
  })

  actions {
    actions {
      action_type = "FAAS"
      is_enabled  = true
      function_id = oci_functions_function.cloud_guard_handler.id
    }
  }
}
{% endhighlight %}

Note that event rules must be created in the reporting region. Cloud Guard emits events only from the reporting region you configured — if the event rule lives in a different region, it will never fire.

The function handler receives the event payload, inspects the resource, and acts. The example below handles the public bucket case using Resource Principal authentication — no credentials stored in the function:

{% highlight python %}
import io
import json
import oci
from fdk import response

def handler(ctx, data: io.BytesIO = None):
    try:
        event = json.loads(data.read().decode("utf-8"))
        details = event["data"]["additionalDetails"]

        risk_level    = details.get("riskLevel", "UNKNOWN")
        resource_type = details.get("resourceType", "")
        resource_name = details.get("resourceName", "")

        signer = oci.auth.signers.get_resource_principals_signer()

        if resource_type == "Bucket" and risk_level == "CRITICAL":
            obj_client = oci.object_storage.ObjectStorageClient(
                config={}, signer=signer
            )
            ns = obj_client.get_namespace().data
            obj_client.update_bucket(
                namespace_name=ns,
                bucket_name=resource_name,
                update_bucket_details=oci.object_storage.models.UpdateBucketDetails(
                    public_access_type="NoPublicAccess"
                )
            )

        return response.Response(
            ctx,
            response_data=json.dumps({"status": "handled", "riskLevel": risk_level}),
            headers={"Content-Type": "application/json"}
        )
    except Exception as ex:
        return response.Response(
            ctx,
            response_data=json.dumps({"error": str(ex)}),
            headers={"Content-Type": "application/json"},
            status_code=500
        )
{% endhighlight %}

Resource Principal is the correct authentication mechanism for OCI Functions. The function's dynamic group needs `manage object-family in tenancy` (or the specific compartment) for the bucket remediation to work. Never hardcode credentials or use instance principals in a function — Resource Principal is designed exactly for this.

For functions to receive Cloud Guard events, the function's dynamic group also needs to be explicitly allowed to be invoked. A pattern that works well is gating the event rule behind a condition on `riskLevel = ["CRITICAL"]` (as above) to avoid unnecessary function invocations from medium or low severity findings during initial setup.

## OCI Threat Intelligence

Threat Intelligence is already wired into Cloud Guard without any additional Terraform. When you clone the Oracle-managed detector recipe, the Threat Detector detector type (separate from the Configuration detector) is included in the base. It consumes OCI's IOC feeds automatically and raises Problems when it detects communications with known malicious IPs, domains, or file hashes in your tenancy's activity logs.

What Threat Intelligence provides:

- **Indicator types**: IP addresses, domain names, URLs, MD5/SHA1/SHA256 hashes, file names
- **Confidence scores**: 0–100, sourced from Oracle security researchers, abuse.ch, Tor exit relays, and partner feeds
- **Cost**: included with OCI — no additional licensing
- **Automatic integration**: Cloud Guard's Threat Detector recipe consumes the feeds; no additional wiring needed beyond enabling the recipe

To query IOCs directly via CLI — useful for incident investigation or validating that a suspicious IP from your logs is known-bad:

{% highlight bash %}
# List high-confidence malicious IP addresses
oci threat-intelligence indicator-summaries list-indicators \
  --compartment-id $TENANCY_OCID \
  --type IP_ADDRESS \
  --confidence-above 75 \
  --sort-by confidence \
  --sort-order DESC \
  --limit 100

# List sightings — instances where Cloud Guard detected threat activity
oci cloud-guard sighting list \
  --compartment-id $TENANCY_OCID \
  --compartment-id-in-subtree true \
  --all
{% endhighlight %}

The `--compartment-id` for the `list-indicators` command must be the tenancy root OCID, not a sub-compartment. Using a sub-compartment OCID returns zero results without an error — a misleading behavior worth knowing before you spend time debugging.

One important pairing note: the Threat Detector recipe requires the Activity Detector recipe to be present on the same Cloud Guard target. Without the Activity Detector, the Threat Detector lacks the behavioral telemetry it needs and will not generate sightings. When you define `target_detector_recipes` on your Cloud Guard target, include both the Configuration detector recipe (which we cloned above) and the Activity detector recipe clone.

## Security Score and Risk Score

Cloud Guard exposes two complementary metrics for your tenancy's posture:

| Metric | What it measures | Range | Update frequency |
|---|---|---|---|
| Security Score | Percentage of monitored resources with no open problems | 0–100 | Continuous |
| Risk Score | Weighted score: total problems + resource sensitivity + severity | Numeric | Every 15 minutes |

Query both via CLI:

{% highlight bash %}
# Security Score across the tenancy
oci cloud-guard security-score-aggregation request-security-scores \
  --compartment-id $TENANCY_OCID

# Open CRITICAL problems — the primary remediation backlog
oci cloud-guard problem list \
  --compartment-id $TENANCY_OCID \
  --compartment-id-in-subtree true \
  --access-level ACCESSIBLE \
  --risk-level CRITICAL \
  --lifecycle-state OPEN \
  --all
{% endhighlight %}

One expectation to set: your Security Score on day one will appear low. Cloud Guard uses a 30-day rolling window to build a baseline. Early readings are not meaningful comparisons — they reflect that the service is still discovering the full scope of your tenancy's resources. Give it a week before drawing conclusions, and a full 30 days before using the score as a compliance metric.

## Verification

After `terraform apply` completes, run these CLI commands to confirm the stack is working correctly:

{% highlight bash %}
# Verify Cloud Guard is enabled and confirm the reporting region
oci cloud-guard configuration get \
  --compartment-id $TENANCY_OCID \
  --query 'data.{status: "status", region: "reporting-region"}'

# Verify the target is active and covering the tenancy root
oci cloud-guard target list \
  --compartment-id $TENANCY_OCID \
  --compartment-id-in-subtree true \
  --lifecycle-state ACTIVE \
  --all \
  --query 'data.items[*].{name: "display-name", resource: "target-resource-id"}'

# Verify the custom detector recipe exists in the security compartment
oci cloud-guard detector-recipe list \
  --compartment-id $SECURITY_COMPARTMENT_OCID \
  --lifecycle-state ACTIVE \
  --all \
  --query 'data.items[*].{name: "display-name", id: "id"}'

# List open problems to confirm detection is running
oci cloud-guard problem list \
  --compartment-id $TENANCY_OCID \
  --compartment-id-in-subtree true \
  --access-level ACCESSIBLE \
  --lifecycle-state OPEN \
  --all \
  --query 'data.items[*].{detector: "detector-id", risk: "risk-level", resource: "resource-name"}'
{% endhighlight %}

If Cloud Guard is enabled but the problem list returns empty after 30 minutes, the most likely cause is missing IAM policies. In particular, the `allow service cloudguard to read audit-events in tenancy` and `read object-family in tenancy` statements are the ones most often omitted. Cloud Guard does not surface IAM errors explicitly — problems simply don't appear.

## Common Terraform and Cloud Guard Gotchas

**The reporting region is permanent.** This is the most consequential decision in the entire setup. If you enable Cloud Guard with `reporting_region = "us-ashburn-1"` and later decide you want `eu-frankfurt-1`, you must disable Cloud Guard — which deletes all problem history — and re-enable it. There is no migration path. Set this once and document it.

**Terraform provider bug #2509 with detector rule ordering.** The OCI provider does not guarantee stable ordering of `detector_rules` blocks, which causes Terraform to see a diff on every plan even when nothing has changed. The workaround is to only declare `detector_rules` overrides for rules you are explicitly customizing. Do not enumerate all rules from the Oracle recipe in your clone — that is what triggers the ordering issue.

**`self_manage_resources = true` leaves Cloud Guard broken.** If you set this accidentally (or inherit a configuration that has it set), Cloud Guard enables but Oracle-managed recipes are not provisioned. The service appears active but generates no findings. The fix is to set it back to `false` and run `terraform apply` — Oracle will re-provision the managed recipes. Check the current value with `oci cloud-guard configuration get --compartment-id $TENANCY_OCID`.

**Event rules must live in the reporting region.** OCI Events rules are regional. Cloud Guard only emits events from the reporting region. If your `oci_events_rule` resource is in a different region (for example, because your Function app is deployed elsewhere), the event rule will never fire. Deploy the event rule and the function in the same region as the Cloud Guard reporting region.

**The Threat Detector needs the Activity Detector on the same target.** Enabling the Threat Detector recipe alone on a target is not sufficient. The Threat Detector uses behavioral data from the Activity Detector as its telemetry source. If the Activity Detector recipe is not also attached to the target, the Threat Detector has no data to analyze and generates no sightings. Both recipes must be present.

## Best Practices

**Target the tenancy root, not individual compartments.** A single target at the root gives Cloud Guard visibility across every compartment in your tenancy, including ones created after the target is set up. Compartment-level targets create coverage gaps whenever new compartments are added, which is common in growing tenancies. If you need different responder behavior per compartment, use compartment-level targets in addition to the root target, not instead of it.

**Use `USERACTION` mode for destructive responders.** `AUTOACTION` is appropriate for safe, reversible remediations like making a bucket private. For actions like stopping a compute instance or deleting a resource, use `mode = "USERACTION"` — require human approval before executing. The consequence of an incorrect automatic remediation on a production instance can be worse than the original finding.

**Pin the Oracle-managed recipe index with a data source filter.** The `data.oci_cloud_guard_detector_recipes.oracle_config_recipe.detector_recipe_collection[0].items[0].id` reference assumes the first result is the Oracle Configuration detector. In tenancies with multiple recipes, this index can shift. Add `display_name` filtering to the data source to make the selection explicit.

**Tag recipes and targets for cost attribution and auditability.** The `freeform_tags` block on detector and responder recipes supports filtering in the OCI console and CLI. Using `"managed-by" = "terraform"` makes it immediately clear which resources are IaC-managed and which were created manually — useful when auditing drift.

**Pair Cloud Guard with OCI Vulnerability Scanning.** Cloud Guard detects misconfigurations; [OCI Vulnerability Scanning Service](/oci-vulnerability-scanning-terraform/) detects CVEs in compute instances and container images. The two services complement each other — one covers posture, the other covers known exploitable weaknesses. Both can be provisioned together with Terraform.

**Monitor your Security Score trend, not point-in-time value.** A score of 78 is meaningless without context. A score that moves from 78 to 65 over two weeks tells you misconfigurations are accumulating faster than they are being remediated. Set up an OCI Monitoring alarm on the security score metric to alert when the score drops below a defined threshold.

**Include Cloud Guard in your IaC change management process.** Changes to detector recipes (enabling or disabling rules, changing risk levels) have direct impact on what your security team is alerted to. Treat them with the same pull request review process you use for infrastructure changes — a rule disabled accidentally in a recipe update creates a blind spot that may not be noticed for weeks.

## Conclusion

With the Terraform configuration in this post you have the full OCI security posture stack as code: Cloud Guard enabled at the tenancy root, custom detector and responder recipes with the rules that matter most overridden at `CRITICAL`, automated remediation for public bucket findings via both the built-in responder and an OCI Function, and IAM policies that give the service what it needs to operate. Threat Intelligence is wired in automatically via the Threat Detector recipe. The security score and problem list queries give you an operational view from the CLI.

The recipe/target model scales cleanly. Once this baseline is in place, extending it to new compartments is a matter of adding a target resource block. Customizing detection for a new workload type is adding a `detector_rules` override to the cloned recipe. The hard part — choosing the reporting region, getting the IAM policies right, understanding the `self_manage_resources` pitfall — is done.

Happy scripting!
