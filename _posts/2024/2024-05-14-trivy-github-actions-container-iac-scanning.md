---
title: 'Trivy in GitHub Actions: Container and IaC Scanning in One Pipeline'
author: Victor Silva
date: 2024-05-14T10:00:00+00:00
layout: post
permalink: /trivy-github-actions-container-iac-scanning/
excerpt: "Running separate scanners for container images and Terraform is common but wasteful. Trivy covers both scan types in a single tool. This post walks through building a GitHub Actions pipeline that scans images and IaC, uploads SARIF to the Security tab, and gates the build on HIGH and CRITICAL findings."
categories:
  - DevOps
  - Security
tags:
  - Trivy
  - GitHub Actions
  - DevSecOps
  - Terraform
  - Container Security
  - SARIF
---

You have a Dockerfile and a Terraform directory sitting in the same repository. Somewhere in your CI pipeline you are running Snyk on the image, tfsec on the infrastructure code, and maybe a third tool for secrets. Each one needs its own action, its own config file, and its own set of suppressions. When a new CVE drops you update three places instead of one. When a developer asks why the build failed, you look at three different output formats. This is the kind of friction that makes security feel like a tax rather than a feature.

Trivy fixes this. It is a single open-source scanner from Aqua Security that covers container image vulnerabilities, IaC misconfigurations, secret detection, and SBOM generation under one binary. In this post I will show you how to wire it into GitHub Actions so that both your image and your Terraform code are scanned in the same pipeline, findings are visible in the GitHub Security tab via SARIF upload, and HIGH and CRITICAL issues actually break the build.

## How Trivy Approaches Scanning

Before touching any YAML, it is worth understanding the scan modes because choosing the wrong one is a common source of confusion.

- `scan-type: image` - scans a built container image for OS and library vulnerabilities. This is the mode most people reach for first.
- `scan-type: config` - scans IaC files (Terraform, CloudFormation, Kubernetes manifests, Helm charts) for misconfigurations. Use this when you only want IaC results with no vulnerability noise.
- `scan-type: filesystem` - scans a local directory tree and can run both vulnerability and misconfiguration checks in one pass. Useful for monorepos, but produces combined output that is harder to separate in SARIF.

For a repository that has both a containerized application and Terraform infrastructure, the cleanest approach is two parallel jobs: one `image` scan and one `config` scan. Each produces its own SARIF file, each uploads to a separate category in the Security tab, and each has its own gate step.

Trivy pulls its vulnerability database from GitHub Container Registry and refreshes it every six hours. If GHCR is unavailable when your runner starts and you have no local cache, the scan fails with a database error rather than a security error. Caching the database with `actions/cache` is not optional - it is a reliability requirement.

## Prerequisites

To follow along you will need:

- A GitHub repository with a `Dockerfile` at the root and Terraform files under an `./infra` directory (adjust paths as needed for your layout)
- GitHub Advanced Security enabled on the repository - this is free for all public repositories and available to GitHub Enterprise customers for private repositories
- The `security-events: write` permission in your workflow so the upload-sarif action can post findings to the Security tab
- Docker available on your runner (the default `ubuntu-latest` runners include it)
- Optionally, Trivy installed locally for testing before you push - more on that in the testing section

## Configuration Files

Two files live at the repository root and are referenced by every Trivy step in the workflow.

### trivy.yaml

This file controls global Trivy behavior and keeps your workflow YAML lean. Create it at the root of your repository:

{% highlight yaml %}
timeout: 10m0s
cache-dir: ~/.cache/trivy
vulnerability:
  ignore-unfixed: true
  severity:
    - HIGH
    - CRITICAL
misconfiguration:
  terraform:
    exclude-downloaded-modules: true
scanners:
  - vuln
  - misconfig
  - secret
skip-dirs:
  - .terraform
  - vendor
skip-files:
  - '**/*.tfstate'
  - '**/*.tfstate.backup'
{% endhighlight %}

A few things worth calling out here. `ignore-unfixed: true` means Trivy will not report vulnerabilities that have no available fix. Reporting unfixed CVEs creates noise without giving developers anything actionable to do. `exclude-downloaded-modules: true` tells Trivy to skip the contents of any modules pulled from the Terraform registry - you are responsible for your own code, not the upstream module maintainers' code. The `skip-files` list excludes tfstate files because they contain resolved values and resource IDs that would generate false positives from the secret scanner.

### .trivyignore

Suppression files are where security tooling often gets abused. Every suppression should have a documented reason and an expiry date. Trivy v0.47 and later supports the `exp:YYYY-MM-DD` syntax that automatically reactivates a suppressed finding when the date passes. This removes the "we suppressed it in 2023 and forgot about it" problem.

