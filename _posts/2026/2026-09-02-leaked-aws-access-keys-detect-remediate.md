---
title: 'Leaked AWS Access Keys: Detect, Contain, Eliminate'
author: Victor Silva
date: 2026-09-02T21:06:16+00:00
layout: post
permalink: /leaked-aws-access-keys-detect-remediate/
excerpt: "Truffle Security found 9,300 leaked AWS access keys still work. Detect exposed IAM credentials in CI, run the IR runbook, replace static keys with OIDC."
categories:
  - AWS
  - Security
tags:
  - AWS
  - IAM
  - Secret Scanning
  - Incident Response
  - Credential Hygiene
  - GuardDuty
  - OIDC
---

On 21 August 2026, BleepingComputer and Infosecurity Magazine picked up research from Truffle Security that should make anyone running an AWS account uncomfortable. Truffle scanned public artifacts and pulled out **64,024 unique AWS key pairs** across **431,875 public findings**. They then re-verified a sample of 10,616 complete pairs against AWS on 10 August 2026, and **roughly 88% of them (9,308 keys) still authenticated**. These are not honeypots or expired test credentials. They are leaked AWS access keys and exposed IAM credentials that still open a live door into someone's account, years after they were first pushed somewhere public.

There is no CVE for this. Nothing needs patching. This is credential hygiene, not a software vulnerability, which is exactly why it keeps happening and why no vendor advisory is going to save you. The fix is operational: find the keys before someone else does, kill them safely without torching your billing concession, and stop minting long-lived keys in the first place.

This post is a practical detect-remediate-prevent guide: why long-lived keys keep leaking, what AWS does automatically when it spots one of yours (and the sharp edges of that automation), how to catch keys in CI/CD before they ship, a scripted incident-response runbook, the detection engineering to alert on abuse, and the guardrails that make the whole class of problem go away.

## What the numbers actually say

A few figures from the research are worth pinning down, because the secondary coverage blurs them together:

- Of the still-live keys, **768 gave full account control**: 526 were root-user keys and 242 were IAM users carrying `AdministratorAccess`. (Separately, 817 keys were attributable to an identifiable business overall — that is a different count, not the sum of the two above.)
- The **median age of a still-live key was about five years**. The oldest still authenticating was **17.4 years old**.
- Across the full 64,024-key set, roughly **10,625 were root-account keys (16.6%)** — a different, larger population than the 10,616 pairs Truffle re-verified, so don't conflate the two.
- Of the accounts Truffle could read into, only about **9.5% (262 of 2,754) had any budget configured at all**. Median configured limit: single digits of dollars. A cryptomining or Bedrock-abuse spree runs for days before anyone notices.
- The leak surface has moved. It used to be `git push` accidents. Now the majority of exposures — more than 90% by some counts — come from the **AI/ML supply chain**: Hugging Face datasets, model repos and notebooks (the single largest source), Docker image layers, and CI logs.

## Why long-lived keys keep leaking

An AWS access key for an IAM user is a static pair: a 20-character `AKIA...` access key ID and a 40-character secret. It has no expiry. It is valid from the moment it is created until someone explicitly sets it to `Inactive` or deletes it. Nothing about the passage of time weakens it. A key minted in 2009 works in 2026 if nobody touched it — and Truffle's data says most people never did. Around **86% of the enumerable leaked keys had never been rotated or cleaned up**.

The reason the AI/ML surface is so productive for scanners is that keys leak into *derived artifacts*, not just source:

- A Jupyter notebook committed to a model repo with the credential sitting in an **output cell** from a debugging `print(os.environ)` or a `boto3` traceback.
- A `~/.aws/credentials` file committed wholesale into a Hugging Face Space or dataset repo.
- A **Docker image layer** where the key was `COPY`'d in, then "removed" by a later `RUN rm` — except the earlier layer still contains it and `docker save` hands it right over.
- A CI job with `set -x` enabled that echoes `AWS_SECRET_ACCESS_KEY` into the build log, which is then published as a public artifact or attached to a public PR.

This is also why **rotation alone does not fix a leak**. Rotating the live key gives you a new secret, but it does absolutely nothing about the copy already sitting in a public artifact — that artifact is still public, and whatever else is in it (other keys, internal hostnames, tokens) is still exposed. Rotation is a hygiene cadence. It is not an incident response, and it is not a control.

