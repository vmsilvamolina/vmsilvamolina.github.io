---
title: "Checkov custom policies for Azure Terraform resources"
author: Victor Silva
date: 2024-10-14T23:22:12+00:00
layout: post
permalink: /checkov-custom-policies-azure-terraform/
excerpt: "Built-in Checkov checks cover common misconfigurations, but every organization has rules that no off-the-shelf scanner knows about. This post walks through running Checkov against an Azure Terraform project, understanding how built-in checks are structured, writing a custom Python check, and wiring everything into GitHub Actions."
categories:
  - DevSecOps
tags:
  - checkov
  - terraform
  - azure
  - devsecops
  - iac-security
---

When you run Checkov against your Terraform for the first time, it finds things. A storage account with public blob access enabled. A Key Vault with soft delete disabled. An NSG rule open to 0.0.0.0/0. These are the obvious misconfigurations and the built-in check library covers them well. The problem is not finding what Checkov already knows about — it is finding the things that are specific to your organization.

Your security team requires every resource to carry a `cost_center` tag or it will not be processed by the billing system. Your storage accounts must use a specific SKU and have infrastructure encryption enabled because of a compliance requirement. Your team has decided that all Azure resources must be deployed to a specific set of approved regions. None of that is in the built-in check library because it is specific to you. Writing custom checks is how you close that gap.

This post covers running Checkov against a real Azure Terraform project, understanding how the built-in checks are structured so you can write your own, implementing a custom Python check that enforces a mandatory tag policy, and integrating the whole thing into a GitHub Actions pipeline that gates pull requests.

## How Checkov Evaluates Terraform

Before writing any code it is worth understanding what Checkov is actually scanning. Checkov does not run `terraform plan`. It parses the Terraform HCL files directly and builds an internal graph of resource attributes and their relationships. This means it runs without credentials, without a backend, and without requiring `terraform init` to have been run against the target directory.

The trade-off is that Checkov evaluates the configuration as written, not as it would be applied. If a value is computed at plan time — an attribute set from a `data` source or a resource reference — Checkov may not be able to evaluate it. For most security checks this is fine, because the misconfigurations you care about are the ones hardcoded or defaulted in the HCL, not the ones that emerge from dynamic values.

Each built-in check is a Python class that inherits from `BaseResourceCheck`. The class declares which resource type it targets and which attribute paths it evaluates. When Checkov processes a resource, it calls the `scan_resource_conf` method on every check that targets that resource type and collects pass or fail results. Custom checks follow exactly the same pattern — you register them from a directory and Checkov picks them up alongside the built-in library.

## Prerequisites

To follow along you will need:

- Python 3.8 or later
- Checkov installed: `pip install checkov`
- Terraform 1.3 or later (for writing the test configuration — Checkov does not execute Terraform)
- An Azure Terraform project to scan, or the sample configuration provided in this post
- For the GitHub Actions section: a repository with GitHub Actions enabled

Verify your Checkov installation:

{% highlight bash %}
checkov --version
{% endhighlight %}

{% highlight bash %}
checkov 3.x.y
{% endhighlight %}

## Running Checkov Against an Azure Terraform Project

Start with a basic scan against a directory containing Terraform files. Given this sample configuration saved as `main.tf`:

{% highlight hcl %}
resource "azurerm_resource_group" "example" {
  name     = "rg-example"
  location = "eastus"
}

resource "azurerm_storage_account" "example" {
  name                     = "stexampleaccount"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_0"

  tags = {
    environment = "dev"
  }
}
{% endhighlight %}

Run a scan against the directory:

{% highlight bash %}
checkov -d ./infra --framework terraform
{% endhighlight %}

Checkov prints each check with a PASSED or FAILED result, the check ID, the resource it evaluated, and the file path and line number. The output looks like:

{% highlight text %}
Check: CKV_AZURE_3: "Ensure that 'Secure transfer required' is enabled for Storage Account"
	PASSED for resource: azurerm_storage_account.example

Check: CKV_AZURE_44: "Ensure Storage Account is using the latest version of TLS encryption"
	FAILED for resource: azurerm_storage_account.example
	File: /infra/main.tf:8-20
	Guide: https://docs.bridgecrew.io/docs/bc_azr_storage_3

Check: CKV2_AZURE_1: "Ensure storage for critical data are encrypted with Customer Managed Key"
	FAILED for resource: azurerm_storage_account.example
	File: /infra/main.tf:8-20
{% endhighlight %}

