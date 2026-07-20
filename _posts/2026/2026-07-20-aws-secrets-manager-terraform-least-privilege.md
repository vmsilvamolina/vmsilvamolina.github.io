---
title: 'AWS Secrets Manager Terraform: Least-Privilege Access'
author: Victor Silva
date: 2026-07-20T13:28:34+00:00
layout: post
permalink: /aws-secrets-manager-terraform-least-privilege/
excerpt: "Can't edit the IAM role? Lock down AWS Secrets Manager with Terraform's aws_secretsmanager_secret_policy for genuine least-privilege access control."
categories:
  - AWS
  - Security
tags:
  - AWS Secrets Manager
  - Terraform
  - IAM
  - Least Privilege
  - Resource-Based Policy
  - AWS Academy
---

You've just been handed access to an AWS account, and the identity you're given — a role, not a user — already has broad permissions baked in. You didn't create it. You can't edit it. You definitely can't run `iam:CreatePolicy` to carve out something narrower. And yet the task in front of you is straightforward on paper: store this database password in AWS Secrets Manager, provision it with Terraform, and make sure only the application can read it.

If your instinct is "that's impossible without controlling IAM," you've been thinking about least privilege in only one dimension. This situation is more common than it looks: AWS Academy Learner Labs hand every student a pre-baked `LabRole` with a wide identity policy and no `iam:CreateRole` permission. Cross-account setups often hand you a role assumed from another account that you don't own. Vendor-managed execution environments — a SaaS platform's "bring your own AWS account" integration, an SCP-locked landing zone where a central platform team owns every IAM policy — put you in exactly the same spot: you have an identity to work with, and you have zero ability to narrow what that identity is allowed to do at the IAM layer.

This post walks through the pattern that solves that problem for AWS Secrets Manager specifically: instead of fighting the identity-based policy you can't touch, you attach a **resource-based policy directly to the secret**. AWS evaluates both layers, and a resource policy scoped tightly enough compensates for an identity policy that's far too broad. We'll build this end-to-end with Terraform — creating the secret, writing its value safely, and layering on a resource policy that restricts access to exactly what's needed — and verify it actually works with both a positive and a negative test.

One thing this post deliberately does not cover: secret rotation. Creating a secret and locking down who can read it is a big enough topic on its own, and rotation with Lambda functions deserves its own post — that's coming next.

## The dual-layer access model: why a resource policy works when the identity policy doesn't

Every authorization decision in AWS Secrets Manager (and IAM generally) is the result of evaluating **two independent policy types** for the same request:

- **Identity-based policy** — attached to the principal making the call (a user, role, or federated identity). This is the "what can this identity do" policy. In our scenario, this is `LabRole` — broad, pre-created, and out of reach.
- **Resource-based policy** — attached to the resource being accessed. For Secrets Manager, this is the `aws_secretsmanager_secret_policy` resource. This is the "who can touch this specific secret" policy, and it's the one lever we actually control.

AWS evaluates both layers for every request, and the combination logic is simple once you internalize it:

1. If **either** layer contains an explicit `Deny` that matches the request, the request is denied. Full stop — nothing else matters.
2. If neither layer denies, the request is allowed **only if at least one layer contains an explicit `Allow`** that matches.
3. Everything not explicitly allowed is implicitly denied.

Here's the part that makes this pattern possible: when a resource-based policy exists on a secret, AWS treats it as authoritative for that resource. A principal that has broad `secretsmanager:*` permissions in its identity policy will still be denied if the secret's resource policy doesn't grant it access. Conversely, a narrow resource policy attached to the secret can grant access to a principal whose identity policy alone wouldn't be a problem — but more importantly for us, it can also **restrict** what an overly broad identity policy would otherwise allow, by scoping the resource policy's `Allow` to specific principals, specific actions, and specific conditions.

In plain terms: `LabRole` being allowed to call `secretsmanager:GetSecretValue` on `*` at the identity layer doesn't matter if the secret's resource policy doesn't also say "yes, and this principal specifically, under these conditions." You're not narrowing `LabRole`. You're building a gate around the secret that `LabRole` has to pass through regardless of how permissive its own policy is.

