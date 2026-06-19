---
title: 'Signing OCIR Images with Cosign and Kyverno verifyImages'
author: Victor Silva
date: 2026-06-19T07:08:24+00:00
layout: post
permalink: /cosign-ocir-kyverno-verifyimages/
excerpt: "Sign OCIR images by digest with Cosign and enforce at admission using Kyverno verifyImages on OKE, with OCI Vault Secrets managing the key passphrase."
categories:
  - OCI
  - Security
tags:
  - cosign
  - kyverno
  - ocir
  - oke
  - supply-chain-security
  - image-signing
  - devsecops
  - sigstore
  - kyverno-verifyimages
  - container-signing
---

When Log4Shell dropped, the rush to patch images produced a different problem: how do you know the replacement image in your registry was actually built by your pipeline and not substituted by something else in the chaos? Vulnerability scanning with [OCI VSS](/oci-vulnerability-scanning-terraform/) tells you whether an image has known CVEs. Admission control with [Kyverno](/kyverno-oke-admission-policies/) tells you whether an image comes from OCIR. But neither of those controls answers the question: who produced this exact image artifact, and was it built from the code you expect?

That gap is the software supply chain problem. The CNCF has consolidated around Cosign as the standard tool for image signing, and Kyverno's `verifyImages` rule is the admission-side enforcement mechanism. Together they close the loop: scan → sign → enforce.

This post is the third in the OCI security series, and it completes the supply chain picture. You will sign images by digest using a local ECDSA key pair, store the passphrase securely in OCI Vault Secrets, push signatures as OCI artifacts to OCIR, and configure a `ClusterPolicy` in Kyverno that blocks any image from your tenancy that does not carry a valid signature. The keyless Sigstore Fulcio flow is not covered here — it requires a public Rekor transparency log and publishes your image digests publicly, which is not suitable for private enterprise workloads. The key-based approach owns the full trust chain.

## How It Works: Cosign and OCIR Architecture

Understanding the mechanics before executing commands is worth the two minutes it takes. There are three actors: Cosign, OCIR, and Kyverno.

**Cosign** generates an ECDSA P-256 key pair (`cosign.key` / `cosign.pub`) and uses the private key to sign an image's content-addressable digest. The signature is stored not on the image itself but as a separate OCI artifact in the same registry. The artifact's tag follows the convention `sha256-<digest>.sig`. If the image digest is `sha256:abc123...`, the signature lives at `<registry>/<repo>:sha256-abc123....sig`.

**OCIR** stores both artifacts — the image and its detached signature — as standard OCI Distribution v2 objects. No special OCIR configuration is needed; signatures are just another tag in the repository. The `cosign tree` command lets you visualize the relationship between an image digest and its attached signature artifacts.

**Kyverno** intercepts Pod admission, inspects the image reference, fetches the `.sig` artifact from OCIR, and verifies the signature against the public key embedded in the `ClusterPolicy`. If verification fails — wrong key, missing signature, tampered digest — the Pod is denied. The `mutateDigest: true` option (the default) rewrites the image reference to the digest format in the admitted Pod's spec, making the running container pinned to an immutable artifact.

The architecture looks like this:

{% highlight text %}
  Build Pipeline
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │  docker build → docker push                                     │
  │       │                                                         │
  │       ▼                                                         │
  │  DIGEST=$(docker inspect --format RepoDigests)                  │
  │       │                                                         │
  │       ▼                                                         │
  │  cosign sign --key cosign.key --tlog-upload=false               │
  │       │                                                         │
  └───────┼─────────────────────────────────────────────────────────┘
          │ push image + push .sig OCI artifact
          ▼
  OCIR (syd.ocir.io/<tenancy-ns>/myapp)
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │  myapp@sha256:abc123...  (the image)                            │
  │  myapp:sha256-abc123....sig  (the signature artifact)           │
  │                                                                 │
  └───────────────────────────────────────────────┬─────────────────┘
                                                  │
          kubectl apply (Pod)                     │
                │                                 │
                ▼                                 ▼
  kube-apiserver → Kyverno Admission Webhook
  ┌─────────────────────────────────────────────────────────────────┐
  │                                                                 │
  │  ClusterPolicy: verify-signed-images-ocir                       │
  │                                                                 │
  │  1. Fetch .sig artifact from OCIR                               │
  │  2. Verify against cosign.pub in policy                         │
  │  3. failureAction: Enforce → deny if invalid                    │
  │  4. mutateDigest: true → rewrite tag ref to digest ref          │
  │                                                                 │
  └─────────────────────────────────────────────────────────────────┘
{% endhighlight %}

