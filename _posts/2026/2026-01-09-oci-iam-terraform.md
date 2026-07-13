---
title: 'OCI IAM Terraform: Compartments, Dynamic Groups, Policies'
author: Victor Silva
date: 2026-01-09T23:23:47+00:00
layout: post
permalink: /oci-iam-terraform/
excerpt: "OCI IAM denies everything by default. Build compartments, OCI dynamic groups, instance principals, and oracle cloud IAM policy with Terraform."
categories:
  - OCI
  - Terraform
tags:
  - oci iam terraform
  - oci dynamic groups
  - oci compartments
  - oci instance principals
  - oracle cloud iam policy
  - terraform oci provider
  - oci identity policy
---

You spin up a fresh OCI tenancy, launch a compute instance, write a small script that calls the OCI API — maybe to pull a secret from [OCI Vault](/oci-vault-secrets-management-terraform/) or list objects in Object Storage — and you get back a 401. You check the instance. The OCI CLI is installed and the region is right. You try running the same call with your personal API key and it works fine. The instance just returns `Authorization failed or requested resource not found`.

Welcome to OCI IAM. Unlike AWS, where the default for many resource interactions is implicit access within an account, OCI's IAM model is deny-by-default with no exceptions. No action is permitted unless a policy statement explicitly grants it. There is no instance role to attach, no managed policy to inherit — you need to understand how the model fits together before anything works.

This post walks through the full picture: the five objects in OCI IAM, how compartments act as security boundaries, how policies are scoped, how to give compute instances an identity they can use to call OCI APIs without embedding credentials, and how to build all of it with Terraform. We will cover the gotchas that trip up almost every new OCI deployment, including a policy scoping bug that silently does nothing and an eventual-consistency issue that makes Terraform apply succeed while the permission is not yet effective.

## Understanding OCI IAM

### Deny by default — and what that means in practice

In OCI, the absence of a policy statement is not neutral — it is a hard deny. A new user added to no groups cannot perform any action, not even read their own profile. A compute instance with no dynamic group has no identity from IAM's perspective and cannot call any OCI API. A compartment with no policies attached is inert from an access standpoint regardless of what resources live in it.

This is different from AWS, where EC2 instances have an implicit identity that IAM roles can be attached to, and where certain read operations are allowed to authenticated principals even without explicit policies. In OCI, you build the permission model from zero. That is harder to get started with and significantly better for security once you understand it.

### The five objects

OCI IAM has five core objects that you need to understand before writing any policy:

**Users** are human identities. They authenticate with API keys or the console, and they derive permissions from the groups they belong to. Users themselves carry no permissions — only group membership matters.

**Groups** are collections of users. Policies grant permissions to groups, not to individual users. Groups always exist at the tenancy root level; you cannot scope a group to a compartment.

**Dynamic Groups** are the machine-identity equivalent of groups. Instead of containing users, they contain resources — compute instances, functions, DevOps pipelines, data science jobs — that match a set of rules evaluated at call time. A compute instance in a dynamic group can call OCI APIs using Instance Principal authentication. More on this later.

**Compartments** are logical containers for OCI resources. They are the unit of scope for policies, billing, and access control. Unlike AWS accounts or GCP projects, compartments are not separate billing boundaries or separate API surfaces — they live within a single tenancy. A resource lives in exactly one compartment and cannot be moved between compartments after creation (with a few service-specific exceptions).

**Policies** are the access control statements that connect subjects (groups or dynamic groups) to verbs (what they can do) and resources (what they can do it on) within a location (which compartment or the entire tenancy).

### Policy statement anatomy

Every OCI policy statement follows the same structure:

```
Allow <subject> to <verb> <resource-type> in <location>
```

Where:

- `<subject>` is `group GroupName` or `dynamic-group DynamicGroupName`
- `<verb>` is one of four ordered verbs (described below)
- `<resource-type>` is a specific resource family like `secret-family`, `instances`, `object-family`, or the catch-all `all-resources`
- `<location>` is `tenancy` or `compartment <name>` or `compartment id <ocid>`

A concrete example:

```
Allow group SecurityAdmins to manage secret-family in compartment id ocid1.compartment.oc1..aaaaaa...
```

### The four verbs

OCI uses four verbs in ascending order of privilege. Each verb includes all permissions of the verb below it:

| Verb | What it allows | Example use |
|---|---|---|
| `inspect` | List and discover resources — no data access | Cloud Guard, audit tooling |
| `read` | Inspect plus read resource contents and configuration | Applications reading secrets, config data |
| `use` | Read plus modify state of existing resources (no create/delete) | Rotation jobs, update operations |
| `manage` | Full control — create, update, delete | Administrators, Terraform service accounts |

The golden rule: grant the minimum verb that covers the actual operation. An application that reads a secret needs `read secret-bundles`. It does not need `use` or `manage`, and granting those expands the blast radius of a compromised workload significantly.

## Compartments as security boundaries

### Logical boundaries, not account isolation

Compartments are often misunderstood by engineers coming from AWS or GCP. In AWS, the closest equivalent to strong isolation is a separate account — a separate IAM namespace, a separate billing scope, a separate API surface. In GCP, it is a separate project. In OCI, compartments are **logical boundaries within a single tenancy**. They share the IAM namespace, the same tenancy OCID, and the same API endpoints.

What compartments give you is a scoping mechanism for policies and a way to organize resources for billing and governance. A policy attached to a compartment governs access to resources in that compartment and all compartments nested beneath it. That hierarchical flow is how you build a layered security model.

The key constraint: OCI supports a compartment hierarchy up to six levels deep — the root compartment plus five levels of nesting. Anything beyond that requires rethinking the design.

### A three-level hierarchy in Terraform

For most production workloads, a three-level hierarchy gives you enough granularity without unnecessary complexity. The pattern: a top-level "Workloads" compartment, a Production and NonProd tier beneath it, and function-specific compartments (Network, Security, Compute) under each environment tier.

```
Root (tenancy)
└── Workloads
    ├── Production
    │   ├── Network
    │   ├── Security
    │   └── Compute
    └── NonProd
        ├── Network
        ├── Security
        └── Compute
```

Here is the Terraform to build this hierarchy:

{% highlight hcl %}
variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

# Level 1 — Workloads
resource "oci_identity_compartment" "workloads" {
  compartment_id = var.tenancy_ocid
  name           = "Workloads"
  description    = "Top-level compartment for all workload resources"
  enable_delete  = true

  freeform_tags = {
    "ManagedBy"   = "terraform"
    "Tier"        = "workloads"
  }
}

# Level 2 — Production and NonProd
resource "oci_identity_compartment" "production" {
  compartment_id = oci_identity_compartment.workloads.id
  name           = "Production"
  description    = "Production workloads"
  enable_delete  = true

  freeform_tags = {
    "ManagedBy"   = "terraform"
    "Environment" = "production"
  }
}

resource "oci_identity_compartment" "nonprod" {
  compartment_id = oci_identity_compartment.workloads.id
  name           = "NonProd"
  description    = "Non-production workloads (dev, staging, test)"
  enable_delete  = true

  freeform_tags = {
    "ManagedBy"   = "terraform"
    "Environment" = "nonprod"
  }
}

# Level 3 — Production sub-compartments
resource "oci_identity_compartment" "prod_network" {
  compartment_id = oci_identity_compartment.production.id
  name           = "Network"
  description    = "VCNs, subnets, gateways, security lists"
  enable_delete  = true
}

resource "oci_identity_compartment" "prod_security" {
  compartment_id = oci_identity_compartment.production.id
  name           = "Security"
  description    = "Vaults, keys, secrets, Cloud Guard, Security Zones"
  enable_delete  = true
}

resource "oci_identity_compartment" "prod_compute" {
  compartment_id = oci_identity_compartment.production.id
  name           = "Compute"
  description    = "Compute instances, instance pools, autoscaling configs"
  enable_delete  = true
}

# Level 3 — NonProd sub-compartments
resource "oci_identity_compartment" "nonprod_network" {
  compartment_id = oci_identity_compartment.nonprod.id
  name           = "Network"
  description    = "VCNs, subnets, gateways (non-prod)"
  enable_delete  = true
}