## What AWS does automatically

AWS participates in GitHub's secret-scanning partner program: when GitHub's scanner spots an AWS key in a public commit, it notifies AWS. AWS also runs its own scanning against public sources. When either fires on one of your keys, two things happen.

First, AWS **attaches the `AWSCompromisedKeyQuarantineV3` managed policy** to the IAM principal that owns the key (`arn:aws:iam::aws:policy/AWSCompromisedKeyQuarantineV3`). This policy was created on 21 August 2024 and last edited 16 March 2026. Second, AWS opens a support case in your account describing what it found.

Here is the part people get wrong. **The quarantine policy does not disable the key and does not touch any existing resource.** It is a single explicit `Deny` statement over a curated list of high-blast-radius actions. The key still authenticates. Existing EC2 instances keep running. What the principal loses is the ability to *expand* the blast radius or *cover tracks*.

`V3` notably extended the denied set with AI-abuse actions that `V1` and `V2` did not cover — `bedrock:InvokeModel`, `bedrock:CreateModelInvocationJob`, `sagemaker:CreateEndpointConfig`, and `sagemaker:CreateProcessingJob` — because model-invocation abuse became a primary monetization path for stolen keys.

A representative slice of what `V3` denies, summarized by service:

- **EC2**: `RunInstances`, `StartInstances` (spin up mining fleets)
- **IAM**: essentially every `Create*`, `Attach*`, `Put*`, plus `CreateAccessKey`, `CreateLoginProfile`, `CreateUser`, `DeleteAccessKey`, `DeleteRole`
- **S3**: `GetObject`, `ListBucket`, `PutObject`, `DeleteObject`
- **CloudTrail**: `LookupEvents`, plus stop/delete on trails
- **Lambda**: `CreateFunction`, `UpdateFunctionCode`
- **Organizations**: `*`
- **Bedrock / SageMaker**: the model-invocation and job-creation actions listed above
- **STS**: `GetSessionToken`, `GetFederationToken`
- **KMS**: `ScheduleKeyDeletion`

That is a trimmed view — the full policy runs to around 90 actions. Don't try to memorize it; understand the shape.

**The gotcha to internalize:** because the policy denies `cloudtrail:LookupEvents`, `s3:GetObject`, `s3:ListBucket`, `iam:ListUsers`, `iam:DeleteAccessKey`, and `iam:DeleteRole`, **you cannot run your investigation or clean up IAM from the quarantined principal.** If your "admin" is the user that got quarantined, you are locked out of your own incident response. This is the entire reason the prerequisites below insist on a separate break-glass identity.

**And do not detach the quarantine policy until remediation is complete and the support case is resolved.** Detaching it early can forfeit the fraudulent-charge billing concession AWS may extend for abuse that happened while the key was exposed. The support case is the channel for that conversation — work it, don't short-circuit it.

## Prerequisites

- An **AWS account with CloudTrail enabled** across all regions, with log file validation turned on and events delivered to an S3 bucket you control.
- A **dedicated break-glass / incident-response admin role**, assumed on demand through IAM Identity Center — *not* a standing access key sitting in someone's `~/.aws/credentials`. This is the identity you run the runbook from.
- **AWS CLI v2** installed and configured to assume that role.
- **GuardDuty enabled** in every region you operate in.
- A **GitHub repository** for the CI examples.
- **Terraform ≥ 1.6** for the guardrail snippets.

Verify the basics:

{% highlight bash %}
aws --version                     # aws-cli/2.x
aws cloudtrail describe-trails --query 'trailList[].{Name:Name,MultiRegion:IsMultiRegionTrail,Validation:LogFileValidationEnabled}'
aws guardduty list-detectors --query 'DetectorIds'
aws sts get-caller-identity       # confirm you are the break-glass role, not a user key
{% endhighlight %}

## Detecting leaked AWS access keys in CI/CD

The cheapest place to catch a key is before the commit that leaks it ever lands. Layer three things.

### TruffleHog in GitHub Actions

TruffleHog v3 verifies candidate secrets by actually calling the provider, so an `AKIA` string that still authenticates is flagged as `verified` rather than guessed at.

{% highlight yaml %}
name: secret-scan
on:
  pull_request:
  push:
    branches: [main]