One detail to internalize before touching a command: always sign by digest, not by tag. Tags are mutable — `v1.0.0` can be pushed over. Digests are content-addressable and immutable. Signing a tag gives you a signature that covers whatever that tag pointed to at signing time, not necessarily what it points to when the Pod is admitted. `cosign sign` with a digest reference eliminates that ambiguity.

## Prerequisites

You need:

- OKE cluster with Kyverno v1.11+ installed (see [Kyverno on OKE](/kyverno-oke-admission-policies/) for the setup)
- `cosign` v2.x installed locally
- `docker` with access to your OCIR tenancy
- OCI CLI configured and authenticated
- An OCI Vault (DEFAULT type) and at least one encryption key in it
- `kubectl` pointing at your OKE cluster
- Terraform >= 1.5 with the OCI provider if using the IaC section

Verify Cosign and your OKE connection:

{% highlight bash %}
cosign version
kubectl get nodes
kubectl get pods -n kyverno
{% endhighlight %}

Cosign v2 changed several flag names from v1. The commands in this post are written for v2. The most important change: `--key` now takes `cosign.key` directly; there is no longer a separate `--output-signature` flag for local workflows.

## Step 1: Generate the Key Pair and Store the Passphrase in OCI Vault

Generate the ECDSA P-256 key pair. Cosign will prompt for a passphrase to encrypt the private key at rest. Use a strong random passphrase — it is going straight into OCI Vault Secrets in the next step.

{% highlight bash %}
cosign generate-key-pair
{% endhighlight %}

This produces two files in the current directory:

- `cosign.key` — the encrypted private key (PEM format, passphrase-protected)
- `cosign.pub` — the public key (unencrypted PEM format)

Commit `cosign.pub` to your repository or secret manager. Never commit `cosign.key` — it goes into secure storage only.

Store the passphrase in OCI Vault Secrets. First, get the Vault OCID and a key OCID:

{% highlight bash %}
export VAULT_OCID=ocid1.vault.oc1.ap-sydney-1.aaaa...
export KEY_OCID=ocid1.key.oc1.ap-sydney-1.aaaa...
export COMPARTMENT_OCID=ocid1.compartment.oc1..aaaa...
export PASSPHRASE="your-strong-passphrase-here"

oci vault secret create-base64 \
  --compartment-id $COMPARTMENT_OCID \
  --vault-id $VAULT_OCID \
  --key-id $KEY_OCID \
  --secret-name "cosign-key-passphrase" \
  --secret-content-content "$(echo -n $PASSPHRASE | base64)"
{% endhighlight %}

Save the secret OCID returned in the output — your pipeline will use it to retrieve the passphrase at signing time.

Note on OCI Vault and Cosign KMS integration: at the time of writing, there is no native `ocikms://` provider for Cosign that would allow using OCI Vault as the signing backend directly. The practical approach for OCI — and the one used in production by most OKE customers — is the local key file with the passphrase in Vault Secrets. Your CI/CD pipeline retrieves the passphrase via OCI CLI before calling `cosign sign`, and the private key file is either mounted from a secure pipeline secret or retrieved from an encrypted artifact store.

To retrieve the passphrase in a pipeline step:

{% highlight bash %}
SECRET_OCID=ocid1.vaultsecret.oc1.ap-sydney-1.aaaa...

COSIGN_PASSWORD=$(oci secrets secret-bundle get \
  --secret-id $SECRET_OCID \
  --query 'data."secret-bundle-content".content' \
  --raw-output | base64 --decode)

export COSIGN_PASSWORD
{% endhighlight %}

Cosign reads the passphrase from the `COSIGN_PASSWORD` environment variable when decrypting `cosign.key`. No interactive prompt in automated pipelines.