resource "oci_identity_compartment" "nonprod_security" {
  compartment_id = oci_identity_compartment.nonprod.id
  name           = "Security"
  description    = "Vaults, keys, secrets (non-prod)"
  enable_delete  = true
}

resource "oci_identity_compartment" "nonprod_compute" {
  compartment_id = oci_identity_compartment.nonprod.id
  name           = "Compute"
  description    = "Compute instances (non-prod)"
  enable_delete  = true
}
{% endhighlight %}

The `prod_security` compartment is also where you would enforce [OCI Security Zones](/oci-security-zones/) to prevent misconfiguration of Vault and networking resources at the control-plane level.

Notice `enable_delete = true` on every compartment. This is a Terraform-specific setting that deserves its own paragraph. By default, the OCI Terraform provider will **not** delete compartments when you run `terraform destroy`, even if the compartment is empty. It will silently succeed — Terraform reports the resource as destroyed, but the compartment still exists in OCI. If you then run `terraform apply` again, Terraform tries to create the compartment, OCI returns a conflict because a compartment with that name already exists, and the apply fails. Setting `enable_delete = true` tells the provider to actually issue the delete API call. For non-production infrastructure this is almost always what you want.

## Groups and Policies

### Where groups and policies live

Groups always live at the tenancy root. There is no concept of a compartment-scoped group in OCI. When you create a group, its `compartment_id` must be the tenancy OCID.

Policies are different. A policy lives in the compartment it is attached to, and it governs access to resources in that compartment and all compartments beneath it. You can place a policy in the root compartment if it needs to grant cross-compartment access (for example, SecurityAdmins reading from all compartments). You can place it in a child compartment if the scope is intentionally local.

### The critical gotcha: name resolution vs OCID

This is the most common silent misconfiguration in OCI IAM, and it will burn you if you are not aware of it.

A policy statement can reference a compartment by name or by OCID:

```
# By name — resolves relative to where the policy is defined
Allow group Developers to use instances in compartment NonProd

# By OCID — absolute, unambiguous
Allow group Developers to use instances in compartment id ocid1.compartment.oc1..aaaaaa...
```

When you use a compartment name in a policy statement, OCI resolves it **relative to the compartment where the policy is defined**. If the policy lives in the root compartment, `compartment NonProd` looks for a direct child of root named `NonProd`. If the policy lives in the `Workloads` compartment, `compartment NonProd` looks for a direct child of `Workloads` named `NonProd`.

This is where it goes wrong: if the compartment name exists at a different level of the hierarchy than where the policy is defined, the policy statement silently evaluates as if the compartment does not exist. No error is returned. The policy is accepted by the API and shows up in the console, but it grants nothing.

In Terraform, always use `compartment id <ocid>` — never use compartment names in policy statements. This removes the ambiguity entirely and makes policies portable regardless of where they are defined.

{% highlight hcl %}
# Wrong — resolves by name relative to policy location (silent misscoping risk)
# "Allow group SecurityAdmins to manage vaults in compartment Security"

# Correct — unambiguous OCID reference
resource "oci_identity_group" "security_admins" {
  compartment_id = var.tenancy_ocid   # Groups always live at tenancy root
  name           = "SecurityAdmins"
  description    = "Security operations team — vault, keys, secrets, Cloud Guard"
}

resource "oci_identity_group" "developers" {
  compartment_id = var.tenancy_ocid
  name           = "Developers"
  description    = "Application development team — non-prod workloads"
}

# Tenancy-level policy: SecurityAdmins read access across all compartments
# (audit, governance, cross-compartment visibility)
resource "oci_identity_policy" "security_admins_tenancy" {
  compartment_id = var.tenancy_ocid
  name           = "security-admins-tenancy-policy"
  description    = "SecurityAdmins — read access across tenancy and manage vault in prod Security"

  statements = [
    "Allow group SecurityAdmins to read all-resources in tenancy",
    "Allow group SecurityAdmins to manage vaults in compartment id ${oci_identity_compartment.prod_security.id}",
    "Allow group SecurityAdmins to manage keys in compartment id ${oci_identity_compartment.prod_security.id}",
    "Allow group SecurityAdmins to manage secret-family in compartment id ${oci_identity_compartment.prod_security.id}",
  ]

  depends_on = [
    oci_identity_group.security_admins,
    oci_identity_compartment.prod_security,
  ]
}

