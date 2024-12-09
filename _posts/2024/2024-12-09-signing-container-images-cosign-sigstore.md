---
title: "Signing container images with Cosign and Sigstore"
author: Victor Silva
date: 2024-12-09T21:41:44+00:00
layout: post
permalink: /signing-container-images-cosign-sigstore/
excerpt: "Pushing an unsigned image to a registry and hoping nobody tampers with it is a supply chain risk most teams accept without realizing it. Cosign, part of the Sigstore project, gives you keyless image signing backed by a public transparency log — no key management, no excuses."
categories:
  - Supply Chain Security
tags:
  - cosign
  - sigstore
  - container-security
  - supply-chain
  - cncf
---

You build an image, push it to a registry, and your deployment pipeline pulls it back down. Between those two events, nothing verifies that what you pushed is what your cluster runs. A compromised registry credential, a misconfigured image tag, or a dependency substitution attack can swap that image for something else entirely — and your pipeline would never know. This is the supply chain gap that image signing closes.

Sigstore is a CNCF incubating project that provides the infrastructure for signing, verifying, and recording software artifacts. Cosign is the CLI tool within Sigstore that handles container images specifically. Together, they let you sign an image at build time and verify that signature at deploy time, with no GPG key ring to manage and no secrets to rotate. The signatures are recorded in Rekor, a public tamper-evident transparency log, which means the entire signing history is auditable by anyone.

This post walks through signing a container image with keyless signing using OIDC, verifying the signature locally, and wiring signature verification into a GitHub Actions pipeline so that only signed images can reach your deployment stage.

## How Sigstore and Cosign Work

Before touching the CLI, it helps to understand what "keyless signing" actually means, because it sounds like a contradiction.

Traditional code signing requires you to generate a key pair, protect the private key forever, distribute the public key to verifiers, and handle key rotation when the private key is compromised or expires. At scale, this becomes its own operational problem and a high-value attack target.

Sigstore's keyless model works differently. When you run `cosign sign` in a CI environment, Cosign requests a short-lived certificate from Fulcio, Sigstore's certificate authority. Fulcio issues this certificate only after verifying your identity through an OIDC token — in GitHub Actions, that token comes from GitHub's OIDC provider and encodes your repository, workflow, and ref. The certificate is valid for ten minutes, just long enough to create the signature. The signing event and certificate are then recorded in Rekor so that anyone can audit when and how the image was signed.

The data flow looks like this:

```
GitHub Actions runner
        |
   cosign sign (OIDC token from GitHub)
        |
   Fulcio CA  ---> issues short-lived certificate
        |
   Signature stored in OCI registry (as a separate artifact)
        |
   Rekor transparency log  ---> records the event
        |
   cosign verify (at deploy time)
        |
   Checks signature against Fulcio certificate + Rekor entry
```

The verifier does not need a pre-shared public key. Instead it checks that the certificate was issued by Fulcio and that the Rekor log entry exists and is consistent. The OIDC claims baked into the certificate — repository name, workflow path, ref — become the identity you verify against. If someone signs a copy of your image from a different repository or workflow, the certificate identity will not match, and verification will fail.

## Prerequisites

To follow along you will need:

- Cosign installed locally — version 2.x is required for the examples in this post
- Docker installed and a registry to push to (Docker Hub, GHCR, or any OCI-compatible registry)
- A GitHub repository with Actions enabled
- For keyless signing locally, a Google, GitHub, or Microsoft account for the OIDC browser flow

Install Cosign on macOS:

{% highlight bash %}
brew install cosign
{% endhighlight %}

On Linux, download the binary directly from the Sigstore releases:

{% highlight bash %}
COSIGN_VERSION=$(curl -s https://api.github.com/repos/sigstore/cosign/releases/latest \
  | grep tag_name | cut -d '"' -f4)
curl -Lo cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64"
chmod +x cosign
sudo mv cosign /usr/local/bin/
{% endhighlight %}

Verify the installation:

{% highlight bash %}
cosign version
{% endhighlight %}

You should see output showing `GitVersion` as a 2.x release. If you see a 1.x version, the keyless signing flow and some verification flags will behave differently — upgrade before continuing.

## Signing an Image Locally

Let us start with a local signing flow so you understand what Cosign does before adding CI to the picture.

Build and push a test image. I will use GHCR throughout this post, substituting `ghcr.io/youruser/demo-app` with your actual image reference:

{% highlight bash %}
docker build -t ghcr.io/youruser/demo-app:v1.0.0 .
docker push ghcr.io/youruser/demo-app:v1.0.0
{% endhighlight %}