## Step 2: Set Up the OCIR Repository and Push the Image

If you are managing OCIR repositories with Terraform, the `oci_artifacts_container_repository` resource creates the repository with the correct settings. A private repository is the default for production workloads — never use public repositories for internally-built application images.

For federated users (the common case when using OCI Identity with federation to an identity provider), the OCIR login username format is:

{% highlight bash %}
docker login syd.ocir.io \
  --username '<tenancy-namespace>/oracleidentitycloudservice/<user@domain.com>' \
  --password '<auth-token>'
{% endhighlight %}

The auth token is generated from the OCI console: Profile → Auth Tokens → Generate Token. It is not your password. For local IAM users (non-federated), the format is `<tenancy-namespace>/<username>` without the `oracleidentitycloudservice/` path.

Build and push your image:

{% highlight bash %}
TENANCY_NS="your-tenancy-namespace"
REGION_KEY="syd"  # ap-sydney-1

docker build -t ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:v1.0.0 .
docker push ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:v1.0.0
{% endhighlight %}

## Step 3: Sign the Image by Digest

After the push, get the image's content-addressable digest. Never use the tag as the signing target.

{% highlight bash %}
TENANCY_NS="your-tenancy-namespace"
REGION_KEY="syd"

DIGEST=$(docker inspect \
  --format='{{index .RepoDigests 0}}' \
  ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:v1.0.0 | cut -d@ -f2)

echo "Signing digest: $DIGEST"
{% endhighlight %}

Now sign. The `--tlog-upload=false` flag is critical for private workloads — without it, Cosign uploads the image digest to the public Sigstore Rekor transparency log, which exposes your internal image references to the internet.

{% highlight bash %}
cosign sign \
  --key cosign.key \
  --tlog-upload=false \
  --yes \
  "${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp@${DIGEST}"
{% endhighlight %}

Cosign will prompt for the private key passphrase (or read it from `COSIGN_PASSWORD` if set). After signing, it pushes the signature as an OCI artifact to OCIR with the tag format `sha256-<digest>.sig`. The repository in OCIR now contains two artifacts: the image itself and its detached signature.

Verify what Cosign stored in OCIR:

{% highlight bash %}
cosign tree ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp@${DIGEST}
{% endhighlight %}

The output will show the image digest and the attached signature artifact underneath it. If you only see the image with no signature, check that the OCIR login credentials have push access to the repository.

## Step 4: Verify the Signature Locally

Before configuring Kyverno, confirm the signature is valid using the public key. The `--insecure-ignore-tlog=true` flag tells Cosign not to expect a Rekor entry — consistent with signing with `--tlog-upload=false`.

{% highlight bash %}
cosign verify \
  --key cosign.pub \
  --insecure-ignore-tlog=true \
  "${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp@${DIGEST}"
{% endhighlight %}

A successful verification produces JSON output describing the signature payload, including the signing time and the image digest. If you get a `FAIL` or an error about a missing Rekor entry, the most common causes are a mismatched key pair (used a different public key than the one that corresponds to the signing private key) or the `--tlog-upload=false` flag was omitted during signing while `--insecure-ignore-tlog=true` was added during verification inconsistently.

## Step 5: Configure the Kyverno verifyImages ClusterPolicy

This is where admission enforcement is wired. The `verifyImages` rule type is distinct from `validate` — Kyverno fetches the signature artifact from the registry and verifies it cryptographically, then either admits or denies the Pod.

Retrieve your public key content:

{% highlight bash %}
cat cosign.pub
{% endhighlight %}

Create the `ClusterPolicy` manifest. Replace `<tenancy-ns>` with your actual tenancy namespace and paste the full content of `cosign.pub` into the `publicKeys` field:

{% highlight yaml %}
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-signed-images-ocir
  annotations:
    policies.kyverno.io/title: Verify OCIR Image Signatures
    policies.kyverno.io/category: Supply Chain Security
    policies.kyverno.io/severity: high