# Compartment-level policy: Developers in NonProd Compute
resource "oci_identity_policy" "developers_nonprod" {
  compartment_id = oci_identity_compartment.nonprod.id
  name           = "developers-nonprod-policy"
  description    = "Developers — use compute and networking in NonProd"

  statements = [
    "Allow group Developers to use instances in compartment id ${oci_identity_compartment.nonprod_compute.id}",
    "Allow group Developers to use vnics in compartment id ${oci_identity_compartment.nonprod_network.id}",
    "Allow group Developers to read virtual-network-family in compartment id ${oci_identity_compartment.nonprod_network.id}",
    "Allow group Developers to manage objects in compartment id ${oci_identity_compartment.nonprod_compute.id}",
  ]

  depends_on = [
    oci_identity_group.developers,
    oci_identity_compartment.nonprod_compute,
    oci_identity_compartment.nonprod_network,
  ]
}
{% endhighlight %}

The `depends_on` blocks are not just style — they are operationally necessary. OCI IAM has eventual-consistency propagation that can take up to 60 seconds after a group or compartment is created before they are fully resolvable in a policy statement. Terraform does not wait for this propagation automatically. If the policy resource is created before the group or compartment it references is fully propagated, the policy may be created with a broken reference that silently grants nothing. The `depends_on` makes Terraform serialize the creation correctly and reduces (though does not fully eliminate) the propagation window issue.

## Dynamic Groups and Instance Principals

### The machine-identity problem

Compute instances, OCI Functions, DevOps pipelines, and data science jobs all need to call OCI APIs at runtime. The naive solution is to generate an API key for a service user, put it on the instance, and configure the OCI CLI or SDK to use it. This works but creates a credential management problem: you need to rotate the key, the key is stored on disk (and possibly in Terraform state, AMI snapshots, or container images), and a compromised instance leaks a long-lived credential.

OCI's answer is Instance Principals. An instance belonging to a Dynamic Group can authenticate with OCI IAM using a short-lived session token derived from a certificate that the Instance Metadata Service (IMDS) provides. No static key is stored anywhere.

### How Instance Principals work

When an instance calls the OCI API using Instance Principal authentication, the SDK performs this sequence:

1. The SDK calls the IMDS at `169.254.169.254` to retrieve a leaf certificate that uniquely identifies the instance.
2. The leaf cert is exchanged with the OCI IAM service for a short-lived session token.
3. The session token is used to sign API requests.
4. IAM evaluates the request against the dynamic group matching rules to determine if the instance is a member of any dynamic group, then evaluates the applicable policy statements.

The session token is refreshed automatically by the SDK before expiry. From the application's perspective, it is just a signer — the credential lifecycle is managed by the SDK and IAM, not by the application.

The comparison to other cloud providers makes the model clearer:

| | OCI | AWS | GCP |
|---|---|---|---|
| Identity mechanism | Dynamic Group + Instance Principal | IAM Role + Instance Profile | Service Account + Workload Identity |
| Auth flow | IMDS cert → IAM session token | IMDS temporary credentials (STS) | IMDS token → GCP IAM |
| Assignment timing | Matching rule evaluated at call time | Role attached at launch (or via IMDSv2) | SA attached at instance creation |
| Credential rotation | Automatic (SDK-managed) | Automatic (STS) | Automatic |

The critical OCI-specific behavior in that table is "matching rule evaluated at call time." Dynamic groups do not attach to an instance at launch — the IAM service evaluates the matching rule every time the instance makes an API call. This means:

- If you move an instance to a different compartment, its dynamic group membership changes immediately.
- If you update the matching rule on a dynamic group, all existing instances are affected immediately.
- There is no "stale attachment" problem — but there is also no grace period.

