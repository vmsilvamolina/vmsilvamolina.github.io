---
title: "OCI Identity and Access Management: users, groups and policies"
author: Victor Silva
date: 2022-11-08T15:44:32+00:00
layout: post
permalink: /oci-iam-users-groups-policies/
excerpt: "An introduction to Oracle Cloud Infrastructure IAM: how compartments, users, groups, and policies work together — with practical examples using the OCI CLI and Terraform."
categories:
  - OCI
  - Security
tags:
  - OCI
  - Oracle Cloud
  - IAM
  - Security
  - Terraform
  - OCI CLI
---

When you spend enough time working with Azure RBAC or AWS IAM, you build a mental model that feels pretty universal: principals (users, service accounts, roles) get permissions, those permissions apply to resources, and the scope of that relationship is controlled through some kind of hierarchical namespace — subscriptions and resource groups in Azure, accounts and regions in AWS. Moving to Oracle Cloud Infrastructure (OCI) for the first time, I expected to find something roughly equivalent. What I found instead was a model that looks similar on the surface but has a genuinely different organizing principle, and understanding that difference early saves a lot of confusion later.

The centerpiece of OCI IAM is the **compartment**. There is no direct equivalent in Azure or AWS. In Azure, resource groups are organizational containers but they are not the primary authorization boundary — RBAC roles can be assigned at the subscription, resource group, or individual resource level, and they cascade downward. In AWS, the account is the primary isolation boundary, with resource-based policies and IAM conditions filling in the gaps. In OCI, the compartment is both the organizational container and the authorization scope, and everything — every compute instance, every VCN, every bucket — lives in a compartment. The root of the tree is your tenancy, which is itself a special compartment called the root compartment.

The second thing that stands out when coming from AWS IAM in particular is the policy syntax. AWS policy documents are JSON with ARN wildcards, condition blocks, and a fairly steep learning curve for writing correct statements. OCI policies are written as human-readable English sentences: `Allow group Developers to manage instance-family in compartment dev-workloads`. Once you internalize the four-word structure and the verb hierarchy, you can write and read policies without referencing documentation. That is a real advantage for teams where policy authorship should not be limited to a single security specialist.

This post walks through the core OCI IAM model from scratch — compartments, users, groups, and policies — using the OCI CLI for hands-on examples and Terraform for the IaC-first approach. If you are coming from Azure or AWS and starting to work with OCI, this is the mental model you need to internalize before anything else.

## The OCI IAM Model

Before touching the CLI, it is worth mapping out the four core concepts and how they relate to each other.

**Tenancy** is your OCI account. When you sign up for OCI, a tenancy is created for you, and it has a root compartment with the same OCID as the tenancy itself. Every resource you ever create in OCI ultimately belongs to the tenancy. The tenancy is also where tenancy-wide policies live — policies that apply to all compartments everywhere.

**Compartments** are hierarchical organizational units for resources. A compartment can contain resources (compute instances, databases, networks) and other compartments. This nesting can go quite deep — OCI supports up to six levels of nesting. The key property of compartments that makes them unique is that they are the scope for policy enforcement. When you write a policy that says "in compartment X", that policy applies to resources in X and, by default, to resources in all compartments nested under X. This creates a clean top-down model: the platform team sets guardrails at the tenancy level, and individual teams operate with delegated autonomy inside their compartments.

**Groups** are collections of users. This is the one thing that maps cleanly to both Azure and AWS — you have users, you put them in groups, you attach permissions to groups. The important detail in OCI is that policies are **always** attached to groups, never directly to individual users. There is no OCI equivalent of attaching a policy directly to a user. If you need a single user to have permissions, you put that user in a group (even a group with a single member) and write a policy for the group.

**Policies** are the permission statements that grant groups access to resource types in compartment scopes. The syntax is fixed and structured:

```
Allow group <GroupName> to <verb> <resource-type> in <location>
```

