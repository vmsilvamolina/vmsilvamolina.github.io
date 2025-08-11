---
title: 'Oracle Cloud Security Zones [English]'
author: Victor Silva
date: 2025-08-05T22:36:18+00:00
layout: post
permalink: /oci-security-zones/
excerpt: "In today's cloud-first world, security isn't just about monitoring threats—it's about preventing them from happening in the first place. Oracle Cloud Infrastructure (OCI) Security Zones provide exactly this capability: proactive, policy-driven security enforcement that prevents misconfigurations before they can become vulnerabilities."
categories:
  - Oracle
  - Security
tags:
  - Oracle Cloud
  - Security Zones
  - Security
---

In today's cloud-first world, security isn't just about monitoring threats—it's about preventing them from happening in the first place. Oracle Cloud Infrastructure (OCI) Security Zones provide exactly this capability: proactive, policy-driven security enforcement that prevents misconfigurations before they can become vulnerabilities.
This comprehensive guide will walk you through implementing Security Zones with extensive code examples, Terraform configurations, CLI commands, and interactive demonstrations.

### What Are OCI Security Zones? A Technical Overview

Security Zones in OCI are compartment-level security boundaries that enforce predefined security policies. They act as a "security firewall" for your infrastructure-as-code deployments, automatically validating every resource creation request against established security rules.


```plaintext
┌─────────────────────────────────────────────────────────┐
│      OCI Tenancy                                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │      Compartment                                │    │
│  │  ┌─────────────────────────────────────────┐    │    │
│  │  │      Security Zone                      │    │    │
│  │  │  ┌─────────────────────────────────┐    │    │    │
│  │  │  │      Security Recipe            │    │    │    │
│  │  │  │       • Network Rules           │    │    │    │
│  │  │  │       • Storage Rules           │    │    │    │
│  │  │  │       • Compute Rules           │    │    │    │
│  │  │  │       • IAM Rules               │    │    │    │
│  │  │  └─────────────────────────────────┘    │    │    │
│  │  └─────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```


### Setting Up Your Development Environment

Before we dive into code examples, let's set up the necessary tools:

- OCI CLI installed and configured:
To install the OCI CLI, follow the official documentation: [Installing the CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)

- Cloud Guard enabled in your OCI compartment:
```bash
# To check the status of Cloud Guard
oci cloud-guard configuration get --compartment-id <compartmentId>
```


We could obtain the compartment ID using the CLI:

```bash
#Replace the compartment name before running the command
COMPARTMENT_ID=$(oci iam compartment list \
                  --name "ocilabs" \
                  --query "data[?contains(\"id\",'compartment')].id | [0]" \
                  --raw-output)
```


First, let's see all the policies available in the Security Zone. We can do this using the OCI CLI:

```bash
oci cloud-guard security-policy-collection list-security-policies \
  --compartment-id $COMPARTMENT_ID \
  --query "data.items[*]".{"category:category,name:\"display-name\""} \
  --output table
```

With all the prerequisites in place, we can now create a Security Zone in Oracle Cloud Infrastructure (OCI). A Security Zone is a compartment that enforces security policies to ensure compliance with best practices.


```bash
oci cloud-guard security-policy-collection list-security-policies --compartment-id $COMPARTMENT_ID --query "data.items[?contains(\"display-name\", 'public_subnets')]"
```

And add some manipulation to get only the id:

```bash
DENY_PUBLIC_SUBNET_POLICY_ID=$(oci cloud-guard security-policy-collection list-security-policies \
  --compartment-id $COMPARTMENT_ID \
  --query "data.items[?contains(\"display-name\", 'public_subnets')].id | [0]")
```

The lasts steps are to create a Security Recipe that will use the policy we just found. A Security Recipe is a collection of security policies that define the security posture for resources created within a Security Zone.

```bash
oci cloud-guard security-recipe create \
  --compartment-id $COMPARTMENT_ID \
  --display-name "fromCLI" \
  --security-policies '['$DENY_PUBLIC_SUBNET_POLICY_ID']'
```


Now, I'll try to create a public subnet in the VCN.

```bash
# Get the Virtual Cloud Network (VCN) ID
VCN_ID=$(oci network vcn list \
          --compartment-id $COMPARTMENT_ID \
          --query "data[?contains(\"id\",'vcn')].id | [0]" \
          --raw-output)

# Try to create a public subnet
oci network subnet create \
  --cidr-block "10.0.1.0/24" \
  --compartment-id $COMPARTMENT_ID \
  --vcn-id $VCN_ID
```

After that, we will see the following error message:

<img src="/assets/images/postsImages/OCI_0.png" alt="Error creating public subnet in OCI Security Zone" />


Perfect! OK, return an error message, but it's the behavior we expect. The Security Zone prevents the creation of a public subnet, as it violates the security policies defined in the Security Recipe.

The same action, but using the web portal return ths message:

<img src="/assets/images/postsImages/OCI_1.png" alt="Error creating public subnet in OCI Security Zone using web portal" />

Resuming, Security Zones in OCI are a powerful feature that helps enforce security best practices across your cloud environment. By defining Security Recipes, you can ensure that resources created within a Security Zone comply with your organization's security policies.

Happy scripting!