### ANY vs ALL in matching rules

Dynamic group matching rules use `ANY` and `ALL` as logical operators:

- `ANY` is an OR — the instance is a member if it satisfies **at least one** of the conditions
- `ALL` is an AND — the instance is a member only if it satisfies **every** condition

This is easy to mix up because `ALL` looks like "all of the following are true" and `ANY` looks like "any of the following is true" — which is exactly correct, but the placement in a rule means the rule logic is different.

A rule with `ANY` matches broadly. A rule with `ALL` is a tighter filter. Use `ALL` when you need to combine compartment membership with a tag value, for example to distinguish application servers from bastion hosts within the same compartment.

### Terraform implementation

Let's implement four dynamic groups covering the most common patterns:

{% highlight hcl %}
# Dynamic group 1: all instances in prod/compute by compartment OCID
resource "oci_identity_dynamic_group" "prod_compute_instances" {
  compartment_id = var.tenancy_ocid   # Dynamic groups always live at tenancy root
  name           = "prod-compute-instances"
  description    = "All compute instances in the Production/Compute compartment"

  # ANY with a single condition — equivalent to an exact compartment match
  matching_rule = "ANY {instance.compartment.id = '${oci_identity_compartment.prod_compute.id}'}"
}

# Dynamic group 2: tag-based AND rule — instances in prod/compute tagged as app-servers
resource "oci_identity_dynamic_group" "prod_app_servers" {
  compartment_id = var.tenancy_ocid
  name           = "prod-app-servers"
  description    = "Instances in prod/compute tagged as app-servers (Operations.Role = app-server)"

  # ALL = AND — both conditions must be true
  matching_rule = "ALL {instance.compartment.id = '${oci_identity_compartment.prod_compute.id}', tag.Operations.Role.value = 'app-server'}"
}

# Dynamic group 3: OCI Functions in prod/compute compartment
resource "oci_identity_dynamic_group" "prod_functions" {
  compartment_id = var.tenancy_ocid
  name           = "prod-functions"
  description    = "OCI Functions deployed in Production/Compute"

  matching_rule = "ALL {resource.type = 'fnfunc', resource.compartment.id = '${oci_identity_compartment.prod_compute.id}'}"
}

# Dynamic group 4: DevOps pipeline in any production compartment
resource "oci_identity_dynamic_group" "prod_devops_pipelines" {
  compartment_id = var.tenancy_ocid
  name           = "prod-devops-pipelines"
  description    = "OCI DevOps build and deployment pipelines targeting production"

  # ANY — pipeline may be in any of the three prod sub-compartments
  matching_rule  = "ANY {resource.type = 'devopsdeploypipeline', resource.compartment.id = '${oci_identity_compartment.prod_compute.id}', resource.type = 'devopsdeploypipeline', resource.compartment.id = '${oci_identity_compartment.prod_security.id}'}"
}
{% endhighlight %}

Now the policies that actually grant permissions to these dynamic groups. The most common real-world pattern is allowing compute instances to retrieve secrets from the Security compartment:

{% highlight hcl %}
# Allow prod compute instances to read secrets from the prod Security compartment
resource "oci_identity_policy" "compute_read_secrets" {
  compartment_id = oci_identity_compartment.prod_security.id
  name           = "prod-compute-read-secrets"
  description    = "Allow prod compute instances to retrieve secret bundles from vault"

  statements = [
    "Allow dynamic-group prod-compute-instances to read secret-bundles in compartment id ${oci_identity_compartment.prod_security.id}",
    "Allow dynamic-group prod-compute-instances to read secrets in compartment id ${oci_identity_compartment.prod_security.id}",
  ]

  depends_on = [
    oci_identity_dynamic_group.prod_compute_instances,
    oci_identity_compartment.prod_security,
  ]
}