```
Request: LabRole calls secretsmanager:GetSecretValue on secret X
                    │
        ┌───────────┴────────────┐
        │                        │
  Identity Policy          Resource Policy
  (LabRole — broad,        (attached to secret X —
   not editable)            the lever we control)
        │                        │
        │   Allow (implicit,     │   Allow, scoped to LabRole ARN
        │   broad wildcard)      │   + VersionStage = AWSCURRENT
        │                        │
        └───────────┬────────────┘
                     │
        Both layers must permit, and an explicit
        Deny in either layer wins outright
                     │
              ┌──────┴──────┐
              │   Decision   │
              └─────────────┘
```

This is the mechanic behind compensating controls in cloud security: when you can't fix the root cause, you add a second, independent layer that constrains the blast radius. It's not a workaround specific to Academy — it's the correct pattern any time you inherit an identity you can't shape.

## Prerequisites and a self-check before you start

You'll need:

- Terraform >= 1.5 (examples use the mainline `secret_string` pattern; if you're on Terraform >= 1.11 I'll also show the write-only alternative)
- AWS provider `hashicorp/aws` >= 5.0
- AWS CLI v2, configured with credentials for your lab session (Academy sessions typically expire after ~4 hours and require re-copying temporary credentials)
- An active AWS Academy Learner Lab session, or any AWS environment where you're working with a pre-created role you cannot modify

Academy's exact allow-list of permitted services isn't published anywhere official, and it varies by course and lab template. Don't assume — verify. Before writing a single line of Terraform, confirm two things: who you are, and whether Secrets Manager is reachable at all in this session.

{% highlight bash %}
# Confirm the identity your session is actually using
aws sts get-caller-identity

# Confirm Secrets Manager is reachable and permitted in this lab
aws secretsmanager list-secrets --region us-east-1
{% endhighlight %}

The first command should return an ARN that includes `assumed-role/LabRole` (or `voclabs`, depending on the course template). The second should return an empty `SecretList: []` on a fresh account, not an `AccessDeniedException`. If the second command fails, stop here — this particular lab template doesn't expose Secrets Manager, and no amount of Terraform will fix that.

All examples below target `us-east-1`, the typical Academy default region. It's fully configurable via the `aws_region` variable — just be aware that Academy labs sometimes restrict which regions are usable, so check before switching.

## Step-by-step implementation

### Provider and variables

Nothing exotic in the provider block, but pin the version — resource policy behavior and `block_public_policy` support landed in specific provider releases, and you don't want a `terraform init` on a different machine silently picking up a version that doesn't support a field you're relying on.

{% highlight hcl %}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5"
}

provider "aws" {
  region = var.aws_region
}
{% endhighlight %}

{% highlight hcl %}
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "db_password" {
  description = "Secret value for the database password. Set via TF_VAR_db_password, never committed."
  type        = string
  sensitive   = true
}
{% endhighlight %}

The `db_password` variable is never given a default. You export it as an environment variable before running Terraform, which keeps it out of your `.tf` files, your shell history (if you use a leading space, most shells won't log it), and version control entirely:

{% highlight bash %}
export TF_VAR_db_password="$(openssl rand -base64 24)"
terraform apply
{% endhighlight %}

### Resolving the LabRole ARN dynamically

We need the full ARN of `LabRole` to reference it in the resource policy, and that ARN includes the account ID — which you shouldn't hardcode, both because it changes every time Academy resets your lab and because hardcoding account IDs in Terraform is a portability smell regardless of context. The `aws_caller_identity` data source gives us the account ID of whatever credentials Terraform is currently using:

{% highlight hcl %}
data "aws_caller_identity" "current" {}

locals {
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}
{% endhighlight %}

If your environment uses a differently named pre-created role — a cross-account assumed role, a vendor-managed execution role — swap `LabRole` for that role's name. Everything downstream stays the same; only this one string changes.

### Creating the secret container

{% highlight hcl %}
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "app/production/db-password"
  description             = "Database admin password for the production app tier"
  recovery_window_in_days = 0

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
{% endhighlight %}

Two details worth stopping on:

**`recovery_window_in_days = 0`** deletes the secret immediately (no 7–30 day soft-delete window) when Terraform destroys it. In a normal AWS account you'd think twice about this — soft-delete is a safety net against accidental deletion. But in an Academy lab, sessions reset roughly every four hours, and if you re-apply the same Terraform in a fresh session after a prior session left a secret in the pending-deletion state, `aws_secretsmanager_secret` creation fails with a name collision — Secrets Manager won't let you create a new secret with a name that's still reserved by a soft-deleted one. Setting the recovery window to zero means `terraform destroy` actually frees the name immediately, which matters a lot when you're iterating across multiple short-lived sessions. In a real production account with a stable lifecycle, you'd likely want the default recovery window instead.

**No KMS configuration at all.** Notice there's no `kms_key_id` argument in this block. Secrets Manager encrypts every secret at rest by default using the AWS-managed key `aws/secretsmanager`, and using that default key requires zero additional IAM permissions — `LabRole`'s existing access is enough, because AWS-managed keys don't require an explicit key policy grant the way customer-managed KMS keys do. This is genuinely AWS-specific: both GCP Secret Manager and OCI Vault expect a provider-managed or customer-managed key with its own grants before secrets even work. AWS gets you to "encrypted at rest, zero extra config" faster than either.

### Writing the secret value

{% highlight hcl %}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}
{% endhighlight %}