spec:
  webhookConfiguration:
    failurePolicy: Fail
    timeoutSeconds: 30
  background: false
  rules:
    - name: check-image-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "syd.ocir.io/<tenancy-ns>/*"
            - "*.ocir.io/<tenancy-ns>/*"
          type: Cosign
          failureAction: Enforce
          mutateDigest: true
          verifyDigest: true
          required: true
          attestors:
            - count: 1
              entries:
                - keys:
                    publicKeys: |-
                      -----BEGIN PUBLIC KEY-----
                      <cosign.pub contents>
                      -----END PUBLIC KEY-----
                    signatureAlgorithm: sha256
                    rekor:
                      ignoreTlog: true
                    ctlog:
                      ignoreSCT: true
{% endhighlight %}

Apply the policy:

{% highlight bash %}
kubectl apply -f verify-signed-images-ocir.yaml
{% endhighlight %}

Three settings in this policy deserve explicit attention.

`failurePolicy: Fail` on the webhook means that if Kyverno itself is unavailable when a Pod is submitted, the admission request is rejected rather than allowed through. This is the correct setting for a security control. `Ignore` would mean a Kyverno outage silently disables image verification for the duration — never use `Ignore` on security-critical policies.

`rekor.ignoreTlog: true` and `ctlog.ignoreSCT: true` are required when you signed with `--tlog-upload=false`. Kyverno v1.11+ supports these fields. Without them, Kyverno expects a Rekor entry and a Signed Certificate Timestamp from Fulcio's CT log, both of which do not exist in the key-based local signing flow.

`mutateDigest: true` rewrites the image reference in the admitted Pod spec from a tag reference (`myapp:v1.0.0`) to a digest reference (`myapp@sha256:abc123...`). This makes the running container pinned to the exact artifact that was verified — the tag can move, but the digest is permanent. This is enforced at runtime, not just at policy evaluation time.

`background: false` is intentional for `verifyImages` rules. The background controller operates on existing resources and cannot perform signature verification (it cannot authenticate to OCIR on behalf of arbitrary workloads). Setting it to `false` restricts evaluation to the admission path where it belongs.

## Step 6: Configure the Kyverno imagePullSecret for Private OCIR

Kyverno's admission controller needs to pull the signature artifact from OCIR during verification. For private repositories this requires credentials — the same credentials your nodes use to pull the image itself. Without them, Kyverno cannot fetch the `.sig` artifact and verification fails with an authentication error, which then blocks the Pod even if the image is correctly signed.

Create an `imagePullSecret` in the `kyverno` namespace:

{% highlight bash %}
kubectl create secret docker-registry ocirsecret \
  --docker-server=syd.ocir.io \
  --docker-username='<tenancy-ns>/oracleidentitycloudservice/<user@domain.com>' \
  --docker-password='<auth-token>' \
  -n kyverno
{% endhighlight %}

Then patch the Kyverno admission controller Deployment to use it:

{% highlight bash %}
kubectl patch deployment kyverno \
  -n kyverno \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--imagePullSecrets=ocirsecret"}]'
{% endhighlight %}

Wait for the rollout to complete:

{% highlight bash %}
kubectl rollout status deployment/kyverno -n kyverno
{% endhighlight %}

If you installed Kyverno via Helm, the cleaner approach is to set `existingImagePullSecrets` in the Helm values rather than patching the Deployment directly. This survives Helm upgrades:

{% highlight bash %}
helm upgrade kyverno kyverno/kyverno \
  -n kyverno \
  --reuse-values \
  --set "existingImagePullSecrets[0]=ocirsecret"
{% endhighlight %}

## Testing and Validation

### Blocked: Unsigned Image

Push an image without signing it, then try to run it:

{% highlight bash %}
docker tag ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:v1.0.0 \
           ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:unsigned