jobs:
  trufflehog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0          # full history so the diff scan has a base
      - name: TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --results=verified,unknown --fail
{% endhighlight %}

`--fail` makes the step exit non-zero on a finding. `--results=verified,unknown` keeps known-false-positive noise down while still surfacing anything it could not disprove.

TruffleHog also scans the two artifact types that dominate the current leak data. Point it at a built image or a Hugging Face org directly:

{% highlight bash %}
trufflehog docker --image ghcr.io/my-org/api:latest --results=verified
trufflehog huggingface --org my-ml-org --results=verified
{% endhighlight %}

If you publish images or model repos, wire those two commands into the same pipeline that builds them. The Docker scan walks every layer, so it catches the "removed in a later layer" case.

### Gitleaks and pre-commit

Gitleaks gives you a fast regex-and-entropy pass, both in CI and locally.

{% highlight yaml %}
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v3
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
{% endhighlight %}

The jump from `v2` to `v3` of the action is only a runtime bump — Node 20 to Node 24. It matters because GitHub is removing the Node 20 action runtime on 16 September 2026, so pinning `@v2` will start throwing deprecation warnings and then break.

Locally, stop the key before it is even committed:

{% highlight yaml %}
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
  - repo: local
    hooks:
      - id: trufflehog
        name: trufflehog (verified only)
        entry: bash -c 'trufflehog git file://. --since-commit HEAD --results=verified --fail'
        language: system
        pass_filenames: false
{% endhighlight %}

### GitHub secret scanning and push protection

For public repositories this is free, and for AWS keys **push protection is on by default**. When a developer tries to push a commit containing an `AKIA` key, GitHub blocks the push client-side with the offending file and line. It is the only control in this list that stops the leak before it touches the remote at all. Turn it on for private repos too if you have GitHub Advanced Security.

These scanners are the dedicated complement to a broader pipeline scanner. If you already run [Trivy in GitHub Actions](/trivy-github-actions-container-iac-scanning/) — which has its own secret scanner — keep it for the wide coverage and add TruffleHog/Gitleaks for verification depth and the Docker/Hugging Face surfaces.

## The incident-response runbook

You have confirmed a key is exposed. Run this from the **break-glass admin role**, not from the principal that owns the key. Every step keys off one variable.

{% highlight bash %}
#!/usr/bin/env bash
set -euo pipefail

KEY="AKIAEXAMPLE1234567890"                      # the exposed access key ID
USER=$(aws iam get-access-key-last-used --access-key-id "$KEY" \
  --query 'UserName' --output text)

echo "[1] Disabling key $KEY on user $USER (reversible, preserves it for correlation)"
aws iam update-access-key --user-name "$USER" --access-key-id "$KEY" --status Inactive

echo "[2] Revoking STS sessions minted from this key"
cat > /tmp/revoke-older-sessions.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": { "DateLessThan": { "aws:TokenIssueTime": "TOKEN_ISSUE_CUTOFF" } }
  }]
}
EOF
sed -i "s/TOKEN_ISSUE_CUTOFF/$(date -u +%Y-%m-%dT%H:%M:%SZ)/" /tmp/revoke-older-sessions.json
aws iam put-user-policy --user-name "$USER" \
  --policy-name AWSRevokeOlderSessions \
  --policy-document file:///tmp/revoke-older-sessions.json

echo "[3] Blast radius: management events tied to this key (last 90 days only)"
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="$KEY" \
  --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource,IP:CloudTrailEvent}' \
  --output json > blast-radius-$KEY.json

echo "[4] Persistence sweep across the account"
aws iam get-account-authorization-details > authz-details.json
aws iam list-users --query \
  'Users[?CreateDate>=`2026-08-01`].[UserName,CreateDate]' --output table
for u in $(aws iam list-users --query 'Users[].UserName' --output text); do
  aws iam list-access-keys --user-name "$u" \
    --query 'AccessKeyMetadata[].[UserName,AccessKeyId,Status,CreateDate]' --output text
  aws iam get-login-profile --user-name "$u" 2>/dev/null && echo "  ^ console login exists"
done
aws iam list-open-id-connect-providers
aws iam list-saml-providers
for r in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  aws ec2 describe-instances --region "$r" \
    --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType,LaunchTime]' \
    --output text
done
{% endhighlight %}