This is the mainline pattern and it works everywhere, but be clear-eyed about what it does: `secret_string` writes the plaintext value into the Terraform state file as an attribute of this resource. Marking the variable `sensitive = true` only suppresses it from CLI output (`terraform plan`/`apply` logs) — it does nothing to protect the value once it's in `terraform.tfstate`. We'll come back to this properly in the security considerations section, because it's the same problem I've flagged in the GCP and OCI secrets posts on this blog, and the mitigations rank differently depending on your Terraform version.

If you're running Terraform >= 1.11, there's a better option: `secret_string_wo`, a **write-only** attribute. Write-only attributes are never persisted to state at all — Terraform sends the value during apply and then forgets it, tracked instead by a companion version counter:

{% highlight hcl %}
resource "aws_secretsmanager_secret_version" "db_password_wo" {
  secret_id                = aws_secretsmanager_secret.db_password.id
  secret_string_wo         = var.db_password
  secret_string_wo_version = 1 # bump this integer to push a new value
}
{% endhighlight %}

I'm keeping `secret_string` as the mainline example in this post because a lot of pipelines — Academy environments included — are still pinned to older Terraform versions, and `secret_string_wo` simply isn't available there. If you're on 1.11+, prefer it.

### The centerpiece: a resource policy that restricts LabRole

This is where the actual least-privilege work happens. We build the policy document with `aws_iam_policy_document` rather than hand-rolled JSON — it's less error-prone, and Terraform will catch structural mistakes at plan time that a raw JSON string wouldn't.

{% highlight hcl %}
data "aws_iam_policy_document" "db_password_resource_policy" {
  statement {
    sid    = "AllowLabRoleReadCurrentVersion"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.lab_role_arn]
    }

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [aws_secretsmanager_secret.db_password.arn]

    condition {
      test     = "StringEquals"
      variable = "secretsmanager:VersionStage"
      values   = ["AWSCURRENT"]
    }
  }
}

resource "aws_secretsmanager_secret_policy" "db_password" {
  secret_arn          = aws_secretsmanager_secret.db_password.arn
  policy              = data.aws_iam_policy_document.db_password_resource_policy.json
  block_public_policy = true
}
{% endhighlight %}

Walk through what this actually buys you:

The `Allow` statement grants `LabRole` — and only `LabRole`, referenced by its full ARN — the ability to call `GetSecretValue` and `DescribeSecret` on this one secret. Nothing broader. Even though `LabRole`'s identity policy might allow it to touch every secret in the account, this resource policy is the only thing standing between `LabRole` and this specific secret, and it says "current version only, this action set only."

The `secretsmanager:VersionStage` condition is what makes this genuinely restrictive rather than decorative. Secrets Manager labels versions with stages — `AWSCURRENT` is the active one, `AWSPREVIOUS` is whatever was current before the last update. Constraining the condition to `AWSCURRENT` means this principal can read the live value but not roll back to an older one by explicitly requesting a previous stage. Without it, anyone who can call `GetSecretValue` at all can also request `--version-stage AWSPREVIOUS` and read whatever the secret used to be.