docker push ${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:unsigned

kubectl run test-unsigned \
  --image="${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp:unsigned"
{% endhighlight %}

Expected output:

```
Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
resource Pod/default/test-unsigned was blocked due to the following policies

verify-signed-images-ocir:
  check-image-signature: image verification failed for syd.ocir.io/<tenancy-ns>/myapp:unsigned;
  .attestors[0].entries[0].keys: no signatures found
```

### Admitted: Signed Image by Digest

{% highlight bash %}
kubectl run test-signed \
  --image="${REGION_KEY}.ocir.io/${TENANCY_NS}/myapp@${DIGEST}"
{% endhighlight %}

The Pod is admitted. Verify that `mutateDigest: true` pinned the image reference to the digest:

{% highlight bash %}
kubectl get pod test-signed \
  -o jsonpath='{.spec.containers[0].image}'
{% endhighlight %}

The output should show the digest form `syd.ocir.io/<tenancy-ns>/myapp@sha256:abc123...` regardless of whether you submitted a tag or a digest reference. Kyverno rewrote it.

### Policy Reports

{% highlight bash %}
# Namespace-scoped reports
kubectl get policyreport -A

# Filter for failures
kubectl get polr -n default -o yaml | grep -A5 "result: fail"
{% endhighlight %}

### Kyverno Admission Controller Logs

If a signature verification produces an unexpected result, the admission controller logs are the first place to look:

{% highlight bash %}
kubectl logs -n kyverno \
  -l app.kubernetes.io/component=admission-controller \
  --tail=100 | grep -i "verify"
{% endhighlight %}

Common log patterns to look for: `image verification failed` (policy blocking correctly), `failed to fetch signatures` (OCIR auth issue — check the imagePullSecret), `no signatures found` (image is unsigned or wrong digest), `failed to verify signature` (key mismatch).

## Terraform: Managing OCIR and Vault Resources as Code

The following resources provision the complete infrastructure foundation: the OCIR repository, OKE node IAM policies for pulling images, and the OCI Vault with the Cosign passphrase secret.

{% highlight hcl %}
# ── OCIR Repository ───────────────────────────────────────────────
resource "oci_artifacts_container_repository" "app_repo" {
  compartment_id = var.compartment_id
  display_name   = "myapp/backend"
  is_public      = false
  freeform_tags  = { "managed-by" = "terraform" }
}

# ── OKE Worker Node Dynamic Group ────────────────────────────────
resource "oci_identity_dynamic_group" "oke_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "oke-worker-nodes"
  description    = "OKE worker node instances"
  matching_rule  = "All {instance.compartment.id = '${var.node_compartment_id}'}"
}

# ── IAM Policy: OKE nodes pull from OCIR ─────────────────────────
resource "oci_identity_policy" "oke_ocir_pull" {
  compartment_id = var.compartment_id
  name           = "oke-pull-from-ocir"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.oke_nodes.name} to read repos in compartment ${var.compartment_name}",
  ]
}

# ── OCI Vault ─────────────────────────────────────────────────────
resource "oci_kms_vault" "devsecops" {
  compartment_id = var.compartment_id
  display_name   = "devsecops-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "devsecops" {
  compartment_id      = var.compartment_id
  display_name        = "devsecops-key"
  management_endpoint = oci_kms_vault.devsecops.management_endpoint

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

# ── Cosign Passphrase Secret ──────────────────────────────────────
resource "oci_vault_secret" "cosign_passphrase" {
  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.devsecops.id
  key_id         = oci_kms_key.devsecops.id
  secret_name    = "cosign-key-passphrase"

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.cosign_passphrase)
  }
}
{% endhighlight %}

The `oci_identity_policy` granting the OKE dynamic group `read repos` access is what enables node-level image pulls without embedding credentials in a Kubernetes secret. This is the preferred approach for OKE: node instances carry the IAM identity, and that identity is what OCIR verifies. Note that this policy covers image pulls by nodes — the Kyverno `imagePullSecret` configured in Step 6 is still needed separately for the Kyverno admission controller to fetch signature artifacts, because Kyverno runs as a Pod, not as a node-level agent with instance principal auth.

Add the required variables:

{% highlight hcl %}
variable "compartment_id" {
  description = "Compartment for OCIR, Vault, and policies"
  type        = string
}

variable "tenancy_ocid" {
  description = "Tenancy OCID for dynamic group and IAM policies"
  type        = string
}

variable "node_compartment_id" {
  description = "Compartment where OKE worker nodes run"
  type        = string
}

variable "compartment_name" {
  description = "Name of the compartment, used in IAM policy statements"
  type        = string
}

variable "cosign_passphrase" {
  description = "Passphrase for the Cosign private key"
  type        = string
  sensitive   = true
}
{% endhighlight %}