The `<verb>` controls the permission level and follows a strict four-tier hierarchy from least to most permissive:

| Verb | What it includes |
|---|---|
| `inspect` | List resources; no access to configuration details |
| `read` | inspect + get full resource details |
| `use` | read + create and update resources (no delete, no IAM changes) |
| `manage` | Full control, including delete and IAM-related operations |

The `<location>` is either `tenancy` (applies everywhere) or `compartment <name>` (applies to that compartment and its children). You can also use `compartment id <ocid>` if you need to reference by OCID rather than name.

## Prerequisites

To follow along you will need:

- An OCI account with Administrator access (or at minimum Identity Domain Administrator in the root compartment)
- OCI CLI 3.x installed and configured (`oci setup config`)
- Terraform 1.x if you want to follow the IaC section
- The tenancy OCID — export it as `OCI_TENANCY` for convenience

Verify your CLI is configured correctly:

{% highlight bash %}
# Verify CLI config and authentication
oci iam tenancy get --tenancy-id $OCI_TENANCY

# Should return JSON with your tenancy name, home region, etc.
{% endhighlight %}

## Creating a Compartment

The first thing to do in any new OCI tenancy is set up the compartment structure that reflects your workload organization. For this post, we will create a single `dev-workloads` compartment to scope all development resources.

{% highlight bash %}
# Create a compartment in the root (tenancy)
oci iam compartment create \
    --compartment-id $OCI_TENANCY \
    --name "dev-workloads" \
    --description "Development environment compartment" \
    --wait-for-state ACTIVE

# The command returns the full compartment object including the OCID
# Save it for later use
export DEV_COMPARTMENT_OCID=$(oci iam compartment list \
    --compartment-id $OCI_TENANCY \
    --name "dev-workloads" \
    --query 'data[0].id' \
    --raw-output)

# List all compartments in the tenancy
oci iam compartment list \
    --compartment-id $OCI_TENANCY \
    --all \
    --query 'data[*].{Name:name, OCID:id, State:"lifecycle-state"}' \
    --output table
{% endhighlight %}

The `--wait-for-state ACTIVE` flag is worth using for compartment creation — the compartment needs to be fully active before you can create policies against it, and the CLI will poll until that state is reached. Without it, you might get a race condition if you immediately try to attach a policy.

One thing to know early: deleting compartments in OCI is not instant. A compartment can only be deleted when it is empty (no resources, no subcompartments), and even then the deletion is asynchronous and can take several minutes to propagate. Plan your compartment hierarchy with some care rather than treating them as disposable.

## Creating Users and Groups

With the compartment in place, we can create the identity objects. The pattern is: create the user, create the group, then add the user to the group.

{% highlight bash %}
# Create a user
oci iam user create \
    --name "john.doe@company.com" \
    --description "Developer - John Doe" \
    --email "john.doe@company.com"

# Save the user OCID
export USER_OCID=$(oci iam user list \
    --name "john.doe@company.com" \
    --query 'data[0].id' \
    --raw-output)

# Create a group for developers
oci iam group create \
    --name "dev-developers" \
    --description "Development team members"

# Save the group OCID
export GROUP_OCID=$(oci iam group list \
    --name "dev-developers" \
    --query 'data[0].id' \
    --raw-output)

# Add the user to the group
oci iam group add-user \
    --group-id $GROUP_OCID \
    --user-id $USER_OCID

# Verify membership
oci iam group list-users \
    --group-id $GROUP_OCID \
    --all \
    --query 'data[*].{Name:name, Email:email, State:"lifecycle-state"}' \
    --output table
{% endhighlight %}

One thing that surprises people coming from AWS: OCI IAM users are native OCI users with a console password and API keys. They are different from federated users (who authenticate through an identity provider like Active Directory). For production environments you will almost always want to federate with an external IdP rather than managing native OCI users directly, but understanding the native model first makes the federated setup much easier to reason about.

## Writing OCI Policies