`block_public_policy = true` turns on a genuinely useful AWS-specific guardrail: Secrets Manager runs your resource policy through Zelkova, AWS's automated reasoning engine, and rejects the `apply` outright if the policy would grant access to `Principal: "*"` or otherwise make the secret effectively public. Neither GCP Secret Manager's IAM-binding model nor OCI Vault's compartment-scoped policies run a formal-verification pass like this before accepting a policy. Leave it on by default — it only ever catches a mistake before it reaches production.

One gotcha worth flagging explicitly: Terraform will happily let you set `policy = "{}"` at plan time — it's syntactically valid JSON — but the Secrets Manager API rejects it on apply. A resource policy needs at least one statement; there's no such thing as an "empty but present" resource policy.

### Advanced variant: restricting by VPC endpoint (optional)

If your workload calls Secrets Manager exclusively from inside a VPC through a Secrets Manager VPC endpoint (a `com.amazonaws.<region>.secretsmanager` interface endpoint), you can add a second statement that denies any request not coming through that specific endpoint. This is a genuinely stronger control — it collapses the attack surface down to "traffic that transited this one endpoint" — but it has a hard prerequisite: **the VPC endpoint has to already exist**. Academy lab VPCs frequently don't ship with one by default, and creating a `aws_vpc_endpoint` resource of your own may or may not be within what your lab session permits.

Treat this as the advanced path, not the mainline one:

{% highlight hcl %}
variable "secretsmanager_vpc_endpoint_id" {
  description = "VPC endpoint ID for Secrets Manager, if one exists in this VPC. Leave empty to skip this control."
  type        = string
  default     = ""
}

data "aws_iam_policy_document" "db_password_resource_policy_with_vpce" {
  source_policy_documents = [data.aws_iam_policy_document.db_password_resource_policy.json]

  statement {
    sid    = "DenyOutsideVpcEndpoint"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = [local.lab_role_arn]
    }

    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_password.arn]

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"
      values   = [var.secretsmanager_vpc_endpoint_id]
    }
  }
}

resource "aws_secretsmanager_secret_policy" "db_password_vpce" {
  count = var.secretsmanager_vpc_endpoint_id != "" ? 1 : 0

  secret_arn          = aws_secretsmanager_secret.db_password.arn
  policy              = data.aws_iam_policy_document.db_password_resource_policy_with_vpce.json
  block_public_policy = true
}
{% endhighlight %}

This is an explicit `Deny`, not a second `Allow` — a `Deny` anywhere always wins, so this statement just carves out an exception on top of the existing grant. The `count` guard means the resource simply doesn't get created if you haven't supplied a VPC endpoint ID, so this block can stay in your module without breaking environments that don't have one.

If you want to check whether your lab VPC already has a Secrets Manager endpoint before wiring this up:

{% highlight bash %}
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.us-east-1.secretsmanager" \
  --query 'VpcEndpoints[].VpcEndpointId' --output text
{% endhighlight %}

If that comes back empty, skip this section entirely — the `VersionStage` condition from the mainline example is already doing real work on its own.

## Testing and validation

Apply the configuration, then work through both a positive and a negative test. This is the part that actually proves the resource policy is doing something, rather than just existing.

### Confirm the secret and its encryption key

{% highlight bash %}
aws secretsmanager describe-secret \
  --secret-id app/production/db-password \
  --region us-east-1 \
  --query '{Name:Name, ARN:ARN, KmsKeyId:KmsKeyId, LastChangedDate:LastChangedDate}'
{% endhighlight %}

`KmsKeyId` should come back empty or reference the default `aws/secretsmanager` alias — confirming encryption at rest is active without you having configured anything.

### Confirm the resource policy is attached

{% highlight bash %}
aws secretsmanager get-resource-policy \
  --secret-id app/production/db-password \
  --region us-east-1 \
  --query 'ResourcePolicy' --output text | jq .
{% endhighlight %}

You should see the `Allow` statement scoped to your `LabRole` ARN, with the `VersionStage` condition intact. If this comes back empty, the `aws_secretsmanager_secret_policy` resource either wasn't applied or was rejected — check `terraform apply` output for a Zelkova rejection.