## Best Practices and Gotchas

**Sign by digest, always.** The commands in this post use `docker inspect` to extract the digest and pass it explicitly to `cosign sign`. A pipeline that builds, pushes, and then signs by digest is the correct pattern. A pipeline that signs the tag `v1.0.0` after pushing is signing the artifact that happened to have that tag at that moment — defensible, but brittle.

**Keep `--tlog-upload=false` consistent across sign and verify.** If you signed with `--tlog-upload=false` and then verify without `--insecure-ignore-tlog=true`, Cosign tries to fetch a Rekor entry that does not exist and fails. The policy's `rekor.ignoreTlog: true` and `ctlog.ignoreSCT: true` fields are the Kyverno-side expression of this same consistency requirement. Both sides must agree on whether Rekor is part of the trust chain.

**The Kyverno imagePullSecret is not the same as the node pull secret.** A common mistake: configuring the OKE node pool's imagePullSecret for OCIR and assuming Kyverno inherits it. It does not. Kyverno's admission controller is a Pod in the `kyverno` namespace and needs its own credential. The `--imagePullSecrets` argument or the Helm `existingImagePullSecrets` value is mandatory for private OCIR repositories.

**`failurePolicy: Fail` is non-negotiable.** If your Kyverno deployment goes unhealthy and `failurePolicy` is `Ignore`, unsigned images can reach production for the duration of the outage. For a security control this is unacceptable. Run Kyverno in HA mode (3 replicas for the admission controller) and accept the `Fail` failure policy as the price of having a real security boundary.

**Store `cosign.key` out of source control.** The key is passphrase-encrypted, so a compromised private key file alone is not immediately exploitable — but it dramatically lowers the effort needed to forge signatures if the passphrase is also exposed. Keep the key in an encrypted artifact store, a CI/CD secrets manager, or an HSM-backed KMS. OCI Vault managed keys (HSM type) can store secrets and are FIPS 140-2 Level 3 validated if that is a compliance requirement.

**Rotate keys periodically and update the ClusterPolicy atomically.** Key rotation requires generating a new pair, re-signing all current images with the new key, updating the `publicKeys` field in the ClusterPolicy, and only then discarding the old key. The window between updating the policy and completing re-signing of all images needs to be managed carefully — consider adding both old and new public keys as separate `attestors.entries` items during the transition.

**Use `imageReferences` patterns that match exactly your tenancy's scope.** The `*.ocir.io/<tenancy-ns>/*` pattern in the policy covers all OCIR regions for your tenancy. If you want to restrict enforcement to a single region, use `syd.ocir.io/<tenancy-ns>/*`. Images from other registries that are not matched by any `imageReferences` pattern are not subject to `verifyImages` evaluation — combine this policy with the `restrict-image-registries` policy from the Kyverno post to ensure nothing slips through.

**Test with `--dry-run=server` before enforcing.** Before switching to `failureAction: Enforce`, run your pods with `kubectl apply --dry-run=server` against the policy in Audit mode to surface any images that will be blocked. The PolicyReport populated in Audit mode shows which existing workloads would fail, giving you the full remediation list before you start blocking production.

## Wrapping Up

This post closes the supply chain security loop that started with OCI VSS scanning OCIR images for CVEs and continued with Kyverno blocking non-compliant pod specs on OKE. Scanning tells you what vulnerabilities are present. Registry restrictions tell you which source is allowed. Signature verification tells you who produced the artifact. All three are necessary; none of them alone is sufficient.

The key-based approach with a local ECDSA key pair and the passphrase in OCI Vault Secrets is operationally straightforward and completely private — your image digests never appear in a public transparency log. The Kyverno ClusterPolicy is a single YAML resource that embeds the public key and enforces the trust chain at every Pod admission event, for every workload, across every namespace. Once it is in place, shipping an unsigned image to production is not a policy violation waiting to be detected — it is a hard block at the gate.

The natural next step from here is integrating `cosign sign` into your CI/CD pipeline so that signing happens automatically on every successful build, eliminating the manual step entirely. The passphrase retrieval from OCI Vault via OCI CLI — covered in Step 1 — is the building block for that automation.

Happy scripting!