# Allow prod functions to read objects in a specific Object Storage bucket
resource "oci_identity_policy" "functions_read_objects" {
  compartment_id = oci_identity_compartment.prod_compute.id
  name           = "prod-functions-object-access"
  description    = "Allow prod functions to read objects from application data bucket"

  statements = [
    "Allow dynamic-group prod-functions to read objects in compartment id ${oci_identity_compartment.prod_compute.id}",
    "Allow dynamic-group prod-functions to read buckets in compartment id ${oci_identity_compartment.prod_compute.id}",
  ]

  depends_on = [
    oci_identity_dynamic_group.prod_functions,
    oci_identity_compartment.prod_compute,
  ]
}

# Allow app servers (tag-based dynamic group) to use only their specific secrets
resource "oci_identity_policy" "app_servers_specific_secrets" {
  compartment_id = oci_identity_compartment.prod_security.id
  name           = "prod-app-servers-secrets"
  description    = "Allow tagged app servers to retrieve specific secrets"

  statements = [
    "Allow dynamic-group prod-app-servers to read secret-bundles in compartment id ${oci_identity_compartment.prod_security.id} where target.secret.name = 'app-db-password'",
  ]

  depends_on = [
    oci_identity_dynamic_group.prod_app_servers,
    oci_identity_compartment.prod_security,
  ]
}
{% endhighlight %}

### Calling the OCI API from an instance using Instance Principals

Once the dynamic group and policy are in place, calling the OCI API from the instance requires no additional configuration. Here is the Python SDK pattern using `InstancePrincipalsSecurityTokenSigner`:

{% highlight python %}
import oci

# No config file needed — credentials come from the instance metadata service
signer = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
secrets_client = oci.secrets.SecretsClient(config={}, signer=signer)

secret_bundle = secrets_client.get_secret_bundle(secret_id="ocid1.vaultsecret.oc1...")
import base64
value = base64.b64decode(secret_bundle.data.secret_bundle_content.content).decode("utf-8")
print(value)
{% endhighlight %}

The `config={}` is intentional — the signer overrides all credential handling. No API key file on disk, no environment variable with a secret. The SDK calls IMDS, exchanges the cert for a session token, and signs the request transparently.

## Validating with OCI CLI

After applying, do not assume the permissions are live. IAM propagation in OCI can take up to 60 seconds after Terraform reports success. These CLI commands confirm the objects were created correctly and that the actual auth flow works.

{% highlight bash %}
# List all compartments under the tenancy, including root
oci iam compartment list \
  --compartment-id $TENANCY_OCID \
  --all \
  --include-root \
  --output table

# List all policies in a specific compartment
oci iam policy list \
  --compartment-id $PROD_SECURITY_OCID \
  --all

# Inspect a dynamic group's matching rule
oci iam dynamic-group get \
  --dynamic-group-id $DYNAMIC_GROUP_OCID

# Test Instance Principal auth FROM the instance — run this on the compute instance
oci iam region list --auth instance_principal

# Audit for overly permissive tenancy-level policies
oci iam policy list \
  --compartment-id $TENANCY_OCID \
  --all \
  --query "data[].statements[]" | grep -i "all-resources"
{% endhighlight %}

The last command is worth running on any tenancy you inherit. `manage all-resources in tenancy` appearing in the output of any policy outside the Administrators group is a finding that should be remediated immediately.

The `oci iam region list --auth instance_principal` command is the simplest possible instance principal test because it requires no special permissions — IAM can authenticate the instance and return the list of regions without needing a specific policy grant. If this command returns a 401, the dynamic group matching rule is not matching the instance or the policy has not propagated. If it returns the region list, the auth flow is working and you can move on to testing the specific API calls the application needs.

## Best Practices

### Never use `in tenancy` when `in compartment id <ocid>` is sufficient

A statement like `Allow group SecurityAdmins to read all-resources in tenancy` grants read access to every resource in every compartment across the entire tenancy. That is appropriate for a dedicated security audit role. It is not appropriate for a developer group, a CI/CD pipeline, or an application workload.

The blast radius difference is significant: if a credential is compromised, `in tenancy` exposes the entire OCI environment. `in compartment id <ocid>` limits the exposure to a specific compartment and its children. When in doubt, scope to the smallest compartment that covers the actual operational requirement.

### `manage all-resources in tenancy` belongs only to the Administrators group