{% highlight text %}
# CVE in base image, no fix upstream - review by 2025-06-01
CVE-2023-4911 exp:2025-06-01

# IaC check: S3 logging handled by org-level config
AVD-AWS-0107

# Test fixture, not a real credential
generic-api-key:tests/fixtures/mock_credentials.json
{% endhighlight %}

Treat this file the way you treat `CODEOWNERS`. Require pull request review to merge changes to it, because every entry is a documented risk acceptance. If someone can silently add a suppression without review, your security gate is theatrical.

## The GitHub Actions Workflow

Create `.github/workflows/trivy.yaml` with the following content. I will walk through the important decisions after the full listing.

{% highlight yaml %}
name: Trivy Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  image-scan:
    name: Container Image Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Build container image
        run: docker build -t ${{ github.repository }}:${{ github.sha }} .

      - name: Cache Trivy database
        uses: actions/cache@v4
        with:
          path: ~/.cache/trivy
          key: trivy-db-${{ runner.os }}-${{ github.run_id }}
          restore-keys: trivy-db-${{ runner.os }}-

      - name: Trivy image scan - SARIF
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: image
          image-ref: ${{ github.repository }}:${{ github.sha }}
          format: sarif
          output: trivy-image.sarif
          severity: HIGH,CRITICAL
          ignore-unfixed: true
          trivyignores: .trivyignore
          trivy-config: trivy.yaml
        env:
          TRIVY_CACHE_DIR: ~/.cache/trivy

      - name: Upload image SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-image.sarif
          category: trivy-image

      - name: Trivy image scan - pipeline gate
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: image
          image-ref: ${{ github.repository }}:${{ github.sha }}
          format: table
          severity: HIGH,CRITICAL
          exit-code: '1'
          ignore-unfixed: true
          trivyignores: .trivyignore
          trivy-config: trivy.yaml
        env:
          TRIVY_CACHE_DIR: ~/.cache/trivy

  iac-scan:
    name: Terraform IaC Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Cache Trivy database
        uses: actions/cache@v4
        with:
          path: ~/.cache/trivy
          key: trivy-db-${{ runner.os }}-${{ github.run_id }}
          restore-keys: trivy-db-${{ runner.os }}-

      - name: Trivy IaC scan - SARIF
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: config
          scan-ref: ./infra
          format: sarif
          output: trivy-iac.sarif
          severity: HIGH,CRITICAL
          trivyignores: .trivyignore
          trivy-config: trivy.yaml
        env:
          TRIVY_CACHE_DIR: ~/.cache/trivy

      - name: Upload IaC SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-iac.sarif
          category: trivy-iac

      - name: Trivy IaC scan - pipeline gate
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: config
          scan-ref: ./infra
          format: table
          severity: HIGH,CRITICAL
          exit-code: '1'
          trivyignores: .trivyignore
          trivy-config: trivy.yaml
        env:
          TRIVY_CACHE_DIR: ~/.cache/trivy
{% endhighlight %}

### The SARIF + Exit Code Split - The Most Important Part

Notice that each scan appears twice: once with `format: sarif` and no `exit-code`, and once with `format: table` and `exit-code: '1'`. This is the key design decision in the whole workflow and it is easy to get wrong.

If you set `exit-code: 1` on the same step that outputs SARIF, the step exits with a non-zero code when findings exist. GitHub Actions marks that step as failed and does not run subsequent steps by default. This means the `upload-sarif` step never runs. The Security tab shows nothing, you have no historical record of what was found, and developers have no way to review findings in the pull request UI - they just see a red build.

By splitting into two steps, the SARIF step always completes and writes its output file, the upload step always runs (protected by `if: always()`), and the gate step is the one that actually fails the build. Developers get both the human-readable table output in the job log and the annotated view in the Security tab.

### Why `if: always()` and Not `if: success()`

The upload step uses `if: always()` instead of the default `if: success()`. This matters because a future change to step ordering or a transient runner error could cause the SARIF step to report a non-zero status. With `if: success()`, that would silently swallow your scan results. With `if: always()`, the upload happens regardless, so you always have findings in the Security tab even when something else in the job goes wrong.

### Trigger Strategy

The workflow triggers on push to `main` and `develop`, on pull requests targeting `main`, and on a nightly schedule at 02:00 UTC. The nightly run catches newly published CVEs that would not have triggered any code change event. Without it, a vulnerability published on Tuesday goes undetected until someone opens a pull request.

