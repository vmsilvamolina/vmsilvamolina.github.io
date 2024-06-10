---
title: 'GCP Binary Authorization Terraform: GKE image signing'
author: Victor Silva
date: 2024-06-10T10:00:00+00:00
layout: post
permalink: /gcp-binary-authorization-gke-terraform/
excerpt: "Signing an image means nothing if your cluster runs unsigned ones. Build GCP Binary Authorization for GKE with Terraform: KMS key, attestor, and policy."
categories:
  - GCP
  - Security
tags:
  - GCP
  - Binary Authorization
  - Kubernetes
  - Terraform
  - Security
  - google_binary_authorization_policy
  - Binary Authorization GKE
  - container image signing GKE
  - Cloud KMS
  - supply chain security
  - terraform google provider
---

The SolarWinds and 3CX attacks share a structural pattern: a trusted build system was compromised, and the resulting artifacts were distributed and run without anyone questioning their legitimacy. The code was signed — just by the wrong entity after the wrong build process. Once an attacker is inside your supply chain, the question shifts from "is this image signed?" to "can I prove this image was produced by a specific, audited pipeline and nothing else?"

That is the problem Binary Authorization is designed to address. It does not just check for the existence of a signature — it requires that an image carry an attestation from a specific attestor that you control, backed by a cryptographic key in Cloud KMS, before GKE will schedule it. No attestation, no scheduling. The policy is enforced at the Kubernetes admission layer, so it applies regardless of how the image was submitted — `kubectl apply`, Helm, ArgoCD, or anything else.

This post is the enforcement companion to [signing container images with Cosign and Sigstore](/signing-container-images-cosign-sigstore/). Where that post covered producing signatures, this one covers requiring them. I will walk through the full stack with Terraform: a Cloud KMS asymmetric signing key, a Container Analysis note, an attestor, a Binary Authorization policy with a safe rollout path, a GKE cluster configured to enforce the policy, and a Cloud Build pipeline that produces valid attestations. I will also cover the misconfigurations that will quietly undermine your enforcement if you are not aware of them.

## How Binary Authorization Works

Before writing any Terraform it is worth understanding the four actors in the system, because the Terraform resources map directly to them.

```
Cloud Build (Signer)
      |
      | signs image digest with KMS key
      v
Attestation (stored in Artifact Analysis)
      |
      | checked by
      v
Attestor (holds public key + note reference)
      |
      | referenced by
      v
Policy (project singleton, one per project)
      |
      | enforced by
      v
GKE Admission Webhook (blocks or allows scheduling)
```

**Attestor** — a resource that holds a public key reference and a Container Analysis note. It is the identity that produced a valid attestation. A project can have multiple attestors for different pipelines or environments.

**Attestation** — a signed payload stored as an Artifact Analysis occurrence, linked to a specific image digest. The attestation proves that the attestor's private key signed a record of that digest.

**Policy** — a project singleton. There is exactly one Binary Authorization policy per GCP project. It defines which attestors are required before an image can be run, with different rules possible for different clusters.

**GKE Admission Webhook** — Binary Authorization installs a webhook into your GKE cluster that intercepts every pod creation request, checks the policy, and blocks or allows the pod based on whether the required attestations are present.

One invariant that cannot be negotiated: Binary Authorization always operates on the image digest, never the tag. A tag is mutable — the same tag can point to a different digest tomorrow. An attestation is bound to a specific `sha256:...` digest, and that is what the webhook checks. This is not just a best practice; it is how the system works architecturally. The implication for your deployment manifests is that you need to reference images by digest, not tag, or your cluster will either reject valid images or be fooled by tag mutations.

### Enforcement Modes

Binary Authorization has two enforcement modes that map to a safe rollout progression:

`DRYRUN_AUDIT_LOG_ONLY` — the webhook checks policy but does not block anything. Violations are logged to Cloud Audit Logs. Use this mode when you first enable Binary Authorization to understand what would be blocked before actually blocking it.

`ENFORCED_BLOCK_AND_AUDIT_LOG` — violations are blocked and logged. This is the production mode. Move to this only after you have validated that all legitimate workloads have valid attestations.

