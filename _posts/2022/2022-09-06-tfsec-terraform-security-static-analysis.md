---
title: "tfsec: static analysis for Terraform security misconfigurations"
author: Victor Silva
date: 2022-09-06T10:22:18+00:00
layout: post
permalink: /tfsec-terraform-security-static-analysis/
excerpt: "How to use tfsec to catch security misconfigurations in Terraform code before they reach production — including custom checks, CI/CD integration with GitHub Actions, and reading the output."
categories:
  - DevSecOps
  - Terraform
tags:
  - tfsec
  - Terraform
  - DevSecOps
  - Security
  - GitHub Actions
  - IaC
---

Terraform lets you deploy infrastructure fast. That speed works in both directions — a misconfigured storage account with public blob access enabled deploys just as fast as a secure one. The difference is that the misconfigured one usually makes it through review because the Terraform looks correct at a glance. The attribute is missing, not wrong, and missing attributes tend not to catch the eye during a code review.

This is the problem that tfsec solves. It is a static analysis tool that scans your Terraform code for known security misconfigurations before `terraform plan` or `terraform apply` ever runs. It does not need credentials, a backend, or a real cloud connection — it reads the HCL files directly and checks the attributes against a library of security rules. A storage account without `min_tls_version = "TLS1_2"` fails the check. An NSG rule with `source_address_prefix = "0.0.0.0/0"` fails its check. The developer sees the failure immediately, in the same place they see the rest of their CI output.

tfsec is maintained by Aqua Security and the check library covers the major providers: Azure, AWS, GCP, and more. The Azure check set is particularly comprehensive for the kinds of issues that show up in real production environments — public access settings, encryption configuration, TLS versions, network exposure, and secrets in places they should not be. This post walks through installing tfsec, understanding its output, integrating it into GitHub Actions on pull requests, writing a custom check, and handling false positives cleanly.

## Installing tfsec

tfsec ships as a single binary with no runtime dependencies, which makes installation straightforward across all environments.

{% highlight bash %}
# macOS
brew install tfsec

# Linux (direct binary via install script)
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash

# Docker (useful in CI environments without package management)
docker pull aquasec/tfsec:latest

# Verify the installation
tfsec --version
{% endhighlight %}

