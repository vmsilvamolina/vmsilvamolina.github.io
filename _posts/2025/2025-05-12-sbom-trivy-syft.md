---
title: "Generating and validating SBOMs with Trivy and Syft"
author: Victor Silva
date: 2025-05-12T23:05:40+00:00
layout: post
permalink: /sbom-trivy-syft/
excerpt: "After a supply chain attack you find out what was actually inside your container images — too late. SBOMs change that. This post shows how to generate SBOMs from container images with both Trivy and Syft, compare the two formats, query the results, and automate generation in a GitHub Actions pipeline."
categories:
  - Supply Chain Security
tags:
  - sbom
  - trivy
  - syft
  - supply-chain
  - cncf
---

You ship a container image. Inside it is an OS base layer, a runtime, a handful of language packages, and whatever the base image author decided to include last week. If that image ends up in an incident — a supply chain compromise, a CVE disclosure, an audit — the first question you will be asked is: what is in it? If the honest answer is "we would have to rebuild the image and run a scanner to find out", you have a gap that SBOMs are designed to close.

A Software Bill of Materials is a machine-readable inventory of every component in a software artifact: packages, libraries, versions, licenses, and their relationships. Think of it as a manifest file that travels with the artifact, produced at build time when the contents are known exactly. In 2021, the U.S. executive order on improving cybersecurity (EO 14028) made SBOM generation a requirement for software sold to federal agencies. Since then, SBOMs have moved from compliance checkbox to operational practice in security-conscious engineering teams. The Log4Shell and XZ Utils incidents are frequently cited examples of why knowing your dependency tree matters before an advisory drops, not after.

This post covers the two most widely used SBOM formats, how to generate SBOMs from a container image with both Syft and Trivy, how to query and validate what you produced, and how to add SBOM generation to a GitHub Actions pipeline so every image build produces an auditable inventory automatically.

## SBOM Formats: SPDX and CycloneDX

Two formats dominate the ecosystem and it is worth understanding the difference before you generate anything.

**SPDX** (Software Package Data Exchange) is the older of the two, originally developed by the Linux Foundation and now an ISO standard (ISO/IEC 5962:2021). It was designed primarily for license compliance and is deeply integrated into the open-source legal toolchain. SPDX files can describe relationships between packages, files, and snippets, and the format is verbose enough to satisfy detailed legal requirements. If your SBOM consumers are legal or procurement teams, SPDX is the format they expect.

**CycloneDX** is an OWASP project designed explicitly for security use cases. It is more compact, more focused on vulnerability context, and has richer support for linking components to known vulnerabilities. If your SBOM consumers are security scanners, vulnerability management platforms, or CI gates, CycloneDX is typically the better fit. Tools like Grype, Dependency-Track, and Trivy itself consume CycloneDX natively.

Both formats are widely supported. In practice, most teams generate CycloneDX for security workflows and SPDX when they need to satisfy compliance requirements. Syft and Trivy can produce both, so you do not have to choose one tool per format.

## Prerequisites

You will need the following tools installed. Each command verifies the installation:

Install Syft (Anchore's SBOM generator):

{% highlight bash %}
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
syft version
{% endhighlight %}

Install Trivy (CNCF project, from Aqua Security):

{% highlight bash %}
brew install aquasecurity/trivy/trivy
trivy version
{% endhighlight %}

On Linux, install Trivy via the official script:

{% highlight bash %}
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
trivy version
{% endhighlight %}

You will also need Docker to build or pull the images you want to scan, and `jq` for querying JSON output:

{% highlight bash %}
docker --version
jq --version
{% endhighlight %}

Throughout this post I will use `nginx:1.25` as the target image. It is a real image with a realistic package set and available on Docker Hub without authentication.

## Generating an SBOM with Syft

Syft is a dedicated SBOM generator from Anchore. It is fast, supports a wide range of package ecosystems, and produces clean output in multiple formats. Start by generating a CycloneDX JSON SBOM directly from the image without pulling it first — Syft handles the pull:

{% highlight bash %}
syft nginx:1.25 -o cyclonedx-json=nginx-sbom.cdx.json
{% endhighlight %}

Syft pulls the image layers, enumerates all package databases (dpkg, rpm, apk, language package manifests), and writes the inventory to `nginx-sbom.cdx.json`. On a standard nginx image this runs in a few seconds and produces a file with several hundred components.

Generate the same inventory in SPDX JSON format:

{% highlight bash %}
syft nginx:1.25 -o spdx-json=nginx-sbom.spdx.json
{% endhighlight %}

You can also generate both in a single run by repeating the `-o` flag:

{% highlight bash %}
syft nginx:1.25 \
  -o cyclonedx-json=nginx-sbom.cdx.json \
  -o spdx-json=nginx-sbom.spdx.json
{% endhighlight %}

To see what Syft found without writing files, pipe to table output in the terminal:

{% highlight bash %}
syft nginx:1.25 -o table
{% endhighlight %}

This prints a human-readable table of package names, versions, and types — useful for a quick audit without needing `jq`.

## Generating an SBOM with Trivy

Trivy is a CNCF project that combines vulnerability scanning, IaC misconfiguration detection, secret scanning, and SBOM generation in a single binary. This makes it particularly convenient in CI environments where you want to scan and document in the same step.

Generate a CycloneDX SBOM from the same image:

{% highlight bash %}
trivy image --format cyclonedx --output nginx-trivy.cdx.json nginx:1.25
{% endhighlight %}

Generate an SPDX SBOM:

{% highlight bash %}
trivy image --format spdx-json --output nginx-trivy.spdx.json nginx:1.25
{% endhighlight %}

Trivy also supports generating an SBOM from a filesystem directory rather than an image, which is useful if you want to produce an SBOM for an application repository before it is containerized:

{% highlight bash %}
trivy fs --format cyclonedx --output app-sbom.cdx.json ./
{% endhighlight %}

## Comparing the Two Outputs

Syft and Trivy take different approaches to SBOM generation and the outputs reflect that.

Check the component counts from both tools:

{% highlight bash %}
jq '.components | length' nginx-sbom.cdx.json
jq '.components | length' nginx-trivy.cdx.json
{% endhighlight %}

You will typically see a small difference. Trivy applies its vulnerability database context during scanning, which can affect how it classifies and deduplicates packages. Syft focuses purely on enumeration without the vulnerability context, which sometimes surfaces packages that Trivy filters. Neither count is definitively correct — they reflect different enumeration strategies.

List all package names from the Syft output:

{% highlight bash %}
jq -r '.components[].name' nginx-sbom.cdx.json | sort
{% endhighlight %}

Find components present in Syft's output but missing from Trivy's:

{% highlight bash %}
comm -23 \
  <(jq -r '.components[].name' nginx-sbom.cdx.json | sort) \
  <(jq -r '.components[].name' nginx-trivy.cdx.json | sort)
{% endhighlight %}

For most container images the overlap is high. The differences are edge cases worth reviewing, but they should not lead you to distrust either tool — both are production-grade generators used widely in the industry.

## Querying and Validating an SBOM

An SBOM you cannot query is just a file on disk. Let us extract useful information from the CycloneDX output.

List all components with their versions:

{% highlight bash %}
jq -r '.components[] | "\(.name) \(.version)"' nginx-sbom.cdx.json | sort
{% endhighlight %}

Find all components that match a specific package name — useful when you need to quickly check whether a vulnerable library is present:

{% highlight bash %}
jq '.components[] | select(.name | test("openssl"; "i"))' nginx-sbom.cdx.json
{% endhighlight %}

Extract all unique license identifiers from the SBOM to feed into a license compliance check:

{% highlight bash %}
jq -r '[.components[].licenses[]?.license.id // empty] | unique[]' nginx-sbom.cdx.json
{% endhighlight %}

Check the SBOM metadata — the tool that generated it, the target image, and the generation timestamp:

{% highlight bash %}
jq '.metadata | {timestamp, component: .component.name, tools: [.tools[]?.name]}' nginx-sbom.cdx.json
{% endhighlight %}

This metadata block is what makes an SBOM useful for audit purposes: it records not just what was found but when and by which tool.

You can also feed a Syft-generated SBOM directly into Grype (Anchore's vulnerability scanner) for vulnerability matching without re-pulling the image:

{% highlight bash %}
grype sbom:nginx-sbom.cdx.json
{% endhighlight %}

This is a useful pattern for decoupling SBOM generation from vulnerability analysis. Generate once, scan multiple times with different tools, store the SBOM as an artifact alongside the image.

## Integrating into GitHub Actions

This is where the workflow becomes durable. The goal is to generate an SBOM as part of every image build, attach it to the image in the registry as an OCI artifact, and upload it as a pipeline artifact so it is available for later inspection.

Create `.github/workflows/sbom.yaml`:

{% highlight yaml %}
name: Build and Generate SBOM

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  build-and-sbom:
    name: Build, Push, and Generate SBOM
    runs-on: ubuntu-latest
    env:
      IMAGE: ghcr.io/${{ github.repository }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        id: build-push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }}

      - name: Generate SBOM with Trivy
        uses: aquasecurity/trivy-action@0.28.0
        with:
          scan-type: image
          image-ref: ${{ env.IMAGE }}:${{ github.sha }}
          format: cyclonedx
          output: sbom.cdx.json
        env:
          TRIVY_USERNAME: ${{ github.actor }}
          TRIVY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload SBOM as pipeline artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom-${{ github.sha }}
          path: sbom.cdx.json
          retention-days: 90

      - name: Install Syft and generate SPDX SBOM
        run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
            | sh -s -- -b /usr/local/bin
          syft ${{ env.IMAGE }}:${{ github.sha }} \
            -o spdx-json=sbom.spdx.json

      - name: Upload SPDX SBOM as pipeline artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom-spdx-${{ github.sha }}
          path: sbom.spdx.json
          retention-days: 90

      - name: Print component count
        run: |
          echo "CycloneDX components: $(jq '.components | length' sbom.cdx.json)"
          echo "SPDX packages: $(jq '.packages | length' sbom.spdx.json)"
{% endhighlight %}

A few things to call out in this workflow.

**Generate from the pushed image, not the local build context.** The SBOM is generated from `IMAGE:SHA` after it has been pushed to the registry. This means the SBOM reflects exactly what is in the registry, including any layer transforms that happened during the push. Generating from a local image reference and pushing the SBOM separately introduces a subtle gap: the SBOM could describe an image digest that differs from what is in the registry.

**Retain SBOMs for 90 days.** Pipeline artifacts are ephemeral by default. Setting a 90-day retention gives you a window to retrieve the SBOM for audit, incident response, or feeding into a vulnerability management platform. Adjust this value based on your retention policy.

**Produce both formats.** CycloneDX for security tooling downstream, SPDX for compliance workflows. The cost of generating both is negligible and having both formats available means you do not have to re-run a scan when a new consumer needs a different format.

## Best Practices

**Generate SBOMs at build time, not on demand.** An SBOM generated six months after the fact from a rebuilt image is not the same as one generated from the original build. Base images change, package databases change, and the rebuilt image may not match the original byte for byte. Treat the SBOM as a build artifact — it is produced once alongside the image and stored with it.

**Attach SBOMs to the image in your registry.** Storing the SBOM as an OCI artifact using `cosign attach sbom` or `oras push` keeps the SBOM co-located with the image it describes. When the image is pulled for deployment, the SBOM travels with it and is retrievable by digest. Pipeline artifacts expire; registry artifacts are as durable as your registry retention policy.

**Use the image digest as the SBOM identifier.** Tags are mutable. An SBOM that references an image by tag can become ambiguous if the tag is reused. Reference the image by its `sha256:` digest in the SBOM metadata and in any downstream systems that consume it.

**Feed SBOMs into a vulnerability management platform.** Tools like Dependency-Track accept CycloneDX SBOMs and provide continuous vulnerability tracking against a live CVE feed. This means a CVE published today can be matched against SBOMs generated three months ago, without re-scanning any image. The SBOM becomes an ongoing asset, not a point-in-time scan result.

**Validate SBOM completeness after generation.** A component count of zero is not always an error — Trivy will happily produce an empty SBOM from a scratch image. Add a validation step that asserts the component count is above a reasonable threshold for your image type. A single `jq` assertion in the pipeline catches misconfigurations before they silently produce useless SBOMs.

{% highlight bash %}
COUNT=$(jq '.components | length' sbom.cdx.json)
if [ "$COUNT" -lt 5 ]; then
  echo "SBOM validation failed: only $COUNT components found, expected more"
  exit 1
fi
echo "SBOM validation passed: $COUNT components"
{% endhighlight %}

## What You End Up With

After following this setup you have a pipeline that generates both CycloneDX and SPDX SBOMs for every container image build, stores them as pipeline artifacts with 90-day retention, and validates that the SBOM is non-trivial before proceeding. You also have the CLI commands to query an SBOM for specific packages, compare outputs between tools, and feed an SBOM into downstream vulnerability scanning without re-pulling the image.

The broader value is auditability. When someone asks what was in a specific image at a specific point in time, the answer is a file you can retrieve and query — not a scan you have to rerun against a potentially different artifact. That shift from reactive to proactive is what supply chain security practice looks like in operation.

Happy scripting!