The policy also has a breakglass escape hatch: adding the label `image-policy.k8s.io/break-glass: "true"` to a pod bypasses enforcement. This is intentional for emergency scenarios, but every breakglass use is audit-logged. I will cover how to monitor for it later.

## Prerequisites

To follow along you will need:

- Terraform 1.5 or later
- The `google` provider version 5.x
- A GCP project with billing enabled
- The following APIs enabled: `binaryauthorization.googleapis.com`, `containeranalysis.googleapis.com`, `cloudkms.googleapis.com`, `container.googleapis.com`, `artifactregistry.googleapis.com`
- `gcloud` CLI authenticated with a principal that has Project Editor or equivalent IAM permissions
- An Artifact Registry repository to push images to

Enable the required APIs:

{% highlight bash %}
gcloud services enable \
  binaryauthorization.googleapis.com \
  containeranalysis.googleapis.com \
  cloudkms.googleapis.com \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  --project="${PROJECT_ID}"
{% endhighlight %}

Verify authentication and confirm your project:

{% highlight bash %}
gcloud auth application-default login
gcloud config get-value project
terraform version
{% endhighlight %}

## Building the Stack with Terraform

The implementation follows the dependency chain: KMS key → Container Analysis note → Attestor → Policy → GKE cluster → IAM. I will walk through each resource with the reasoning behind the configuration decisions.

### Cloud KMS Signing Key

Binary Authorization uses asymmetric signing. Your CI pipeline signs image digests with the private key half; the attestor holds the public key half for verification. EC P-256 with SHA-256 is the algorithm Binary Authorization recommends and the one that offers a good balance of security and performance.

Create `kms.tf`:

{% highlight hcl %}
resource "google_kms_key_ring" "binauthz" {
  name     = "binauthz-keyring"
  location = "global"
}

resource "google_kms_crypto_key" "signing_key" {
  name     = "binauthz-signing-key"
  key_ring = google_kms_key_ring.binauthz.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "EC_SIGN_P256_SHA256"
    protection_level = "SOFTWARE"  # use HSM in production
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "signing_key_version" {
  crypto_key = google_kms_crypto_key.signing_key.id
}
{% endhighlight %}

The `lifecycle { prevent_destroy = true }` block is not optional. If you accidentally destroy this key and recreate it, the public key changes — and every attestation ever created with the old key becomes unverifiable. Existing workloads that reference those attestations will fail policy checks. Protecting the key from accidental destruction in Terraform is a hard requirement.

For production, `protection_level = "HSM"` stores the private key material in hardware security modules and prevents it from ever being exported. The cost increase is modest compared to the security improvement.

### Container Analysis Note and Attestor

The Container Analysis note is the anchor for attestations. Think of it as a named container that holds all the attestations produced by a given pipeline. The attestor points to this note and holds the public key.

Create `binauthz.tf`:

{% highlight hcl %}
resource "google_container_analysis_note" "build_note" {
  name = "build-attestor-note"

  attestation_authority {
    hint {
      human_readable_name = "Built and signed by Cloud Build"
    }
  }
}

resource "google_binary_authorization_attestor" "build_attestor" {
  name = "build-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name

    public_keys {
      id = data.google_kms_crypto_key_version.signing_key_version.id

      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.signing_key_version.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.signing_key_version.public_key[0].algorithm
      }
    }
  }

  depends_on = [google_container_analysis_note.build_note]
}
{% endhighlight %}

The `depends_on` is necessary because the Container Analysis API enforces that the note must exist before an attestor can reference it. Without explicit ordering, Terraform may submit both creates concurrently, and the attestor creation will fail.

The `pkix_public_key` block reads the public key PEM directly from the KMS key version data source. This is the clean approach — the public key material is managed by KMS and you reference it dynamically rather than hard-coding a PEM string.

### Binary Authorization Policy

The policy is where enforcement decisions are made. There is exactly one policy per project, and it applies across all clusters in the project unless you define cluster-specific override rules. Here I define both a default rule in dry-run mode and a cluster-specific rule in enforced mode, which lets you enable enforcement cluster by cluster:

{% highlight hcl %}
variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "cluster_name" {
  type    = string
  default = "primary"
}

resource "google_binary_authorization_policy" "policy" {
  global_policy_evaluation_mode = "ENABLE"

  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/gke-release/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/gke-node-images/*"
  }

  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "DRYRUN_AUDIT_LOG_ONLY"

    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name
    ]
  }

  cluster_admission_rules {
    cluster          = "${var.zone}.${var.cluster_name}"
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name
    ]
  }

  depends_on = [google_binary_authorization_attestor.build_attestor]
}
{% endhighlight %}

`global_policy_evaluation_mode = "ENABLE"` is the single most important setting in this configuration. Without it, GKE system images — `kube-dns`, `metrics-server`, `kube-proxy`, and others — are subject to the same attestation requirements as your application images. None of them have your attestations, so cluster bootstrap fails. Your nodes come up and then nothing schedules. Setting `global_policy_evaluation_mode = "ENABLE"` tells Binary Authorization to automatically exempt GKE-managed system images using Google's own attestation infrastructure. This is required in every production Binary Authorization configuration.

The `admission_whitelist_patterns` entries whitelist GKE release images at the registry level. These are belt-and-suspenders insurance in addition to `global_policy_evaluation_mode`. Keep these patterns specific — never use a bare wildcard (`*`) as a whitelist pattern. A bare wildcard effectively disables enforcement for every image, which defeats the entire purpose of the policy.

The `cluster_admission_rules` block uses `"${var.zone}.${var.cluster_name}"` as the cluster identifier. This is the format Binary Authorization expects: `ZONE.CLUSTER_NAME`. If your cluster is regional rather than zonal, use the region: `REGION.CLUSTER_NAME`.

### GKE Cluster with Binary Authorization

Enabling Binary Authorization on the cluster is a single field:

{% highlight hcl %}
data "google_project" "project" {}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
{% endhighlight %}

`evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"` tells GKE to use the project's Binary Authorization policy for this cluster. The alternative mode is `DISABLED`, which turns off Binary Authorization on the cluster entirely. There is no in-between — either the cluster enforces the project policy or it does not.

### IAM for Cloud Build

The Cloud Build service account needs three permissions to create attestations: permission to read attestors, permission to sign with the KMS key, and permission to attach occurrences to Container Analysis notes.

{% highlight hcl %}
locals {
  cb_sa = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "cb_attestor_viewer" {
  project = data.google_project.project.project_id
  role    = "roles/binaryauthorization.attestorsViewer"
  member  = local.cb_sa
}

resource "google_project_iam_member" "cb_kms_signer" {
  project = data.google_project.project.project_id
  role    = "roles/cloudkms.signerVerifier"
  member  = local.cb_sa
}

resource "google_project_iam_member" "cb_notes_attacher" {
  project = data.google_project.project.project_id
  role    = "roles/containeranalysis.notes.attacher"
  member  = local.cb_sa
}
{% endhighlight %}

`roles/cloudkms.signerVerifier` grants the Cloud Build SA the ability to use the KMS key for both signing and verification operations. This is the minimum required — `roles/cloudkms.cryptoKeyEncrypterDecrypter` is the wrong role, and a common mistake, because it covers symmetric encryption rather than asymmetric signing.

`roles/containeranalysis.notes.attacher` is scoped to note attachment specifically. The broader `roles/containeranalysis.admin` would also work but grants far more than is needed. Prefer the minimum viable role.

## Signing Images in Cloud Build

Now that the infrastructure exists, the Cloud Build pipeline needs to produce attestations as part of every build. The flow is: build the image, push it, retrieve the digest, attest.

Create `cloudbuild.yaml` in your application repository:

{% highlight yaml %}
steps:
  - id: build
    name: gcr.io/cloud-builders/docker
    args:
      - build
      - -t
      - us-docker.pkg.dev/$PROJECT_ID/app-repo/my-app:$COMMIT_SHA
      - .

  - id: push
    name: gcr.io/cloud-builders/docker
    args:
      - push
      - us-docker.pkg.dev/$PROJECT_ID/app-repo/my-app:$COMMIT_SHA

  - id: get-digest
    name: gcr.io/cloud-builders/gcloud
    entrypoint: bash
    args:
      - -c
      - |
        DIGEST=$(gcloud artifacts docker images describe \
          us-docker.pkg.dev/$PROJECT_ID/app-repo/my-app:$COMMIT_SHA \
          --format='get(image_summary.digest)')
        echo "$$DIGEST" > /workspace/image_digest.txt
        echo "Image digest: $$DIGEST"

  - id: attest
    name: gcr.io/cloud-builders/gcloud
    entrypoint: bash
    args:
      - -c
      - |
        IMAGE_DIGEST=$(cat /workspace/image_digest.txt)
        gcloud container binauthz attestations sign-and-create \
          --artifact-url="us-docker.pkg.dev/$PROJECT_ID/app-repo/my-app@$$IMAGE_DIGEST" \
          --attestor="$_ATTESTOR_NAME" \
          --attestor-project="$PROJECT_ID" \
          --keyversion-project="$PROJECT_ID" \
          --keyversion-location="$_KMS_LOCATION" \
          --keyversion-keyring="$_KMS_KEYRING" \
          --keyversion-key="$_KMS_KEY" \
          --keyversion="1"

substitutions:
  _ATTESTOR_NAME: build-attestor
  _KMS_LOCATION: global
  _KMS_KEYRING: binauthz-keyring
  _KMS_KEY: binauthz-signing-key
{% endhighlight %}

The `get-digest` step retrieves the digest after the push completes. You cannot compute the digest locally before pushing because the registry may apply transformations. Pulling the digest from Artifact Registry after the push ensures you are attesting the exact bytes that are stored in the registry.

The `sign-and-create` command does two things in one operation: it creates the cryptographic signature using the KMS key, and it stores the resulting attestation as an Artifact Analysis occurrence linked to the image digest. The attestation is now queryable and verifiable by the Binary Authorization webhook.

The `$$DIGEST` double-dollar syntax is Cloud Build's way of referencing shell variables inside substituted build steps — a single `$` would be interpreted as a Cloud Build substitution variable.

## Testing and Validation

With the policy in dry-run mode initially, the first validation pass is checking what would be blocked before switching to enforcement.

### Verify the Policy Configuration

Export the current policy and confirm it matches what you applied:

{% highlight bash %}
gcloud container binauthz policy export --project="${PROJECT_ID}"
{% endhighlight %}

Confirm the attestor is configured correctly with the right public key:

{% highlight bash %}
gcloud container binauthz attestors describe build-attestor \
  --project="${PROJECT_ID}" \
  --format=yaml
{% endhighlight %}

The output should show the PKIX public key PEM and the note reference. If the note reference is missing or the key does not match your KMS key, policy evaluation will fail silently or with confusing error messages.

### Deploy an Unattested Image

With the cluster-level rule in `ENFORCED_BLOCK_AND_AUDIT_LOG` mode, attempt to run an image that has no attestation:

{% highlight bash %}
kubectl run test-blocked \
  --image=us-docker.pkg.dev/${PROJECT_ID}/app-repo/my-app:some-unattested-tag \
  --restart=Never
{% endhighlight %}

The pod creation should be denied with an error message from the admission webhook:

```
Error from server (VIOLATES_POLICY): admission webhook
"imagepolicywebhook.image-policy.k8s.io" denied the request:
Attestations for images and binaries referenced by containers
in this pod were not found. Images must be attested by all
attestors required by the project policy.
```

That error is the system working correctly. Now deploy an image that went through the Cloud Build pipeline and has a valid attestation:

{% highlight bash %}
# Get the digest of an attested image
IMAGE_DIGEST=$(gcloud artifacts docker images describe \
  us-docker.pkg.dev/${PROJECT_ID}/app-repo/my-app:${COMMIT_SHA} \
  --format='get(image_summary.digest)')

# Reference by digest in the deployment
kubectl run test-allowed \
  --image="us-docker.pkg.dev/${PROJECT_ID}/app-repo/my-app@${IMAGE_DIGEST}" \
  --restart=Never
{% endhighlight %}

This pod should schedule successfully.

### Verify Attestations Exist

You can query attestations for any image to confirm the Cloud Build pipeline produced them correctly:

{% highlight bash %}
IMAGE_TO_ATTEST="us-docker.pkg.dev/${PROJECT_ID}/app-repo/my-app@${IMAGE_DIGEST}"

gcloud container binauthz attestations list \
  --attestor="projects/${PROJECT_ID}/attestors/build-attestor" \
  --artifact-url="${IMAGE_TO_ATTEST}"
{% endhighlight %}

If the list is empty, the attestation step in Cloud Build did not run or failed silently. Check the Cloud Build logs for the `attest` step.

### Check Audit Logs

Binary Authorization writes all policy evaluation events to Cloud Audit Logs. This is where dry-run violations and enforcement blocks both appear:

{% highlight bash %}
gcloud logging read \
  'protoPayload.serviceName="binaryauthorization.googleapis.com"' \
  --freshness=1h \
  --project="${PROJECT_ID}" \
  --format='table(timestamp, protoPayload.methodName, protoPayload.status.message)'
{% endhighlight %}

During dry-run mode, you will see `denyAttempt` entries for any image that would have been blocked. Use this output to identify workloads that need attestations before you switch to enforced mode.

Monitor for breakglass usage in production separately. Any use of the breakglass label should trigger an alert:

{% highlight bash %}
gcloud logging read \
  'protoPayload.request.breakGlass=true' \
  --freshness=30d \
  --project="${PROJECT_ID}"
{% endhighlight %}

Wire this into a Cloud Monitoring alert policy so you know immediately when someone bypasses enforcement.

## Key Misconfigurations to Avoid

Binary Authorization has several failure modes that will silently undermine your enforcement if you are not aware of them.

**Missing `global_policy_evaluation_mode = "ENABLE"`**

If you omit this setting, GKE system components — `kube-dns`, `metrics-server`, `kube-proxy`, and others — are subject to the same attestation requirements as your applications. None of them have attestations from your attestor. The result is a cluster that boots up and then fails to schedule anything, including the system pods that make the cluster functional. Always set `global_policy_evaluation_mode = "ENABLE"`.

**Overly broad whitelist patterns**

Using `*` as a whitelist pattern exempts every image from policy evaluation. This effectively disables Binary Authorization while leaving it technically enabled. If you need to whitelist images, be specific: `gcr.io/google_containers/*` is fine; `*` is not. Review your whitelist patterns whenever you add new entries.

**Tag-based image references**

Binary Authorization operates on digests. If your deployment manifests reference images by tag (`my-app:v1.2.3`), the webhook resolves the tag to a digest at admission time — but your CI/CD pipeline signed a specific digest, not the tag. If the tag has been updated to point to a different digest since the attestation was created, the attestation will not match and the pod will be blocked. Always use digest-based references in production deployment manifests. Combine Binary Authorization with an OPA Gatekeeper or Kyverno policy that rejects tag-only image references to enforce this consistently.

**Breakglass label left in production manifests**

The breakglass label `image-policy.k8s.io/break-glass: "true"` is intended for emergency use only, but it is easy for a label added during an incident to remain in a manifest that gets committed and deployed repeatedly. Every pod with that label bypasses Binary Authorization silently — and you only know about it if you are monitoring the audit logs. Audit your production manifests for the breakglass label regularly, and set a Cloud Monitoring alert on the log query shown in the testing section above.

**Init containers are not evaluated**

This is a known limitation: Binary Authorization does not evaluate init containers. An attacker who can control a pod spec can include an unattested image as an init container and it will run without any policy check. This bypasses your enforcement entirely if the init container contains the malicious code. Complement Binary Authorization with an OPA Gatekeeper policy that restricts init container images to the same allowed patterns as your main containers.

**Fail-open under API quota exhaustion**

If the Binary Authorization API experiences quota exhaustion or a service disruption, GKE may fail open — allowing pods to schedule that would otherwise be blocked. Monitor `quota_exceeded_error_count` in Cloud Monitoring and set alerts on it. Quota exhaustion events during a security incident are not coincidental.

## Best Practices

**Start with dry-run, move cluster by cluster.** Deploy the policy globally with `DRYRUN_AUDIT_LOG_ONLY` first. Let it run for at least a week while you review the audit logs. Identify every workload that would be blocked. Build the attestation pipeline for each of them. Then switch clusters to `ENFORCED_BLOCK_AND_AUDIT_LOG` one at a time, starting with non-production environments.

**Use `prevent_destroy` on your KMS signing key.** If the signing key is deleted and recreated, the public key changes and all existing attestations become unverifiable. Every attested image in your registry loses its attestation. This is a catastrophic event for a Binary Authorization deployment. Protect the key in Terraform, and restrict KMS key deletion permissions in IAM as well.

**Sign by digest in Cloud Build, deploy by digest in Kubernetes.** The attestation is bound to a specific digest. If your Kubernetes manifests reference images by tag, a tag mutation between the time of attestation and the time of deployment can cause the attestor and webhook to disagree about what was signed. Always reference images by digest in deployment manifests. The Cloud Build pipeline should write the digest to a manifest as part of the release process.

**Use separate attestors for different stages.** A single attestor for all environments means that an image that passed CI could be deployed to production directly if someone bypasses the deployment gate. Consider adding a second attestor for production — one for "built by CI" and one for "approved for production" — and require both attestations in your production cluster rules. The two-attestor pattern provides defense in depth against pipeline bypasses.

**Restrict breakglass to break-glass situations.** The breakglass label is useful during genuine incidents. It is dangerous when it becomes a routine workaround. Create a Cloud Monitoring alert on breakglass audit log entries, route it to your security team, and require a documented incident ticket for every use. Treat a breakglass event the same way you treat a privileged access escalation — log it, review it, and remediate the underlying cause.

**Review attestations for public base images.** Your Cloud Build pipeline attests images it builds. But what about public base images pulled directly into deployments? A policy that only allows attested images will block public images unless you whitelist their registries. Be explicit about which external registries you trust and whitelist them specifically in the policy, rather than opening up enforcement broadly.

## Conclusion

Binary Authorization turns image signing from a paper guarantee into an enforced runtime control. With the stack built in this post — a Cloud KMS asymmetric signing key, a Container Analysis note, an attestor, a policy with `global_policy_evaluation_mode = "ENABLE"`, a GKE cluster enforcing the project policy, and a Cloud Build pipeline that produces attestations on every build — your cluster will reject any image that was not produced and signed by your trusted pipeline.

The rollout path matters: start with `DRYRUN_AUDIT_LOG_ONLY`, review the audit logs thoroughly, then switch to `ENFORCED_BLOCK_AND_AUDIT_LOG` cluster by cluster. The biggest operational risk is not enforcement being too strict — it is enforcement being bypassed through the misconfigurations covered above. The whitelist patterns, init container limitation, and breakglass label are the three areas worth reviewing on a regular basis once you are in production.

For teams already using Cosign for image signing, as covered in [the previous post in this series](/signing-container-images-cosign-sigstore/), Binary Authorization can be configured to use Cosign-compatible attestations through the PKIX key format. The two systems can coexist: Cosign signatures for teams using GitHub Actions and open-source registries, Binary Authorization attestations for workloads running through Cloud Build and deploying to GKE. Both layers working together give you the supply chain depth that neither provides alone.

Binary Authorization controls what gets scheduled, but it does not watch what those workloads do at runtime. [Falco for runtime security in Kubernetes](/falco-runtime-security-kubernetes/) covers the complementary layer — syscall-level detection that fires when a container behaves unexpectedly after it has been admitted. For enforcing additional policy constraints beyond image attestation, such as blocking tag-only image references or restricting init container images, [OPA and Rego admission controller policies](/opa-rego-admission-controller-policy/) walks through writing and deploying Gatekeeper constraints that work alongside Binary Authorization.

Happy scripting!