This is where OCI IAM becomes genuinely distinctive. Let's create a policy that gives the `dev-developers` group practical working permissions in the `dev-workloads` compartment: the ability to manage compute instances, use networking resources, and manage object storage.

{% highlight bash %}
# Create a policy with multiple statements
oci iam policy create \
    --compartment-id $OCI_TENANCY \
    --name "dev-compute-policy" \
    --description "Dev team compute and storage access in dev-workloads compartment" \
    --statements '[
      "Allow group dev-developers to manage instance-family in compartment dev-workloads",
      "Allow group dev-developers to use virtual-network-family in compartment dev-workloads",
      "Allow group dev-developers to manage object-family in compartment dev-workloads"
    ]'
{% endhighlight %}

Notice that this policy is created at the tenancy level (`--compartment-id $OCI_TENANCY`), not in the `dev-workloads` compartment. Policies that reference a specific compartment can be placed either at the tenancy level or in the compartment itself — but policies granting access to resources in child compartments must be placed in an ancestor compartment or the tenancy. If you put the policy inside `dev-workloads` itself, it would also work, but it could not reference resources in sibling or parent compartments.

### Common Policy Patterns

The resource-type families (`instance-family`, `virtual-network-family`, `object-family`) are aggregate types that cover multiple related resource types. This is more convenient than listing each resource type individually. Here are the patterns I find myself reaching for repeatedly:

{% highlight bash %}
# Read-only access to all resources (useful for auditors, monitoring)
# "Allow group auditors to inspect all-resources in compartment dev-workloads"

# Network administrators managing VCNs, subnets, security lists
# "Allow group network-admins to manage virtual-network-family in tenancy"

# Application team with object storage access scoped to one compartment
# "Allow group app-team to use object-family in compartment app-prod"

# Security team managing IAM at the tenancy level
# Note: IAM policies are always written at the tenancy level
# "Allow group security-admins to manage users in tenancy"
# "Allow group security-admins to manage groups in tenancy"
# "Allow group security-admins to manage policies in tenancy"

# Allow a team to manage their own compartment entirely
# "Allow group dev-leads to manage all-resources in compartment dev-workloads"
{% endhighlight %}

The `use` vs `manage` distinction is important for network resources specifically. Developers who need to launch instances need `use` on `virtual-network-family` (to attach to existing VCNs and subnets), but should not have `manage` unless they also need to create or modify VCNs — that is usually a network admin concern. This separation maps cleanly to the principle of least privilege.

## Listing and Auditing Policies

Once you have policies in place, being able to audit them quickly is essential. OCI CLI makes this straightforward.

{% highlight bash %}
# List all policies in the tenancy (including what's in child compartments)
oci iam policy list \
    --compartment-id $OCI_TENANCY \
    --all \
    --query 'data[*].{Name:name, Statements:statements}' \
    --output json

# List policies in a specific compartment only
oci iam policy list \
    --compartment-id $DEV_COMPARTMENT_OCID \
    --all \
    --output table

# Get details of a specific policy by OCID
oci iam policy get --policy-id $POLICY_OCID

# Check all groups a user belongs to
oci iam user list-groups \
    --user-id $USER_OCID \
    --all \
    --query 'data[*].{GroupName:name, Description:description}' \
    --output table
{% endhighlight %}

There is no native "effective permissions" view in OCI the way Azure has the "check access" feature on a resource. To audit what a user can do, you trace the chain: user → groups → policies matching those groups → resource types and compartments in those policies. For complex tenancies this is worth automating with a script that does exactly that traversal.

## Terraform: The Same Setup as IaC

Let's implement the same compartment, group, and policy structure with Terraform using the OCI provider. This is the approach I recommend for anything beyond initial exploration — the OCI provider is mature and the resource model maps closely to the CLI.

