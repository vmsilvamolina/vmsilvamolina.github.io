---
title: 'Oracle Cloud Security Zones: Custom Recipes, Terraform, and Day-2 Operations'
author: Victor Silva
date: 2026-03-25T01:18:34+00:00
layout: post
permalink: /oci-security-zones-part2/
excerpt: "The Maximum Security Recipe is Oracle's nuclear option — it enables every available Security Zone policy simultaneously and cannot be modified. In practice, most production workloads cannot tolerate it without significant architectural changes, because it blocks things like internet gateways, NAT gateways, public load balancers, volume detachment, instance termination, and OKE cluster operations."
categories:
  - Oracle
  - Security
tags:
  - Oracle Cloud
  - Security Zones
  - Security
---

[Part 1 of this series](https://blog.victorsilva.com.uy/oci-security-zones/) covered the conceptual foundation of OCI Security Zones: what they are, how they enforce policy by denying API calls outright, the relationship with Cloud Guard and Security Advisor, and what the Maximum Security Recipe actually blocks. If you haven't read it, start there.

This post picks up where Part 1 left off. It answers the next set of questions practitioners ask after they understand the concept: *How do I build a custom recipe that fits my workload? How do I automate this with Terraform instead of clicking through the console? And what are the operational surprises waiting on day two?*

## Custom Recipes vs. Maximum Security: A Decision Framework

The Maximum Security Recipe is Oracle's nuclear option — it enables every available Security Zone policy simultaneously and cannot be modified. In practice, most production workloads cannot tolerate it without significant architectural changes, because it blocks things like internet gateways, NAT gateways, public load balancers, volume detachment, instance termination, and OKE cluster operations.

Custom recipes let you select which Oracle-authored policies to include. You cannot write your own policy logic — the library is curated by Oracle — but you can assemble a policy set appropriate to each environment.

The most useful mental model for custom recipe construction comes from OCI's own Landing Zone framework, which maps policies to **CIS Benchmark levels**:

| CIS Level | Policies Included | Best For |
|---|---|---|
| **Level 1** | Deny public buckets, public subnets, internet gateway; deny databases without backup; require customer-managed encryption keys | Most production workloads |
| **Level 2** | All Level 1 + data confinement policies, Oracle-approved configurations, port restriction | Regulated data: PHI, PCI, classified |

Start with CIS Level 1 for standard production compartments. Apply Level 2 selectively to compartments holding your most sensitive data. Avoid Maximum Security unless you are in a greenfield environment specifically designed around its constraints — or you are onboarding to OCI via a Landing Zone that has already pre-validated compatibility.

The categories you most frequently need to reason about when customizing:

**Deny Public Access** — the most operationally impactful category. Blocking `internet_gateway`, `NAT_gateway`, and `public_subnets` means your VCN topology must be private-only. For environments that legitimately need outbound internet access (to pull container images, reach OCI service endpoints, etc.), this either requires a shared services VCN with a NAT gateway outside the zone, or removing the NAT gateway policy from your custom recipe.

**Require Customer-Managed Encryption Keys** — the four vault key policies (`deny block_volume_without_vault_key`, `deny boot_volume_without_vault_key`, `deny file_system_without_vault_key`, `deny buckets_without_vault_key`) require OCI Vault to be set up and a Master Encryption Key provisioned *before* applying the zone. Vault is not part of Always Free — you need a standard or virtual private vault. The vault should be in the same zone or a parent compartment to avoid key access itself violating zone policies.

**Oracle-Approved Configurations** — this category includes policies that block compute instance termination (`deny terminate_instance`), volume detachment (`deny detach_volume`), and OKE operations (`deny manage_oke_service`). These are frequently too restrictive for teams that use autoscaling or perform routine maintenance. Exclude them from custom recipes unless you have a specific operational reason to include them.

## Building a Custom Recipe via CLI

The CLI workflow has three steps: list available policies and collect the OCIDs you want, create a recipe from those OCIDs, then create the zone with the recipe.

### Step 1: List and filter available policies

```bash
# List all available security policies in the tenancy
oci cloud-guard security-policy-collection list-security-policies \
  --compartment-id $COMPARTMENT_ID \
  --all

# Filter to find a specific policy's OCID
oci cloud-guard security-policy-collection list-security-policies \
  --compartment-id $COMPARTMENT_ID \
  --display-name "deny public_buckets" \
  --lifecycle-state ACTIVE
```

**Important:** Policy OCIDs are region-specific. You must look them up in the target tenancy and region — you cannot hardcode them from documentation or another environment.

### Step 2: Create the recipe

```bash
oci cloud-guard security-recipe create \
  --compartment-id $COMPARTMENT_ID \
  --display-name "prod-cis-level-1-recipe" \
  --security-policies '["ocid1.securityzonepolicy.oc1..aaa...xyz", "ocid1.securityzonepolicy.oc1..aaa...abc"]'
```

### Step 3: Create the zone

```bash
oci cloud-guard security-zone create \
  --compartment-id $COMPARTMENT_ID \
  --display-name "production-security-zone" \
  --security-zone-recipe-id $RECIPE_OCID
```

To update an existing zone to use a different recipe:

```bash
oci cloud-guard security-zone update \
  --security-zone-id $ZONE_OCID \
  --security-zone-recipe-id $NEW_RECIPE_OCID
```

## Terraform Automation

The CLI workflow above does not scale. For any environment managed as code, there are two Terraform paths: the Oracle Landing Zone module, or native provider resources.

### Path 1: Oracle Landing Zone Security Module

Oracle publishes and maintains a `terraform-oci-modules-security` module (github.com/oci-landing-zones/terraform-oci-modules-security) that abstracts away the policy OCID lookup problem. You specify a `cis_level` and it selects the appropriate policies automatically:

```hcl
module "security_zones" {
  source       = "github.com/oci-landing-zones/terraform-oci-modules-security//security-zones"
  tenancy_ocid = var.tenancy_ocid

  security_zones_configuration = {
    reporting_region = "us-ashburn-1"

    recipes = {
      CIS-L1-RECIPE = {
        name           = "prod-cis-level-1-recipe"
        description    = "CIS Level 1 recipe for production workloads"
        compartment_id = var.compartment_id
        cis_level      = "1"
      }
      CIS-L2-RECIPE = {
        name           = "sensitive-cis-level-2-recipe"
        description    = "CIS Level 2 recipe for sensitive data compartments"
        compartment_id = var.compartment_id
        cis_level      = "2"
      }
    }

    security_zones = {
      PROD-ZONE = {
        name           = "production-security-zone"
        compartment_id = var.prod_compartment_id
        recipe_key     = "CIS-L1-RECIPE"
      }
      SENSITIVE-ZONE = {
        name           = "sensitive-data-security-zone"
        compartment_id = var.sensitive_compartment_id
        recipe_key     = "CIS-L2-RECIPE"
      }
    }
  }
}
```

**Prerequisites before applying:**
- Terraform >= 1.3.0
- Cloud Guard must be enabled in the tenancy
- IAM policy: `allow group <SecurityAdmins> to manage cloud-guard-family in tenancy`

This module approach is the recommended path for teams using OCI Core or Zero Trust Landing Zones, because the module is tested against Oracle's own reference architectures.

### Path 2: Native Provider Resources

For teams that prefer direct resource control without the module abstraction:

```hcl
# Fetch policy OCIDs from the tenancy — required because they are region-specific
data "oci_cloud_guard_security_policies" "all_policies" {
  compartment_id = var.tenancy_ocid
}

# Locals to extract specific policy OCIDs by name
locals {
  policy_map = {
    for p in data.oci_cloud_guard_security_policies.all_policies.security_policy_collection[0].items :
    p.display_name => p.id
  }
}

resource "oci_cloud_guard_security_recipe" "custom_recipe" {
  compartment_id = var.compartment_id
  display_name   = "custom-security-recipe"
  description    = "Custom recipe for production workloads"
  security_policies = [
    local.policy_map["deny public_buckets"],
    local.policy_map["deny public_subnets"],
    local.policy_map["deny internet_gateway"],
    local.policy_map["deny block_volume_without_vault_key"],
    local.policy_map["deny boot_volume_without_vault_key"],
    local.policy_map["deny database_without_backup"],
  ]
}

resource "oci_cloud_guard_security_zone" "production_zone" {
  compartment_id          = var.compartment_id
  display_name            = "production-security-zone"
  description             = "Security zone for production workloads"
  security_zone_recipe_id = oci_cloud_guard_security_recipe.custom_recipe.id
}
```

Using the `data` source and `locals` to map policy names to OCIDs avoids hardcoded OCID strings that would break across regions and environments.

The OCI Console also provides a **"Save as Stack"** button during recipe and zone creation wizards. This exports a Terraform configuration to Oracle Resource Manager — useful for teams bootstrapping an IaC workflow from a console-based starting point.

## Operational Lifecycle: What Happens After Day One

### The Cloud Guard Target Side Effect

This is the most commonly missed operational detail: **when you create a security zone on a compartment, OCI deletes any existing Cloud Guard target for that compartment and replaces it with a security zone target**.

If you had a manually configured Cloud Guard target with custom detector recipes on that compartment, those configurations are gone. The replacement target gets the default Oracle-managed detector recipe.

Audit your Cloud Guard targets before applying security zones to existing compartments. If you have custom detector configuration you want to preserve, document it before creating the zone and reapply it to the new target afterward.

### Subcompartment Hierarchy

When a security zone is applied to a parent compartment, all subcompartments are automatically included. Subcompartments can have their own separate security zones (which creates a distinct Cloud Guard target for the subcompartment). A subcompartment can also be removed from the parent zone entirely via the Security Zones console:

```bash
oci cloud-guard security-zone remove \
  --security-zone-id $ZONE_OCID \
  --compartment-id $SUBCOMPARTMENT_OCID
```

The hard constraint remains: **each compartment can belong to exactly one security zone**. You cannot layer multiple recipes on a single compartment. If your workload needs different policy profiles within the same parent, the answer is separate child compartments with separate zones.

You also **cannot move a compartment** using the standard IAM console once it is part of a security zone. Use the Security Zones console for compartment operations.

### Existing Resources and Policy Violations

Applying a security zone to a compartment that already contains non-compliant resources does not delete or modify those resources. Cloud Guard detects and reports the violations, but remediation is the operator's responsibility.

The key constraint: you cannot move a non-compliant resource out of the compartment using movement-restriction policies — the movement itself would be denied by the zone. You must bring the resource into compliance in place (e.g., encrypting an unencrypted block volume with a Vault key) before the zone will treat it as fully compliant.

For the same reason, you cannot move a non-compliant resource *into* a security zone compartment. All policies must be satisfied before the move is permitted.

### Name Immutability

Once a security zone is created, **its name cannot be changed**. Only the description and recipe assignment can be updated. Establish a naming convention before deployment — `<env>-<purpose>-security-zone` works well — and document it. Renaming requires deleting and recreating the zone, which resets the Cloud Guard target again.

## Common Gotchas

**Root compartment warning.** Oracle's documentation explicitly cautions against assigning a security zone to the root (tenancy) compartment. Doing so applies zone policies to every resource across the entire tenancy, which blocks a wide range of routine administrative operations. Apply zones at the workload compartment level, not the root.

**Database compatibility.** Not all database configurations are compatible with Security Zones. Incompatible with Maximum Security Recipe: Always Free Autonomous Databases and Autonomous Database with public endpoints. Compatible (paid, private endpoint configurations): Autonomous AI Database, Bare Metal DB systems, Virtual Machine DB systems, and Exadata Cloud DB systems. Data Guard associations must be within the same security zone compartments — cross-zone Data Guard is blocked.

**Vault must exist before encryption policies apply.** The four `deny *_without_vault_key` policies will cause resource creation to fail unless you have an OCI Vault with a Master Encryption Key already provisioned and accessible. If you include encryption policies in your recipe, provision the vault as part of the same Terraform apply (with correct ordering) or as a prerequisite stack. The vault should be in the same or a parent compartment to avoid key access itself triggering zone violations.

**Policy OCIDs are region-specific.** Do not copy OCID values from one region's recipe to another. Always look up policy OCIDs in the target region, either via CLI or the `data` source in Terraform. The module approach avoids this problem entirely by resolving OCIDs internally.

## What to Cover in Part 3

The natural next topic in this series is Cloud Guard in depth: how detector recipes work, when to use the Oracle-managed recipe vs. a custom one, how auto-remediation is configured, and how to interpret Cloud Guard's risk score output in the context of Security Zone policy violations. Zero Trust Packet Routing (ZPR) — Oracle's newer, attribute-based network control layer — is also worth its own post as a complement to Security Zones for teams building on OCI's security architecture.

*References: [Security Zone Policies — Oracle Docs](https://docs.oracle.com/iaas/security-zone/using/security-zone-policies.htm) · [terraform-oci-modules-security](https://github.com/oci-landing-zones/terraform-oci-modules-security) · [Safeguard Your Tenancy With Custom Security Zones — Oracle A-Team](https://www.ateam-oracle.com/safeguard-your-tenancy-with-custom-security-zones) · [oci_cloud_guard_security_zone — Terraform Registry](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/cloud_guard_security_zone)*

Happy scripting!