Including `pull_request` as a trigger is what makes this a real gate rather than a reporting tool. A developer finds out about a HIGH vulnerability when they open their PR, not after it merges to main.

### Pinning the Action Version

The workflow pins `aquasecurity/trivy-action@0.28.0` rather than using `@master` or `@latest`. This is a supply chain security practice - pinning to a specific tag means a compromised action release does not automatically affect your pipeline. Review the Trivy action changelog when you bump the version.

## Testing and Validation Locally

Before pushing the workflow, validate your configuration locally to avoid a cycle of trial-and-error commits.

Install Trivy on macOS:

{% highlight bash %}
brew install aquasecurity/trivy/trivy
{% endhighlight %}

Scan a container image with the same severity filters you use in CI:

{% highlight bash %}
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 myapp:latest
{% endhighlight %}

Scan your Terraform directory:

{% highlight bash %}
trivy config --severity HIGH,CRITICAL --exit-code 1 ./infra
{% endhighlight %}

Generate a SARIF file and verify it has the expected structure before you let GitHub Actions upload it:

{% highlight bash %}
trivy image --format sarif --output results.sarif --severity HIGH,CRITICAL myapp:latest
jq '.runs[0].results | length' results.sarif
{% endhighlight %}

That `jq` command prints the number of findings. If it returns `0` when you expect results, check that `--ignore-unfixed` is not hiding everything and that your severity filter matches the vulnerabilities in the image.

Verify that `.trivyignore` is actually suppressing what you expect:

{% highlight bash %}
trivy image --ignorefile .trivyignore --severity HIGH,CRITICAL --format json myapp:latest \
  | jq '[.Results[].Vulnerabilities[]? | .VulnerabilityID] | sort | unique'
{% endhighlight %}

Run the same command without `--ignorefile` and compare the output. The CVEs listed in `.trivyignore` should be present in the second list but absent in the first. If a CVE you suppressed still appears, check that the ID is spelled correctly and that the expiry date has not already passed.

## Best Practices and Common Mistakes

There are a handful of mistakes I see repeatedly when teams adopt Trivy in CI.

**Do not use `exit-code: 0` and call it a gate.** An explicit `exit-code: 0` means the step always exits successfully regardless of findings. This is the configuration equivalent of commenting out your tests. If you want informational-only scanning on a branch, remove `exit-code` entirely and document that the branch is not gated.

**Do not skip caching the vulnerability database.** A cold Trivy run downloads roughly 30-60 MB of database content, adding 30-60 seconds to your job. More importantly, if GHCR is experiencing an outage or rate-limiting when your runner starts, the database download fails and Trivy cannot complete the scan. The cache acts as a fallback. Key the cache on `run_id` as shown in the workflow to get a fresh download per run while still benefiting from the restore key fallback on warm caches.

**Use specific version pins, not floating tags.** `@master` and `@latest` float. A breaking change or a security issue in the action publisher's account means your pipeline silently changes behavior. Pin to a version tag and update it intentionally.

**Add expiry dates to every suppression.** Without `exp:YYYY-MM-DD`, a suppressed CVE stays suppressed forever. You suppress a vulnerability because there is no fix today and you have a compensating control. You should revisit that decision when a fix becomes available. Expiry dates force that revisit.

**Run scans on pull requests, not only on push to main.** A gate that only runs after merge to main is not a gate - it is an incident report. Developers need the feedback when they can still act on it, which is during code review.

**Use separate SARIF categories for image and IaC results.** The `category` field in `upload-sarif` namespaces your results in the Security tab. Without separate categories, a second upload overwrites the first. With `category: trivy-image` and `category: trivy-iac`, both appear as distinct alert sources and you can filter by type.

**Treat `.trivyignore` changes as risk acceptances requiring review.** Add it to your `CODEOWNERS` file so that any modification requires approval from a security-aware owner. A suppression file that developers can update without review defeats the purpose of having a gate.

## What You End Up With

After following this setup you have a pipeline that:

- Builds your container image and scans it for HIGH and CRITICAL vulnerabilities with no unfixed results excluded
- Scans your Terraform IaC for misconfigurations at the same severity thresholds
- Uploads both result sets to the GitHub Security tab in SARIF format, visible as inline annotations on pull request diffs
- Fails the build if either scan finds actionable issues
- Runs nightly to catch newly published CVEs between code changes
- Has a single config file (`trivy.yaml`) and a single suppression file (`.trivyignore`) that cover both scan types

The investment to set this up is one workflow file, two config files, and an understanding of the SARIF and exit-code split. The return is that your security posture is checked automatically on every change, findings are visible where developers already work, and you have replaced three separate scanning tools with one.

Happy scripting!