{% highlight hcl %}
terraform {
  required_providers {
    oci = {
      source  = "hashicorp/oci"
      version = "~> 4.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

# Create the development compartment
resource "oci_identity_compartment" "dev_workloads" {
  compartment_id = var.tenancy_ocid
  name           = "dev-workloads"
  description    = "Development environment compartment"
  enable_delete  = true
}

# Create the developers group
resource "oci_identity_group" "dev_developers" {
  compartment_id = var.tenancy_ocid
  name           = "dev-developers"
  description    = "Development team members"
}

# Create a user (in practice, prefer federation over native users)
resource "oci_identity_user" "john_doe" {
  compartment_id = var.tenancy_ocid
  name           = "john.doe@company.com"
  description    = "Developer - John Doe"
  email          = "john.doe@company.com"
}

# Add user to group
resource "oci_identity_user_group_membership" "john_doe_dev" {
  group_id = oci_identity_group.dev_developers.id
  user_id  = oci_identity_user.john_doe.id
}

# Create the policy granting compute and storage access
resource "oci_identity_policy" "dev_compute_policy" {
  compartment_id = var.tenancy_ocid
  name           = "dev-compute-policy"
  description    = "Dev team compute and storage access in dev-workloads compartment"

  statements = [
    "Allow group dev-developers to manage instance-family in compartment dev-workloads",
    "Allow group dev-developers to use virtual-network-family in compartment dev-workloads",
    "Allow group dev-developers to manage object-family in compartment dev-workloads",
  ]
}

# Outputs for reference
output "compartment_ocid" {
  value = oci_identity_compartment.dev_workloads.id
}

output "group_ocid" {
  value = oci_identity_group.dev_developers.id
}
{% endhighlight %}

A few notes on the Terraform setup. The `enable_delete = true` on the compartment resource is required if you want `terraform destroy` to actually delete the compartment — by default OCI soft-deletes compartments when you remove them through the API, and the Terraform resource will fail to destroy without this flag. The OCI provider also has the quirk that policy statement order is not significant, but changes to the statements list will cause an in-place update (not a destroy/recreate), so adding new policy statements does not cause downtime.

## Compartment Hierarchy and Policy Inheritance

One of the most powerful aspects of the compartment model is policy inheritance. A policy written in a parent compartment that references child compartments applies to those children. More broadly, a policy that says `in tenancy` applies everywhere. This allows a clean separation of concerns:

- **Tenancy level**: Platform and security team policies. Network guardrails, identity management, logging requirements.
- **Parent compartment level**: Business unit or environment-wide policies. A "dev-environment" compartment might have policies that apply to all child development compartments.
- **Leaf compartment level**: Team-specific policies. A single team's workload permissions scoped to their compartment.

This top-down inheritance means that a security team can set organization-wide guardrails that no team can override from within their own compartment. A team can manage `all-resources in compartment their-compartment`, but they cannot grant themselves permissions beyond what the ancestor policy hierarchy allows. This is the guardrail model that is harder to achieve cleanly in AWS without Service Control Policies, and more structured than Azure's Management Group policy inheritance for RBAC.

## Wrapping Up

OCI IAM's compartment-centric model and natural-language policy syntax have a different feel from both Azure RBAC and AWS IAM, but they are not harder — just different. The mental shift is to think of compartments as your primary tool for both organizing resources and defining authorization scope, and to think of policies as readable English statements rather than JSON documents with ARN wildcards.

The verb hierarchy (`inspect`, `read`, `use`, `manage`) gives you a clean way to express least privilege without building complex condition blocks. The fact that policies are always written for groups, never for individual users, enforces a discipline that makes access reviews much easier to conduct systematically.

Once you have this model internalized, the rest of OCI IAM — dynamic groups (which let you write policies for resource principals rather than users), instance principals (compute instances that can call OCI APIs using their own identity), and service policies — all make sense as natural extensions of the same pattern. But compartments, groups, and policies are the foundation, and getting comfortable with them through the CLI and Terraform is where to start.

Happy scripting!