Sign it with keyless signing. When you run this locally, Cosign opens a browser window for the OIDC authentication flow:

{% highlight bash %}
cosign sign ghcr.io/youruser/demo-app:v1.0.0
{% endhighlight %}

Cosign will print the transparency log URL for the Rekor entry it just created. Copy that URL — it is useful for auditing. The signature is stored in your registry as a separate OCI artifact, alongside the image. You can see it by listing the image's referrers:

{% highlight bash %}
cosign tree ghcr.io/youruser/demo-app:v1.0.0
{% endhighlight %}

The output shows the image digest, the attached signature, and any other artifacts like SBOMs or attestations that have been attached to it. This is what makes Cosign's approach practical: signatures live in the same registry as the image, so you do not need a separate signature storage service.

## Verifying a Signature

Verification is where the security guarantee actually comes from. When you verify a signature, you are not just checking that one exists — you are asserting that it was created by a specific identity.

For an image signed locally with your GitHub account, the verification command checks the OIDC issuer and the email address embedded in the Fulcio certificate:

{% highlight bash %}
cosign verify \
  --certificate-identity=you@github.com \
  --certificate-oidc-issuer=https://accounts.google.com \
  ghcr.io/youruser/demo-app:v1.0.0 | jq .
{% endhighlight %}

For images signed in GitHub Actions (which we will set up next), the identity is not a personal email — it is the workflow's subject claim. That looks like this:

{% highlight bash %}
cosign verify \
  --certificate-identity-regexp="https://github.com/youruser/demo-app/.github/workflows/.*" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/youruser/demo-app:v1.0.0 | jq .
{% endhighlight %}

The `--certificate-identity-regexp` flag lets you match against the `sub` claim from the OIDC token, which encodes the workflow file path. This means you can verify that the image was signed specifically by your `release.yaml` workflow, not just by any workflow in the repository.

If verification succeeds, Cosign prints the verified payload as JSON and exits with code 0. If the signature is missing, tampered with, or the certificate identity does not match, it exits with a non-zero code and prints an error. This exit code behavior is what makes it reliable as a pipeline gate.

## Signing in GitHub Actions

This is where keyless signing becomes genuinely low-friction. GitHub Actions provides an OIDC token to every workflow step automatically — no secrets, no key generation. You just need to tell Cosign to use it.

Create `.github/workflows/build-sign.yaml`:

{% highlight yaml %}
name: Build and Sign

on:
  push:
    branches: [main]
  release:
    types: [published]

permissions:
  contents: read
  packages: write
  id-token: write  # required for keyless signing via OIDC