This is CIS OCI Benchmark v2.0 control 1.2. The statement `Allow group X to manage all-resources in tenancy` is the OCI equivalent of giving someone root access to the entire cloud environment — they can create and delete any resource, modify any policy, and access any data in any compartment.

OCI creates an Administrators group with this permission when the tenancy is provisioned. The group should have the minimum set of human members necessary, and no other group or dynamic group should ever be granted equivalent scope. Prowler's `oci_iam_policy_no_allow_manage_all_resources_on_tenancy` check specifically detects this pattern in policies outside the default Administrators group. For the detection side — identifying when someone exploits overly permissive policies at runtime — see [OCI Cloud Guard custom detection rules](/oci-cloud-guard-detection-rules/).

If you need an automation service account with broad Terraform access, grant it `manage all-resources in compartment id <workloads_ocid>` scoped to the specific compartment hierarchy it manages — not to the tenancy.

### Dynamic group matching rules evaluate at call time — plan compartment migrations

There is no "warm-up" period for dynamic group membership. An instance is a member of a dynamic group if and only if its current attributes match the rule at the moment of the API call.

This has an important operational implication: if you migrate a compute instance to a different compartment, its dynamic group membership changes the moment the move is committed. Any active connections or in-flight API calls using Instance Principal from that instance will fail immediately after the move because the instance no longer matches the rule. Plan maintenance windows around compartment migrations for instances that use Instance Principal extensively.

### Add `depends_on` for policies that reference groups and compartments by name

OCI IAM has eventual-consistency propagation. After a group or compartment is created via the API, it can take up to 60 seconds for the object to be fully resolvable across all IAM endpoints. Terraform's resource graph does not account for this propagation delay — if two resources have no explicit dependency relationship, Terraform may create them in parallel.

If a policy resource is created before the group it references has fully propagated, the policy statement may contain a reference that IAM cannot resolve. The policy is created (the API call succeeds), but the statement grants nothing. The bug is invisible until someone reports that their access is not working.

The fix is to always add `depends_on` to policy resources listing the groups and compartments they reference. This forces sequential creation and gives propagation the best chance to complete before the policy is written.

### Set `enable_delete = true` on all `oci_identity_compartment` resources

Without `enable_delete = true`, `terraform destroy` will report success but leave the compartment intact in OCI. The next `terraform apply` will then fail because OCI detects a name conflict and returns an error.

This is a provider-level default that protects against accidental deletion of compartments that contain resources. For greenfield Terraform-managed infrastructure, `enable_delete = true` is almost always the right setting. For compartments that pre-existed Terraform adoption or that contain resources managed outside of Terraform, the default protection is more appropriate.

Set it explicitly either way so the intent is clear in the code:

{% highlight hcl %}
resource "oci_identity_compartment" "example" {
  compartment_id = var.tenancy_ocid
  name           = "ExampleCompartment"
  description    = "Managed by Terraform"
  enable_delete  = true   # terraform destroy will actually delete this compartment
}
{% endhighlight %}

## Conclusion

We covered the full OCI IAM model from first principles: the deny-by-default behavior, the five objects, the policy statement anatomy, and the four verbs. We built a three-level compartment hierarchy in Terraform, wired up groups and policies with OCID-based scoping to avoid the silent name-resolution bug, created dynamic groups with both compartment-based and tag-based matching rules, and gave compute instances and functions a machine identity via Instance Principal. We also validated each layer with OCI CLI commands and covered the operational gotchas that cause the most invisible failures in production IAM configurations.

The three-level compartment pattern is a practical starting point for most workloads. You can extend it by adding more environment tiers (staging, DR), by introducing sub-compartments for specific applications within the same environment, or by tightening policy statements to individual resources using `where` conditions. The fundamentals stay the same — the hierarchy just gets deeper. Once the IAM layer is solid, the natural next step is layering in [OCI Security Zones custom recipes](/oci-security-zones-part2/) to enforce preventive guardrails at the compartment level.

Start with this structure, apply it in a non-production tenancy first, run the validation commands, and get comfortable with IAM propagation delays before relying on any of these policies in a critical path.

Happy scripting!