The install script on Linux downloads the latest release binary from GitHub and places it in `/usr/local/bin`. If you prefer to pin a specific version — and in CI you should — download a tagged release binary directly from the [tfsec releases page](https://github.com/aquasecurity/tfsec/releases) instead of using the install script.

## Running tfsec Against Your Terraform Code

The basic invocation is `tfsec` followed by the path to the directory containing your Terraform files. tfsec walks the directory recursively and evaluates every `.tf` file it finds.

{% highlight bash %}
# Scan the current directory
tfsec .

# Scan a specific directory
tfsec ./infrastructure/azure

# Output as JSON (useful for programmatic processing)
tfsec . --format json > tfsec-results.json

# Output as JUnit (useful for CI systems that consume JUnit XML)
tfsec . --format junit > tfsec-results.xml

# Output as SARIF (useful for GitHub Code Scanning integration)
tfsec . --format sarif > tfsec-results.sarif

# Exclude a specific check by its rule ID
tfsec . --exclude azure-storage-no-public-access
{% endhighlight %}

## Understanding the Output

Let's look at a concrete example. Here is a storage account resource with several common misconfigurations omitted:

{% highlight hcl %}
resource "azurerm_storage_account" "example" {
  name                     = "mystorageaccount"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Missing: allow_blob_public_access = false
  # Missing: min_tls_version = "TLS1_2"
  # Missing: enable_https_traffic_only = true
}
{% endhighlight %}

Running `tfsec .` against this produces output like the following:

{% highlight text %}
Result #1 HIGH Public access block not set
────────────────────────────────────────
  ID        azure-storage-no-public-access
  Impact    Blob containers may be publicly accessible
  Resource  azurerm_storage_account.example
  File      main.tf:1-8
  Link      https://aquasecurity.github.io/tfsec/v1.28.0/checks/azure/storage/no-public-access/

Result #2 HIGH Secure transfer to storage account not enforced
────────────────────────────────────────
  ID        azure-storage-enforce-https
  Impact    HTTP traffic to the storage account is permitted
  Resource  azurerm_storage_account.example
  File      main.tf:1-8
  Link      https://aquasecurity.github.io/tfsec/v1.28.0/checks/azure/storage/enforce-https/

Result #3 HIGH Storage account does not enforce the use of TLS 1.2
────────────────────────────────────────
  ID        azure-storage-use-secure-tls-policy
  Impact    TLS older than 1.2 can be negotiated, introducing cryptographic weaknesses
  Resource  azurerm_storage_account.example
  File      main.tf:1-8
  Link      https://aquasecurity.github.io/tfsec/v1.28.0/checks/azure/storage/use-secure-tls-policy/

  3 potential problems detected.
{% endhighlight %}

Each result gives you the severity level, a human-readable description, the rule ID, the impact statement, and the exact file and line range where the offending resource was found. The link takes you to the documentation page for that check, which explains the risk and shows the remediation. This is the format developers need to act on a finding immediately without leaving the terminal.

## Common Azure Findings

These are the misconfigurations that surface most frequently when running tfsec against Azure Terraform for the first time:

| Rule ID | Resource | Issue |
|---------|----------|-------|
| `azure-storage-no-public-access` | azurerm_storage_account | Public blob access not disabled |
| `azure-storage-use-secure-tls-policy` | azurerm_storage_account | TLS version below 1.2 allowed |
| `azure-storage-enforce-https` | azurerm_storage_account | HTTP traffic not disabled |
| `azure-keyvault-ensure-secret-expiry` | azurerm_key_vault_secret | No expiration date set on secrets |
| `azure-network-no-public-ingress` | azurerm_network_security_rule | Inbound rule allows traffic from 0.0.0.0/0 |
| `azure-database-enable-audit` | azurerm_sql_server | Auditing not enabled on the SQL server |
| `azure-compute-no-secrets-in-user-data` | azurerm_virtual_machine | Potential secret value in user data field |

None of these are exotic edge cases. They are the defaults-are-insecure problems that appear in almost every first-pass scan of a production Terraform codebase that was not built with tfsec in the loop from the start.

## Fixing the Findings

Fixing the storage account findings from the example above looks like this:

{% highlight hcl %}
resource "azurerm_storage_account" "example" {
  name                     = "mystorageaccount"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Addresses azure-storage-no-public-access
  allow_blob_public_access  = false

  # Addresses azure-storage-use-secure-tls-policy
  min_tls_version           = "TLS1_2"

  # Addresses azure-storage-enforce-https
  enable_https_traffic_only = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}
{% endhighlight %}

After these changes, `tfsec .` produces zero findings for this resource. The changes are all additive — you are not restructuring the resource, just supplying the values that tfsec expects to see for a compliant configuration. In most cases the remediation is exactly this straightforward: the check fails because an attribute is missing or set to an unsafe default, and fixing it means adding or correcting that attribute.

## GitHub Actions Integration

This is where tfsec pays for itself. Running it manually on your local machine is useful during development, but the real value comes from running it automatically on every pull request that touches Terraform files. The developer who introduced the misconfiguration sees it immediately, in the PR, before anyone reviews the code.

Create `.github/workflows/tfsec.yml`:

{% highlight yaml %}
name: tfsec security scan

on:
  pull_request:
    paths:
      - '**.tf'

jobs:
  tfsec:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          working_directory: ./infrastructure
          format: sarif
          sarif_file: tfsec-results.sarif

      - name: Upload SARIF results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: tfsec-results.sarif
{% endhighlight %}

The `paths` filter on the pull request trigger ensures this workflow only runs when a `.tf` file was modified. There is no point scanning Terraform files on a PR that only touched documentation.

The `aquasecurity/tfsec-action@v1.0.0` action handles the tfsec installation and invocation for you. The `format: sarif` and `sarif_file` parameters tell it to write SARIF output to a file, which the next step then uploads to GitHub's Code Scanning API. This is the part that makes findings appear as inline annotations in the PR diff and as alerts in the Security tab. Reviewers see security issues alongside the code that introduced them without having to look at CI logs.

The `if: always()` condition on the upload step ensures the SARIF file is uploaded even when tfsec finds issues and the action exits with a non-zero code. Without it, a finding would prevent the upload and the Security tab would never receive the results.

## Writing a Custom Check

The built-in check library covers the well-known misconfigurations, but your organization likely has rules that no off-the-shelf scanner knows about. tfsec supports custom checks written in YAML, which is the stable format in the v1.x series.

Here is a custom check that enforces blob versioning on storage accounts — something the built-in checks do not require but your disaster recovery policy might:

{% highlight yaml %}
# custom_checks/azure-storage-versioning-enabled.yaml
---
checks:
  - code: CUS001
    description: Storage account should have blob versioning enabled
    impact: Without versioning, accidental deletes or overwrites cannot be recovered
    resolution: Enable versioning in the blob_properties block
    requiredTypes:
      - resource
    requiredLabels:
      - azurerm_storage_account
    severity: LOW
    matchSpec:
      name: blob_properties
      action: isPresent
      predicateMatchSpec:
        name: versioning_enabled
        action: equals
        value: true
    errorMessage: Storage account does not have blob versioning enabled
    relatedLinks:
      - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account#versioning_enabled
{% endhighlight %}

Run tfsec with your custom check directory:

{% highlight bash %}
tfsec . --custom-check-dir ./custom_checks
{% endhighlight %}

The YAML check structure maps directly to tfsec's internal evaluation model. `requiredTypes` and `requiredLabels` scope the check to specific resource types — in this case only `azurerm_storage_account` resources will be evaluated. `matchSpec` defines the attribute condition that must be true for the check to pass: the `blob_properties` block must be present and within it `versioning_enabled` must equal `true`. If either condition is not met, the check fails and `errorMessage` is surfaced in the output.

Keep custom checks in version control alongside your Terraform code. They are part of your security configuration and should go through the same review process as any other change.

## Handling False Positives

Not every finding requires a fix. Sometimes a rule fires on a configuration that is deliberately non-compliant for a documented business reason — a management NSG rule that allows traffic from any IP because VPN termination is handled upstream, for example. tfsec supports inline ignore comments to suppress specific checks on specific resources:

{% highlight hcl %}
resource "azurerm_network_security_rule" "management" {
  # tfsec:ignore:azure-network-no-public-ingress -- VPN gateway handles source IP restriction; see ADR-0012
  source_address_prefix     = "0.0.0.0/0"
  destination_port_range    = "22"
  access                    = "Allow"
  direction                 = "Inbound"
  protocol                  = "Tcp"
  priority                  = 100
  name                      = "allow-ssh-management"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = var.vnet_name
  network_security_group_name = azurerm_network_security_group.management.name

  source_port_range          = "*"
  destination_address_prefix = "*"
}
{% endhighlight %}

The `tfsec:ignore` comment must appear on the line immediately before the attribute or on the resource block declaration. The format is `tfsec:ignore:<rule-id>`. Everything after the double dash is a free-form comment — use it to explain why this ignore is justified. That explanation is the most important part: a naked ignore with no context is a liability; one that references an ADR or a ticket is a documented exception that can be reviewed and revoked when circumstances change.

Use ignores sparingly. An ignore says "I know this looks like a problem and I have decided it is not." That is a meaningful statement, and it should be true. If you find yourself adding ignores in bulk to quiet a noisy scan, the right response is to fix the underlying issues or adjust the severity threshold on the scan gate, not to ignore your way to a clean result.

## Best Practices

**Pin the tfsec version in CI.** The built-in check library evolves with each release and new checks occasionally fire on configurations that were previously clean. Updating tfsec in CI should be a deliberate decision, not an automatic side effect of a runner rebuild. Use a specific version tag on the action and on any direct binary installations.

**Run tfsec before `terraform plan` in your local workflow.** Add `tfsec .` as a pre-commit hook or a Makefile target that runs before you commit. The earlier you catch a finding, the cheaper it is to fix — a finding in your local editor is trivially cheap; the same finding in a production incident is not.

**Gate on severity levels.** Not every finding should block a PR. Consider failing the build only on HIGH and CRITICAL severity findings and surfacing MEDIUM and LOW as informational annotations in the Security tab. This keeps the gate meaningful: the team pays attention to what blocks the PR and can triage the lower-severity findings through a standard backlog process.

**Document every ignore.** Treat each `tfsec:ignore` comment as a note in your technical debt register. Include a reference to the decision that justified it — an ADR number, a ticket ID, an explanation. Without that context, the next person to read the code has no way to know whether the ignore is still valid.

**Combine tfsec with other layers.** tfsec catches static misconfigurations in HCL. It does not catch issues that emerge at runtime, drift that happens outside of Terraform, or misconfigurations in resources that Terraform did not deploy. Use it as one layer in a defense-in-depth approach alongside runtime policy tools, cloud-native security services, and regular access reviews.

## What You End Up With

After this setup, static security analysis runs on every pull request that touches Terraform. The developer who writes a storage account without `min_tls_version = "TLS1_2"` sees a HIGH finding in their PR diff before anyone reviews the code. The person who adds an NSG rule open to the internet sees the same. These findings do not require a security engineer to catch — they surface automatically, at the point in the workflow where they are cheapest to fix.

Custom checks extend this to your organization's specific policies. The YAML format is expressive enough to cover most attribute-level requirements without requiring you to write code. When the built-in library does not cover something your compliance requirements demand, you write a custom check and it runs in the same scan, produces the same output format, and integrates with the same GitHub Security tab workflow.

That is the DevSecOps promise in practice: security controls that run automatically, surface findings where developers are already working, and require no manual coordination between security teams and development teams to operate.

Happy scripting!