jobs:
  build-sign:
    name: Build, Push, and Sign
    runs-on: ubuntu-latest
    env:
      IMAGE: ghcr.io/${{ github.repository }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

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
          tags: |
            ${{ env.IMAGE }}:${{ github.sha }}
            ${{ env.IMAGE }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image with keyless signing
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign sign --yes \
            ${{ env.IMAGE }}@${{ steps.build-push.outputs.digest }}
{% endhighlight %}

A few decisions in this workflow are worth calling out.

**Sign by digest, not by tag.** The `build-push` step outputs the image digest (a `sha256:...` string). Signing `IMAGE@digest` is more secure than signing `IMAGE:tag` because a tag is mutable — someone could push a different image to the same tag after you sign it, and the signature would no longer correspond to what is actually running. A digest is immutable. When you sign a digest, the signature is cryptographically bound to exactly those bytes.

**`id-token: write` is required.** Without this permission, GitHub does not include the OIDC token in the workflow environment. Cosign will try the OIDC flow, fail to get a token, and exit with an error. This is the most common mistake when setting up keyless signing for the first time.

**`--yes` skips the interactive confirmation.** In non-interactive CI environments, Cosign would block waiting for user input to confirm the transparency log upload. The `--yes` flag accepts it automatically.

## Verifying in a Deployment Pipeline

Signing is only useful if you verify before deploying. Add a verification job to any pipeline that pulls the image before running it:

{% highlight yaml %}
  verify-and-deploy:
    name: Verify and Deploy
    runs-on: ubuntu-latest
    needs: build-sign
    environment: production

    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify image signature
        run: |
          cosign verify \
            --certificate-identity-regexp="https://github.com/${{ github.repository }}/.github/workflows/build-sign.yaml@refs/heads/main" \
            --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
            ghcr.io/${{ github.repository }}@${{ needs.build-sign.outputs.digest }} | jq .

      - name: Deploy
        run: |
          echo "Signature verified. Proceeding with deployment."
          # your deployment commands here
{% endhighlight %}

The `--certificate-identity-regexp` value matches the exact workflow file and ref that produced the signature. An image signed by a different workflow, a different ref, or a fork of the repository will fail this check. That specificity is the point: it prevents a compromised fork or an unreviewed workflow from producing deployable images.

## The Rekor Transparency Log

Every keyless signing event is recorded in Rekor, the public transparency log operated by Sigstore. You can look up any signing event by the image digest:

{% highlight bash %}
rekor-cli search --artifact ghcr.io/youruser/demo-app@sha256:abcdef...
{% endhighlight %}

Or install `rekor-cli` and query by the SHA256 hash of the artifact directly. The log entry shows the signing timestamp, the Fulcio certificate, and the certificate's OIDC claims. This is what makes the system auditable: even if you lose access to your registry or your GitHub account, the Rekor log is a permanent record of when and how every signing event happened.

This transparency property has a privacy implication worth noting. Because Rekor is public, signing an image records the repository name, workflow path, and signing timestamp publicly. For open-source projects this is a feature. For private repositories with sensitive naming conventions, consider whether that exposure is acceptable before adopting keyless signing.

## Testing and Validation

Before wiring this into a production pipeline, validate the whole flow end to end in a test repository.

After running the build-sign workflow, confirm the signature is attached to the image:

{% highlight bash %}
cosign tree ghcr.io/youruser/demo-app:${{ github.sha }}
{% endhighlight %}

Run the full verification command from a machine that has never seen the image before to confirm it works without any local state:

{% highlight bash %}
cosign verify \
  --certificate-identity-regexp="https://github.com/youruser/demo-app/.github/workflows/build-sign.yaml@refs/heads/main" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/youruser/demo-app:latest | jq '.[] | {subject: .optional.Subject, issuer: .optional.Issuer}'
{% endhighlight %}

That `jq` filter extracts the subject and issuer from the verified payload, making it easy to confirm the identity claims match what you expect.

To test that verification correctly rejects unsigned images, pull a different image (one you have not signed) and run the same verification command. Cosign should exit with a non-zero code and print a message like `no matching signatures`:

{% highlight bash %}
cosign verify \
  --certificate-identity-regexp="https://github.com/youruser/demo-app/.*" \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ubuntu:24.04
# Expected: Error: no matching signatures
{% endhighlight %}

This negative test is as important as the positive one. If your gate silently passes unsigned images due to a misconfigured flag, you have no supply chain control — just the appearance of one.

## Best Practices

**Always sign by digest.** Tags are mutable and can be overwritten after signing. Signing by digest (`IMAGE@sha256:...`) binds the signature to the exact bytes that were verified. Use the digest output from your build step, not the tag.

**Pin `cosign-installer` to a specific version.** Using `sigstore/cosign-installer@v3` will follow the latest v3 minor release. For production pipelines, pin to a specific SHA or version tag to protect against supply chain risk in the installer itself.

**Check the `id-token: write` permission early.** This is the first thing to verify when keyless signing fails in CI. It must be set at the job level or the workflow level — inheriting it from a caller workflow is not always reliable in reusable workflow setups.

**Use `--certificate-identity` over `--certificate-identity-regexp` for exact matches.** If you know the exact workflow subject claim, prefer an exact match over a regexp. Regexps introduce the risk of accidentally matching a workflow you did not intend to trust. Reserve the regexp flag for cases where multiple workflow files legitimately produce signed images.

**Integrate verification in admission control, not just pipelines.** Pipeline verification stops a bad image from reaching a deployment job. Admission control — using a tool like Kyverno or OPA Gatekeeper with a Cosign policy — stops a bad image from being scheduled in the cluster even if someone bypasses the pipeline. Both layers together give you defense in depth.

**Treat Rekor entries as evidence, not secrets.** The Rekor log is public and immutable. Do not include sensitive data in artifact names or paths that will appear in signing events. Conversely, do use the Rekor log proactively during incident response — it tells you exactly when and from which workflow an image was signed.

## Conclusion

Signing container images is one of the few supply chain controls that is simultaneously meaningful and low overhead. With Cosign's keyless signing model, there is no key management burden, no secrets to rotate, and no additional infrastructure to run. You get cryptographic proof that every image in your registry was produced by a specific, audited workflow, and you get a public transparency log that records every signing event permanently.

The setup in this post — keyless signing in GitHub Actions, verification by workflow identity, and a deployment gate that checks the signature before proceeding — closes the gap between "we built a clean image" and "we are running the image we built". From here, the natural next step is pushing that verification down into the cluster with a Kyverno policy that enforces signatures at admission time, so the control holds even when someone tries to run an image directly with `kubectl`.

Happy scripting!