### Positive test: read from an EC2 instance running LabInstanceProfile

Launch (or use an existing) EC2 instance with `LabInstanceProfile` attached — this is the instance profile wrapping `LabRole` that Academy provides for compute. From a shell on that instance:

{% highlight bash %}
aws secretsmanager get-secret-value \
  --secret-id app/production/db-password \
  --region us-east-1 \
  --query SecretString --output text
{% endhighlight %}

This should return the plaintext value you set via `TF_VAR_db_password`. No static credentials on the instance — it's using the instance profile's temporary credentials, and the resource policy is explicitly granting `LabRole` (which is what `LabInstanceProfile` assumes) read access to `AWSCURRENT`.

### Negative test: request a version stage the policy doesn't allow

This is the useful part, because in an Academy lab you don't have a second identity to test with — everyone is `LabRole`. Instead, prove the condition is real by violating it directly. First, push a new version so a previous one exists to violate the condition against:

{% highlight bash %}
aws secretsmanager put-secret-value \
  --secret-id app/production/db-password \
  --secret-string "rotated-test-value" \
  --region us-east-1
{% endhighlight %}

This creates a new `AWSCURRENT` and demotes the old value to `AWSPREVIOUS`. Now try to read the previous stage explicitly:

{% highlight bash %}
aws secretsmanager get-secret-value \
  --secret-id app/production/db-password \
  --version-stage AWSPREVIOUS \
  --region us-east-1 \
  --query SecretString --output text
{% endhighlight %}

This should fail, and the error text names the exact mechanism:

{% highlight text %}
An error occurred (AccessDeniedException) when calling the GetSecretValue operation:
User: arn:aws:sts::123456789012:assumed-role/LabRole/i-0abcd1234ef567890 is not authorized
to perform: secretsmanager:GetSecretValue on resource: app/production/db-password
because no resource-based policy allows the secretsmanager:GetSecretValue action
{% endhighlight %}

That message is the dual-layer model made visible: `LabRole`'s identity policy is broad enough that AWS doesn't even complain about the identity side — the failure is specifically "no resource-based policy allows" this request, because the `VersionStage` condition doesn't match `AWSPREVIOUS`. The compensating control is working exactly as designed.

If you have a real second principal available — a different IAM role in a different account, for a genuine cross-account test — running the same `get-secret-value` call from that identity against `AWSCURRENT` will fail the same way, for the same underlying reason: it's simply not named in the policy's `principals` block.

### Reading the secret from application code

The CLI is fine for verification; real workloads use an SDK. Here's the boto3 equivalent, which respects the same instance-profile credentials and the same resource policy:

{% highlight python %}
import boto3
from botocore.exceptions import ClientError


def get_secret(secret_id: str, region: str = "us-east-1") -> str:
    client = boto3.client("secretsmanager", region_name=region)
    try:
        response = client.get_secret_value(SecretId=secret_id)
    except ClientError as e:
        raise RuntimeError(f"Unable to retrieve secret '{secret_id}': {e}") from e
    return response["SecretString"]


if __name__ == "__main__":
    db_password = get_secret("app/production/db-password")
    print(f"Secret retrieved successfully (length: {len(db_password)})")
{% endhighlight %}

No credentials are configured anywhere in this script — boto3 picks up the instance profile's temporary credentials automatically, the same identity chain used by the CLI test above. Run it from anywhere other than an instance carrying `LabInstanceProfile` and it fails with the same `AccessDeniedException`.

## Security considerations

A few points worth internalizing before you take this pattern into a real environment:

**Don't treat this as an Academy-only trick.** The moment you can't edit an identity policy — a role owned by another team, a role in an account you don't administer, an SCP-locked environment where a platform team owns every IAM change — this pattern is your answer. Never assume an identity policy you *do* control is narrow enough on its own, either; the resource policy is a second, independent line of defense worth keeping regardless.

**Leave `block_public_policy = true` on by default.** There is essentially no legitimate reason for a secret's resource policy to grant `Principal: "*"`, and the cost of this check is zero — it only ever blocks a mistake.