A few notes on that sequence. Step 1 **disables rather than deletes** — deletion is irreversible and destroys context you need for correlation; you delete at the very end. Step 2's `aws:TokenIssueTime` deny neutralizes any temporary credentials the attacker already minted with `sts:GetSessionToken`; without it, those sessions live until they expire. Step 3's `lookup-events` on `AccessKeyId` covers only the **last 90 days, management events only**, with a ~15-minute lag — a starting point, not the whole picture.

For anything older than 90 days, or for data events, query the CloudTrail log bucket directly with Athena:

{% highlight sql %}
-- Everything this key did, including data events and beyond the 90-day lookup window
SELECT eventtime, eventsource, eventname, awsregion,
       sourceipaddress, useragent, errorcode
FROM cloudtrail_logs
WHERE useridentity.accesskeyid = 'AKIAEXAMPLE1234567890'
  AND eventtime >= '2024-01-01T00:00:00Z'
ORDER BY eventtime;
{% endhighlight %}

{% highlight sql %}
-- Pivot on IAM persistence activity in the exposure window
SELECT eventtime, eventname, useridentity.arn AS actor,
       sourceipaddress,
       json_extract_scalar(requestparameters, '$.userName')  AS target_user,
       json_extract_scalar(requestparameters, '$.roleName')  AS target_role
FROM cloudtrail_logs
WHERE eventsource = 'iam.amazonaws.com'
  AND eventname IN ('CreateUser','CreateAccessKey','CreateLoginProfile',
                    'AttachUserPolicy','CreateRole','UpdateAssumeRolePolicy')
  AND eventtime BETWEEN '2026-07-01T00:00:00Z' AND '2026-08-20T00:00:00Z'
ORDER BY eventtime;
{% endhighlight %}

Only after remediation is complete **and the support case is resolved** do you finish the lifecycle: repoint the application at a role (see prevention, below), then delete the key and remove the temporary revoke policy.

{% highlight bash %}
aws iam delete-access-key --user-name "$USER" --access-key-id "$KEY"
aws iam delete-user-policy --user-name "$USER" --policy-name AWSRevokeOlderSessions
{% endhighlight %}

## Detection engineering: alert on abuse, not just on the leak

Scanning catches the leak. You also want an alert the moment a leaked key is *used* against you.

GuardDuty is the primary signal. The finding that fires for a leaked **long-lived IAM user key** is `CredentialAccess:IAMUser/CompromisedCredentials` — High severity, sourced from AWS threat intelligence, meaning AWS already knows that key pair is circulating.

Do not confuse it with `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.*`. That family is about **temporary** credentials from an EC2/ECS/Lambda role being used off-instance — a different attack, a different credential type. People conflate the two constantly.

Route both families to SNS with a prefix match:

{% highlight json %}
{
  "source": ["aws.guardduty"],
  "detail-type": ["GuardDuty Finding"],
  "detail": {
    "type": [
      { "prefix": "CredentialAccess:IAMUser/" },
      { "prefix": "UnauthorizedAccess:IAMUser/" }
    ]
  }
}
{% endhighlight %}

If GuardDuty is not enabled everywhere yet, a CloudTrail-only fallback still catches the persistence behavior a stolen key almost always produces:

{% highlight json %}
{
  "source": ["aws.iam"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["iam.amazonaws.com"],
    "eventName": ["CreateUser", "CreateAccessKey", "CreateLoginProfile",
                  "AttachUserPolicy", "AttachRolePolicy", "PutUserPolicy",
                  "CreateRole", "UpdateAssumeRolePolicy"]
  }
}
{% endhighlight %}

Test the whole path — rule, target, SNS delivery — without waiting for a real incident:

{% highlight bash %}
DETECTOR=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)
aws guardduty create-sample-findings --detector-id "$DETECTOR" \
  --finding-types "CredentialAccess:IAMUser/CompromisedCredentials"
{% endhighlight %}

For aggregation, [Security Hub with Terraform](/aws-security-hub-terraform/) collects the GuardDuty finding alongside the CIS Foundations checks in one place. And if a stolen key is turned against your EKS API server, the in-cluster analog is runtime detection — see [Falco runtime security for Kubernetes](/falco-runtime-security-kubernetes/) and [Falco rules with Sidekick alerting](/falco-rules-sidekick-alerting/) for catching the API calls that follow.