To get output in a format suitable for CI integration, use `--output sarif` or `--output json`. SARIF integrates directly with the GitHub Security tab.

{% highlight bash %}
checkov -d ./infra --framework terraform --output sarif --output-file-path ./results
{% endhighlight %}

This writes `results/results_tf.sarif`. You can also filter checks by severity or suppress specific checks with an inline comment in the Terraform:

{% highlight hcl %}
resource "azurerm_storage_account" "example" {
  # checkov:skip=CKV2_AZURE_1:Customer-managed keys managed at org level via policy
  name = "stexampleaccount"
  ...
}
{% endhighlight %}

## Understanding a Built-in Check

Before writing a custom check, read one of the existing built-in checks to understand the pattern. The TLS version check that flagged our storage account is a good example. Checkov's built-in checks live in the installed package under `checkov/terraform/checks/resource/azure/`. You can inspect them directly:

{% highlight bash %}
python3 -c "import checkov; import os; print(os.path.dirname(checkov.__file__))"
{% endhighlight %}

The TLS check looks roughly like this:

{% highlight python %}
from checkov.common.models.enums import CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class StorageAccountMinTLS(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Storage Account is using the latest version of TLS encryption"
        id = "CKV_AZURE_44"
        supported_resources = ["azurerm_storage_account"]
        categories = [CheckCategories.ENCRYPTION]
        super().__init__(name=name, id=id, categories=categories,
                         supported_resources=supported_resources)

    def scan_resource_conf(self, conf):
        min_tls = conf.get("min_tls_version", ["TLS1_2"])
        if isinstance(min_tls, list):
            min_tls = min_tls[0]
        return min_tls == "TLS1_2"

check = StorageAccountMinTLS()
{% endhighlight %}

The structure is consistent across every built-in check: a class, a constructor that declares the check ID and target resource types, and a `scan_resource_conf` method that receives the resource configuration as a dictionary and returns `True` for pass or `False` for fail. The `conf` dictionary is keyed by attribute name, and values are wrapped in lists (because Terraform HCL attribute values are always lists in Checkov's internal representation — always unwrap before comparing).

The module-level instantiation at the bottom (`check = StorageAccountMinTLS()`) is what registers the check with Checkov's runner. You need this in every custom check file.

## Writing a Custom Check: Mandatory Tag Policy

The scenario: your organization requires every Azure resource to carry a `cost_center` tag and an `environment` tag. Missing tags cause billing problems and make resource lifecycle management unreliable. No built-in check enforces your specific required tag set.

Create a directory for your custom checks:

{% highlight bash %}
mkdir -p ./checkov_custom_checks
{% endhighlight %}

Create `./checkov_custom_checks/check_required_tags.py`:

{% highlight python %}
from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

REQUIRED_TAGS = {"cost_center", "environment"}

TAGGABLE_AZURE_RESOURCES = [
    "azurerm_resource_group",
    "azurerm_storage_account",
    "azurerm_virtual_network",
    "azurerm_subnet",
    "azurerm_key_vault",
    "azurerm_linux_virtual_machine",
    "azurerm_windows_virtual_machine",
    "azurerm_app_service",
    "azurerm_sql_server",
    "azurerm_cosmosdb_account",
]


class AzureRequiredTags(BaseResourceCheck):
    def __init__(self):
        name = "Ensure required organization tags are present on Azure resources"
        id = "CKV_CUSTOM_AZURE_1"
        supported_resources = TAGGABLE_AZURE_RESOURCES
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(
            name=name,
            id=id,
            categories=categories,
            supported_resources=supported_resources,
        )

    def scan_resource_conf(self, conf):
        tags = conf.get("tags")

        # No tags block at all
        if not tags:
            return CheckResult.FAILED

        # Unwrap list wrapping from Checkov's internal representation
        if isinstance(tags, list):
            tags = tags[0]

        # Tags block resolves to a variable reference or expression at plan time
        if not isinstance(tags, dict):
            return CheckResult.UNKNOWN

        present_tags = {key.lower() for key in tags.keys()}
        missing = REQUIRED_TAGS - present_tags

        if missing:
            self.details.append(f"Missing required tags: {sorted(missing)}")
            return CheckResult.FAILED

        return CheckResult.PASSED


check = AzureRequiredTags()
{% endhighlight %}

A few things to note here. `CheckResult.UNKNOWN` is the right return value when the check cannot make a definitive determination — in this case when the tags block is a Terraform expression that Checkov cannot resolve statically. Returning `FAILED` for unknowns would create noise; returning `PASSED` would create a false sense of security. `UNKNOWN` results are excluded from the pass/fail count and surfaced separately.

The `self.details.append()` call adds a human-readable message that appears in the Checkov output alongside the FAILED result. Use this to make the failure actionable — tell the developer exactly which tags are missing rather than just saying the check failed.

Run Checkov with the custom check directory:

{% highlight bash %}
checkov -d ./infra --framework terraform --external-checks-dir ./checkov_custom_checks
{% endhighlight %}

The custom check appears in the output alongside built-in checks. If the storage account is missing `cost_center`:

{% highlight text %}
Check: CKV_CUSTOM_AZURE_1: "Ensure required organization tags are present on Azure resources"
	FAILED for resource: azurerm_storage_account.example
	File: /infra/main.tf:8-20

		Missing required tags: ['cost_center']
{% endhighlight %}

## Writing a Second Custom Check: Storage Account Settings

Tag enforcement is useful but the same pattern applies to any attribute requirement. Here is a second check that enforces storage account infrastructure encryption and requires Standard_LRS or Standard_GRS replication — no Premium SKU allowed for general-purpose storage in this fictional policy.

Create `./checkov_custom_checks/check_storage_policy.py`:

{% highlight python %}
from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

ALLOWED_REPLICATION_TYPES = {"LRS", "GRS", "RAGRS"}


class AzureStorageAccountPolicy(BaseResourceCheck):
    def __init__(self):
        name = "Ensure storage accounts comply with organization storage policy"
        id = "CKV_CUSTOM_AZURE_2"
        supported_resources = ["azurerm_storage_account"]
        categories = [CheckCategories.ENCRYPTION]
        super().__init__(
            name=name,
            id=id,
            categories=categories,
            supported_resources=supported_resources,
        )

    def scan_resource_conf(self, conf):
        failures = []

        # Check infrastructure encryption
        infra_encryption = conf.get("infrastructure_encryption_enabled", [False])
        if isinstance(infra_encryption, list):
            infra_encryption = infra_encryption[0]
        if not infra_encryption:
            failures.append("infrastructure_encryption_enabled must be true")

        # Check replication type
        replication = conf.get("account_replication_type", [""])
        if isinstance(replication, list):
            replication = replication[0]
        if isinstance(replication, str) and replication.upper() not in ALLOWED_REPLICATION_TYPES:
            failures.append(
                f"account_replication_type '{replication}' not in allowed set: "
                f"{sorted(ALLOWED_REPLICATION_TYPES)}"
            )

        if failures:
            for f in failures:
                self.details.append(f)
            return CheckResult.FAILED

        return CheckResult.PASSED


check = AzureStorageAccountPolicy()
{% endhighlight %}

This check accumulates multiple failures into `self.details` before returning, so a single resource with two policy violations surfaces both in one scan result rather than requiring two separate scan runs to surface the second.

## Testing Custom Checks

Before committing your custom checks, test them in isolation. Create a small Terraform fixture that deliberately exercises the pass and fail paths:

{% highlight bash %}
mkdir -p ./tests/fixtures
{% endhighlight %}

Create `./tests/fixtures/storage_pass.tf`:

{% highlight hcl %}
resource "azurerm_storage_account" "compliant" {
  name                              = "stcompliant"
  resource_group_name               = "rg-test"
  location                          = "eastus"
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  infrastructure_encryption_enabled = true

  tags = {
    cost_center = "platform-eng"
    environment = "production"
  }
}
{% endhighlight %}

Create `./tests/fixtures/storage_fail.tf`:

{% highlight hcl %}
resource "azurerm_storage_account" "non_compliant" {
  name                     = "stnoncompliant"
  resource_group_name      = "rg-test"
  location                 = "eastus"
  account_tier             = "Premium"
  account_replication_type = "ZRS"
  min_tls_version          = "TLS1_0"

  tags = {
    environment = "dev"
  }
}
{% endhighlight %}

Run both fixtures through the custom checks:

{% highlight bash %}
# Should pass CKV_CUSTOM_AZURE_1 and CKV_CUSTOM_AZURE_2
checkov -f ./tests/fixtures/storage_pass.tf \
  --external-checks-dir ./checkov_custom_checks \
  --check CKV_CUSTOM_AZURE_1,CKV_CUSTOM_AZURE_2

# Should fail CKV_CUSTOM_AZURE_1 (missing cost_center) and CKV_CUSTOM_AZURE_2 (ZRS not allowed, no infra encryption)
checkov -f ./tests/fixtures/storage_fail.tf \
  --external-checks-dir ./checkov_custom_checks \
  --check CKV_CUSTOM_AZURE_1,CKV_CUSTOM_AZURE_2
{% endhighlight %}

Using `--check` to limit to your custom check IDs keeps the output focused. Running the full check suite against fixtures produces noise from built-in checks that are not what you are testing.

## GitHub Actions Integration

Create `.github/workflows/checkov.yaml`:

{% highlight yaml %}
name: Checkov IaC Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

permissions:
  contents: read
  security-events: write

jobs:
  checkov-scan:
    name: Checkov Terraform Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install Checkov
        run: pip install checkov==3.2.231

      - name: Run Checkov with custom checks
        id: checkov
        run: |
          checkov -d ./infra \
            --framework terraform \
            --external-checks-dir ./checkov_custom_checks \
            --output sarif \
            --output-file-path ./results \
            --soft-fail
        continue-on-error: true

      - name: Upload SARIF to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: results/results_tf.sarif
          category: checkov-terraform

      - name: Fail on HIGH and CRITICAL findings
        run: |
          checkov -d ./infra \
            --framework terraform \
            --external-checks-dir ./checkov_custom_checks \
            --check-severity HIGH,CRITICAL \
            --compact
{% endhighlight %}

The split between the two Checkov steps mirrors the Trivy pattern: the first step runs with `--soft-fail` so it always exits zero, writes the SARIF, and uploads findings to the Security tab. The second step runs with a severity filter and exits non-zero if any HIGH or CRITICAL findings are present, breaking the build. Separating them ensures you always have Security tab results even when the gate fires.

Pin Checkov to a specific version (`checkov==3.2.231`) rather than `checkov` or `checkov>=3`. Checkov ships updates frequently and new versions occasionally add checks that cause previously clean scans to fail. Updating the version should be a deliberate decision, not an automatic side effect of a runner rebuild.

## Best Practices

**Use a consistent ID prefix for your custom checks.** The convention `CKV_CUSTOM_` followed by a cloud abbreviation and a sequential number keeps your checks visually distinct from built-in checks in output and makes it easier to write targeted suppression rules.

**Return `UNKNOWN` instead of `PASSED` for unresolvable values.** When an attribute value is a Terraform variable reference or an expression that Checkov cannot resolve, you cannot determine compliance. Returning `PASSED` silently skips enforcement for those resources. `UNKNOWN` surfaces the ambiguity and lets the team decide how to handle it.

**Keep `TAGGABLE_AZURE_RESOURCES` in a shared module.** The list of taggable resource types will grow as your Terraform footprint grows. Put it in a shared Python file inside `checkov_custom_checks/` rather than duplicating it across every tag-related check. When a new resource type is added to your Terraform, you update one list.

**Add a `.checkov.yaml` configuration file to your repository root.** This keeps CLI flags out of your workflow YAML and lets developers run the same scan locally with a plain `checkov -d .` command:

{% highlight yaml %}
framework:
  - terraform
external-checks-dir:
  - ./checkov_custom_checks
directory:
  - ./infra
output:
  - cli
compact: true
{% endhighlight %}

**Treat custom check files as production code.** They live in version control, they have tests, and changes to them should go through pull request review. A custom check that always returns `PASSED` due to a logic bug is worse than no check — it creates false confidence.

**Scope severity correctly on the gate step.** Failing the build on every Checkov finding, including informational ones, creates so much noise that teams start adding blanket suppressions. Gate on HIGH and CRITICAL. Surface MEDIUM and LOW in the Security tab for awareness. Developers will fix the HIGH/CRITICAL issues and can triage the rest through the standard security review process.

## What You End Up With

After this setup you have a static analysis pipeline that evaluates your Azure Terraform against both the Checkov built-in check library and your organization's specific policies. Custom checks run in the same invocation as built-in checks, produce the same output format, and integrate with the Security tab through SARIF. Developers see findings as inline annotations on pull request diffs, not as CI log output they have to dig through.

The mandatory tag check and the storage policy check in this post are starting points. The same pattern — `BaseResourceCheck`, `scan_resource_conf`, `self.details` for human-readable context — works for any attribute-level policy you need to enforce: required firewall rules on SQL servers, minimum retention policies on diagnostic settings, approved VM image references, or anything else your compliance requirements demand.

Happy scripting!