**Watch for the confused deputy problem if you extend this to service principals.** Everything here grants access to an IAM role. If you later grant a resource policy statement to an AWS *service* principal instead — say, via CloudFormation or EventBridge — add `aws:SourceArn` and/or `aws:SourceAccount` conditions. Without them, any customer's resource of that service type, in any account, could potentially trigger access to your secret. Not a concern for the LabRole example above, but the natural next mistake once you start granting to services instead of roles.

**Rank your state-exposure mitigations correctly.** `secret_string` writes plaintext into `terraform.tfstate`. In descending order of how well each option actually protects that value:

1. **`secret_string_wo`** (Terraform >= 1.11) — the value is never written to state at all. The strongest option, when your Terraform version supports it.
2. **Separate-lifecycle pattern** — Terraform manages only the secret container and the resource policy; a CI/CD pipeline step (or a person) writes the actual value afterward with `aws secretsmanager put-secret-value`, outside of Terraform's state entirely. This works on any Terraform version and is the right call for teams not yet on 1.11.
3. **`sensitive = true`** — the weakest of the three. It suppresses the value from `plan`/`apply` console output, but does nothing about the state file itself. Anyone with read access to your state backend can extract the value with `terraform state show` or `terraform output -json` (if surfaced as an output). Don't mistake this flag for actual protection.

Same tradeoff I've walked through for GCP Secret Manager and OCI Vault on this blog — the underlying problem, Terraform state as a plaintext secret store, is universal across providers; only the mitigation names differ.

**CIS AWS Foundations Benchmark alignment.** Two relevant controls fall directly out of what we built here: secrets must not be publicly accessible (covered by `block_public_policy = true`, verified automatically at apply time rather than by manual audit), and secrets must be encrypted at rest (Secrets Manager gives you this by default, with no opt-out — there's no equivalent of an "unencrypted secret" resource to accidentally create). If you want those checks tracked centrally rather than verified ad hoc, see the [AWS Security Hub with Terraform post](/aws-security-hub-terraform/) on this blog for wiring findings like these into a single dashboard.

**One more thing worth knowing, briefly:** AWS's Security Blog covered Secrets Manager adopting post-quantum TLS (ML-KEM key exchange) for the transport layer in April 2026. It doesn't change anything about how you write Terraform or design resource policies — it's a transport-layer upgrade AWS rolls out transparently — but it's a good signal that Secrets Manager's underlying infrastructure is actively hardened, not a static service you're trusting blindly.

## How this compares to GCP and OCI's secret models

If you've read the [OCI Vault post](/oci-vault-secrets-management-terraform/) or the [GCP Secret Manager post](/gcp-secret-manager-terraform/) on this blog, the access-control model here should feel meaningfully different, not just relabeled.

GCP Secret Manager and OCI Vault both center on **IAM-binding models**: you grant a principal a role scoped to a secret (`google_secret_manager_secret_iam_member` on GCP — see the [GCP IAM Terraform post](/gcp-iam-fundamentals-terraform/) for how those role bindings and service accounts are built) or write a compartment-scoped policy statement (`Allow group ... to read secret-bundles in compartment ...` on OCI). The access grant lives entirely on the identity side — there's no separate "policy that lives on the secret itself" layer standing apart from IAM.

AWS's dual-layer model is genuinely different: the resource carries its own policy, evaluated alongside the identity's policy, not instead of it. That's the specific feature that makes the LabRole problem solvable at all. If AWS worked like GCP or OCI, an unmodifiable `LabRole` would be a dead end — no lever anywhere to narrow it. The resource-based policy is that lever.

## Wrapping up

We built a Secrets Manager secret from scratch with Terraform — the container, a securely-sourced value, and a resource policy that genuinely restricts what an identity we don't control is allowed to do. The `VersionStage` condition, `block_public_policy`, and the `aws_caller_identity` lookup for a dynamic role ARN are the pieces that turn "attach some JSON to the secret" into an actual least-privilege control, verified with both a positive read from an EC2 instance and a negative test that fails for exactly the reason we designed it to.

What we didn't touch — on purpose — is rotation. Creating a secret and locking down read access is only half the lifecycle; keeping that secret's value fresh automatically, with a Lambda rotation function and the `aws_secretsmanager_secret_rotation` resource, is a large enough topic to deserve its own post. That's next.

Happy scripting!