## Prevention: eliminate static keys

Every long-lived IAM user key you delete is one that can never leak. The replacement for CI is GitHub's OIDC provider federating into an IAM role — no secret stored anywhere.

{% highlight hcl %}
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "github_deploy" {
  name = "github-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Pin to one repo AND one ref. Never "repo:my-org/*".
          "token.actions.githubusercontent.com:sub" = "repo:my-org/my-repo:ref:refs/heads/main"
        }
      }
    }]
  })
}
{% endhighlight %}

The workflow side carries no credentials at all:

{% highlight yaml %}
permissions:
  id-token: write        # required to mint the OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deploy
          aws-region: us-east-1
          # no aws-access-key-id, no aws-secret-access-key
{% endhighlight %}

`configure-aws-credentials@v6` is the current major. `v6.0.0` was a breaking change on 4 February 2026 that needs a newer runner image — if you pinned an old runner, bump it in the same PR.

The same pattern covers the other credential-holders:

- **On-prem / non-AWS servers**: IAM Roles Anywhere with an X.509 trust anchor.
- **AWS workloads**: EC2 instance roles, IRSA, or EKS Pod Identity — never a key baked into an AMI or a Kubernetes Secret.
- **Humans**: `aws sso login` through IAM Identity Center, short-lived sessions only.

Then close the door behind you with an SCP that forbids new user keys except for a monitored break-glass role:

{% highlight json %}
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "NoNewUserKeys",
    "Effect": "Deny",
    "Action": "iam:CreateAccessKey",
    "Resource": "*",
    "Condition": {
      "StringNotLike": { "aws:PrincipalArn": "arn:aws:iam::*:role/BreakGlass*" }
    }
  }]
}
{% endhighlight %}

Sweep for the keys you already have with the credential report:

{% highlight bash %}
aws iam generate-credential-report >/dev/null
aws iam get-credential-report --query 'Content' --output text | base64 -d > report.csv
# Active keys not rotated in the last 90 days
awk -F, 'NR==1 || ($9=="true" && $10 < "'"$(date -u -d '90 days ago' +%Y-%m-%d)"'")' report.csv
{% endhighlight %}

Once CI keys are gone, application secrets should be fetched through the assumed role from a real secret store — see [AWS Secrets Manager with least-privilege Terraform](/aws-secrets-manager-terraform-least-privilege/). The same federation idea on another cloud is covered in [GCP Workload Identity Federation for GitHub Actions](/gcp-workload-identity-federation-github-actions/).

## Guardrails that make the class of bug disappear

**Kill root keys, then block root entirely.** No account should have root access keys. Beyond that, deny the root principal from doing anything through an SCP, and adopt AWS Organizations centralized root access management (GA in 2024) for the stronger version that removes root credentials from member accounts outright.

{% highlight json %}
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyRootPrincipal",
    "Effect": "Deny",
    "Action": "*",
    "Resource": "*",
    "Condition": {
      "StringLike": { "aws:PrincipalArn": "arn:aws:iam::*:root" }
    }
  }]
}
{% endhighlight %}

**AWS Config rules, via Terraform**, to catch drift back toward static keys:

{% highlight hcl %}
locals {
  key_hygiene_rules = {
    access-keys-rotated               = { maxAccessKeyAge = "90" }  # note: does NOT evaluate root
    iam-user-unused-credentials-check = { maxCredentialUsageAge = "45" }
    iam-user-no-policies-check        = {}
    iam-root-access-key-check         = {}
  }
}

resource "aws_config_config_rule" "key_hygiene" {
  for_each = local.key_hygiene_rules
  name     = each.key
  source {
    owner             = "AWS"
    source_identifier = upper(replace(each.key, "-", "_"))
  }
  input_parameters = length(each.value) > 0 ? jsonencode(each.value) : null
}
{% endhighlight %}

Two blind spots to know about. `access-keys-rotated` **does not evaluate the root user** — cover that with `iam-root-access-key-check`. And `iam-policy-no-statements-with-admin-access` only inspects **customer-managed** policies, so an IAM user with the AWS-managed `AdministratorAccess` policy attached is *not* flagged by it — which is exactly the shape of 242 of those full-control leaked keys.

**Budgets and Cost Anomaly Detection on every account.** Only 9.5% of the exposed accounts had a budget, and the median configured limit was a few dollars — useless against a Bedrock or mining spree that bills thousands per day. Set a real budget and let anomaly detection catch the spike shape:

{% highlight hcl %}
resource "aws_budgets_budget" "account" {
  name         = "account-monthly"
  budget_type  = "COST"
  limit_amount = "500"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["secops@example.com"]
  }
}

resource "aws_ce_anomaly_monitor" "account" {
  name              = "account-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "account" {
  name      = "account-anomaly-sub"
  frequency = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.account.arn]
  subscriber {
    type    = "EMAIL"
    address = "secops@example.com"
  }
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["100"]
    }
  }
}
{% endhighlight %}

**CIS AWS Foundations Benchmark mapping.** The controls above line up with: 1.4 (no root access keys), 1.12 (disable credentials unused ≥ 45 days), 1.13 (one active key per user), 1.14 (rotate keys ≤ 90 days), 1.15 (grant permissions through groups), and 1.16 (no inline or attached `*:*` policies on users).

## Testing and validation

Prove each layer actually fires.

**Push protection.** Add a file containing a well-known example pair and try to push:

{% highlight bash %}
printf 'aws_access_key_id=AKIAIOSFODNN7EXAMPLE\naws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY\n' > creds.txt
git add creds.txt && git commit -m "test" && git push
# expected: remote rejects the push, naming creds.txt and the line
{% endhighlight %}

**TruffleHog gate.** Commit a real-format `AKIA` string on a branch and open a PR — the `trufflehog` job must exit non-zero and block the merge.

**Quarantine policy behavior.** Attach `AWSCompromisedKeyQuarantineV3` to a throwaway sandbox user and confirm the split:

{% highlight bash %}
aws iam attach-user-policy --user-name sandbox-quarantine-test \
  --policy-arn arn:aws:iam::aws:policy/AWSCompromisedKeyQuarantineV3

# all four must return AccessDenied:
aws s3 ls
aws ec2 run-instances --image-id ami-0abcd1234 --instance-type t3.micro
aws iam create-access-key --user-name sandbox-quarantine-test
aws cloudtrail lookup-events --max-results 1

# this must still succeed — the key is not disabled:
aws sts get-caller-identity
{% endhighlight %}

**GuardDuty path.** Fire the sample finding from the detection section and confirm the EventBridge rule delivers to SNS and the message lands.

**OIDC cutover.** Run the federated workflow and check the logs show an assumed-role ARN (`arn:aws:sts::…:assumed-role/github-deploy/…`), then confirm the repository has zero `aws-access-key-id` / `aws-secret-access-key` secrets left in its settings.

**Config rules.** Point `access-keys-rotated` at an existing key older than 90 days and confirm it evaluates `NON_COMPLIANT`.

## Best practices

- Kill static IAM user keys. Every one you delete is one that can't leak.
- Federate everything: OIDC for CI, Roles Anywhere for on-prem, instance roles / IRSA / Pod Identity for workloads, IAM Identity Center for humans.
- Keep exactly one break-glass path, monitored, and deny `iam:CreateAccessKey` everywhere else.
- Block the root principal, and adopt centralized root access management.
- Put a real budget and Cost Anomaly Detection on every account — not a $10 budget, a real one.
- Run secret scanning in CI plus push protection, and scan Docker layers and Hugging Face repos, not just git.
- Keep the incident-response runbook scripted, in version control, and rehearsed — and run it from the break-glass identity, never the quarantined one.
- Do not detach `AWSCompromisedKeyQuarantineV3` until remediation is done and the support case is closed.
- Treat the AI/ML artifact surface — notebooks, output cells, image layers, CI logs — as first-class leak territory, exactly like source code.

## Conclusion

The detail from Truffle's research that should stick with you is not the 9,308 live keys. It is that the median one is **five years old and was never rotated**. A 90-day rotation cadence would not have helped: nobody was running it, and even if they had, the leaked copy in a public repo still authenticates the day after. Rotation cadences are hygiene theater when they are the only control. What actually closes this is credential *elimination*: federated, short-lived identities everywhere, one guarded break-glass path, root locked down, and a budget that notices when someone spends your money. Build that, and the next time a scanner emails you about a leaked key, it is a five-minute cleanup instead of a billing incident.

Happy scripting!
