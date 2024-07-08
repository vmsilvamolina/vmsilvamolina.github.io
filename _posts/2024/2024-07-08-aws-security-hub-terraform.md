---
title: "AWS Security Hub: centralizing findings with Terraform"
author: Victor Silva
date: 2024-07-08T19:47:50+00:00
layout: post
permalink: /aws-security-hub-terraform/
excerpt: "Security findings scattered across GuardDuty, Inspector, Macie, and Config are hard to act on when they live in separate consoles. AWS Security Hub pulls them into a single pane with normalized severity scoring and compliance standard checks. This post walks through enabling it with Terraform, subscribing to CIS and AWS Foundational standards, and routing findings to SNS for real alerting."
categories:
  - Cloud Security
tags:
  - aws
  - security-hub
  - terraform
  - cloud-security
  - findings
---

When you start enabling AWS security services across an account, you quickly run into a coordination problem. GuardDuty is generating threat detections in one console. Inspector is flagging EC2 and ECR vulnerabilities in another. Config is reporting resource misconfigurations somewhere else. Macie has its own S3 data findings. Each service uses different severity labels, different finding schemas, and different notification mechanisms. If you want to know whether your account is in a good state right now, you are context-switching between four different UIs and trying to mentally normalize what HIGH means in GuardDuty versus CRITICAL in Inspector.

AWS Security Hub solves this. It is a regional aggregation service that ingests findings from AWS-native services and third-party tools, normalizes them to the AWS Security Finding Format (ASFF), scores them against compliance standards, and gives you a single place to triage, suppress, and route findings. In this post I will walk through enabling Security Hub with Terraform, subscribing to the CIS AWS Foundations Benchmark and AWS Foundational Security Best Practices standards, aggregating findings across regions, and routing high-severity findings to SNS so you actually get notified when something breaks.

## How Security Hub Organizes Work

Before writing any Terraform, it is worth understanding the three layers Security Hub operates at, because they map directly to the resources you will create.

**Finding ingestion** — Security Hub receives findings from integrated services (GuardDuty, Inspector, Macie, Config, Firewall Manager) and normalizes them to ASFF. You do not configure this per-service; enabling Security Hub and enabling the integration for each service is enough. Each finding gets a normalized `Severity.Label` (INFORMATIONAL, LOW, MEDIUM, HIGH, CRITICAL) regardless of what the originating service called it.

**Compliance standards** — Security Hub runs automated checks against enabled standards. Each standard contains controls mapped to AWS Config rules. When a control check fails, Security Hub generates a finding. The two most commonly enabled standards are the CIS AWS Foundations Benchmark (v1.4.0 or v3.0.0) and the AWS Foundational Security Best Practices (FSBP). Both cover overlapping territory but from different angles — CIS focuses on account-level configuration hygiene, FSBP is broader and covers individual service configurations.

**Findings aggregation** — By default, Security Hub is regional. Findings generated in `us-east-1` do not appear in `eu-west-1`. If you operate in multiple regions, you can designate one region as the aggregation region and link the others to it. All findings flow to the aggregation region, and you manage everything from one place. This is the configuration most multi-region accounts should use.

## Prerequisites

To follow along you will need:

- Terraform 1.3 or later
- The `aws` provider version 5.x — the `aws_securityhub_standards_subscription` resource has been stable since 4.x, but 5.x is recommended
- An AWS account with permissions to enable Security Hub (`securityhub:EnableSecurityHub`), create EventBridge rules, and create SNS topics — `SecurityAudit` plus `AmazonSNSFullAccess` is sufficient for this post, though a tighter set of permissions is better for production
- AWS CLI configured and authenticated, so you can verify findings after setup

Verify your provider version and authentication:

{% highlight bash %}
terraform version
aws sts get-caller-identity
{% endhighlight %}

## Implementation

### Part 1 - Enabling Security Hub

The entry point is `aws_securityhub_account`. This resource enables Security Hub in the current region for the current account. It has very few arguments — most Security Hub configuration lives in separate resources.

Create `securityhub.tf`:

{% highlight hcl %}
resource "aws_securityhub_account" "main" {
  enable_default_standards = false

  control_finding_generator = "SECURITY_CONTROL"

  auto_enable_controls = true
}
{% endhighlight %}

Two decisions here worth explaining.

`enable_default_standards = false` tells Security Hub not to automatically subscribe to the AWS Foundational Security Best Practices and CIS standards when the account is first enabled. If you leave this at `true`, Terraform did not create those subscriptions and does not know about them — they exist outside your state. Subsequent `terraform plan` runs will show no drift, but you have orphaned resources that you cannot manage declaratively. Setting it to `false` and creating the subscriptions explicitly is the correct pattern.

`control_finding_generator = "SECURITY_CONTROL"` is the newer finding generator mode introduced in late 2022. In this mode, Security Hub consolidates findings for the same control across multiple standards into a single finding. In the older `STANDARD_CONTROL` mode, enabling a control in both CIS and FSBP would generate two separate findings for the same resource. The consolidated mode reduces noise significantly in accounts that run multiple standards.

`auto_enable_controls = true` means that when you add a new standards subscription and that standard later releases new controls, those controls are automatically enabled. Without this, new controls in a standard you already subscribe to start disabled and you have to manually enable them — which defeats the purpose of a compliance standard subscription.

### Part 2 - Subscribing to Compliance Standards

Add the standard subscriptions to `securityhub.tf`. Each subscription is its own resource and references a standard ARN:

{% highlight hcl %}
resource "aws_securityhub_standards_subscription" "cis_v140" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
}
{% endhighlight %}

The `depends_on` is required here. Security Hub must be fully enabled before you can subscribe to standards. Without the explicit dependency, Terraform may attempt to create the subscription concurrently with the account enablement, which fails with an error indicating Security Hub is not yet active.

The standard ARNs use `::` (double colon with no account ID) because these are AWS-managed standard definitions, not account-specific resources. The region component is variable because standards subscriptions are regional — you will need to create these in each region where you run Security Hub.

Add the region variable to `variables.tf` if it does not already exist:

{% highlight hcl %}
variable "aws_region" {
  type        = string
  description = "AWS region where Security Hub is being configured"
  default     = "us-east-1"
}
{% endhighlight %}

### Part 3 - Multi-Region Aggregation

If you run workloads in more than one region, set up finding aggregation so everything flows to a single region. The aggregation is configured from the aggregation region — you run this block in the region you want to be the hub:

{% highlight hcl %}
resource "aws_securityhub_finding_aggregator" "main" {
  depends_on   = [aws_securityhub_account.main]
  linking_mode = "ALL_REGIONS"
}
{% endhighlight %}

`linking_mode = "ALL_REGIONS"` automatically includes all current and future regions where Security Hub is enabled in your account. If you prefer an explicit allowlist, use `SPECIFIED_REGIONS` and provide a `specified_regions` list. The `ALL_REGIONS` mode is simpler to maintain because new regions you enable are included automatically, but it does mean you need Security Hub enabled in those regions before findings will flow.

For the linked (non-aggregation) regions, you deploy the same `aws_securityhub_account` and `aws_securityhub_standards_subscription` resources using a provider alias:

{% highlight hcl %}
provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

resource "aws_securityhub_account" "eu_west_1" {
  provider                 = aws.eu_west_1
  enable_default_standards = false
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls     = true
}

resource "aws_securityhub_standards_subscription" "fsbp_eu" {
  provider      = aws.eu_west_1
  depends_on    = [aws_securityhub_account.eu_west_1]
  standards_arn = "arn:aws:securityhub:eu-west-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}
{% endhighlight %}

Once the aggregator is active and the linked regions are enabled, findings from `eu-west-1` appear in the Security Hub console of your aggregation region within a few minutes.

### Part 4 - Routing Findings to SNS via EventBridge

Security Hub does not natively send email or Slack notifications. The standard pattern is to use Amazon EventBridge to match Security Hub findings and route them to SNS, which then delivers to subscribers. This is where having a real alerting path rather than a dashboard you remember to check comes from.

Create `alerting.tf`:

{% highlight hcl %}
resource "aws_sns_topic" "security_hub_findings" {
  name              = "security-hub-high-critical-findings"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.security_hub_findings.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_event_rule" "security_hub_high_critical" {
  name        = "security-hub-high-critical-findings"
  description = "Capture Security Hub findings with severity HIGH or CRITICAL"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
        RecordState = ["ACTIVE"]
        WorkflowState = ["NEW"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.security_hub_high_critical.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_hub_findings.arn

  input_transformer {
    input_paths = {
      account     = "$.detail.findings[0].AwsAccountId"
      region      = "$.detail.findings[0].Region"
      title       = "$.detail.findings[0].Title"
      severity    = "$.detail.findings[0].Severity.Label"
      description = "$.detail.findings[0].Description"
      remediation = "$.detail.findings[0].Remediation.Recommendation.Text"
      findingUrl  = "$.detail.findings[0].Remediation.Recommendation.Url"
    }
    input_template = <<-EOT
      "Security Hub Finding"
      "Account: <account> | Region: <region>"
      "Severity: <severity>"
      "Title: <title>"
      "Description: <description>"
      "Remediation: <remediation>"
      "Reference: <findingUrl>"
    EOT
  }
}

resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.security_hub_findings.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.security_hub_findings.arn
      }
    ]
  })
}
{% endhighlight %}

Add the variable to `variables.tf`:

{% highlight hcl %}
variable "alert_email" {
  type        = string
  description = "Email address to receive HIGH and CRITICAL Security Hub findings"
}
{% endhighlight %}

The EventBridge rule filters on three conditions: severity label must be `HIGH` or `CRITICAL`, record state must be `ACTIVE` (not archived), and workflow state must be `NEW`. The `WorkflowState = ["NEW"]` filter is important — without it, every time a finding is updated (for example, when you suppress it), EventBridge fires again and you get a second notification for something you are already aware of. Filtering to `NEW` means you get one notification per new finding.

The `input_transformer` extracts the most actionable fields from the raw ASFF JSON and formats them into a readable message. Raw ASFF events are several kilobytes of JSON — nobody wants that in an email. The transformer pulls account ID, region, title, severity, description, and remediation recommendation into a concise notification.

The SNS topic policy is required. By default, EventBridge cannot publish to an SNS topic because the topic's resource-based policy does not allow it. The `AllowEventBridgePublish` statement grants the `events.amazonaws.com` service principal permission to call `SNS:Publish` on this specific topic.

## Testing and Validation

After running `terraform apply`, confirm the stack is wired up correctly before relying on it.

Check that Security Hub is enabled and standards are active:

{% highlight bash %}
aws securityhub describe-hub --region us-east-1

aws securityhub get-enabled-standards --region us-east-1 \
  --query "StandardsSubscriptions[].{Arn:StandardsArn,Status:StandardsStatus}" \
  --output table
{% endhighlight %}

Both standards should show `READY` status. If a subscription shows `INCOMPLETE`, Security Hub is still running the initial compliance checks — wait a few minutes and query again.

Verify the finding aggregator is active:

{% highlight bash %}
aws securityhub list-finding-aggregators --region us-east-1 \
  --query "FindingAggregators[].FindingAggregatorArn" \
  --output text
{% endhighlight %}

Generate a test finding to validate the EventBridge-to-SNS path. Security Hub provides a built-in sample findings generator:

{% highlight bash %}
aws securityhub create-sample-findings --region us-east-1
{% endhighlight %}

This creates one sample finding for each enabled integration type. The sample findings are created with `CRITICAL` severity and `NEW` workflow state, so they will match your EventBridge rule. Within 1-2 minutes you should receive an email notification at the address you subscribed. If no email arrives, check the EventBridge rule's monitoring tab for invocation count and the SNS subscription's confirmation status — a subscription must be confirmed (by clicking the link in the confirmation email) before it delivers messages.

Check how many active findings exist after the sample generation:

{% highlight bash %}
aws securityhub get-findings \
  --filters '{"RecordState":[{"Value":"ACTIVE","Comparison":"EQUALS"}],"SeverityLabel":[{"Value":"CRITICAL","Comparison":"EQUALS"}]}' \
  --query "Findings | length(@)" \
  --output text
{% endhighlight %}

You can also query the compliance summary for your enabled standards to see how many controls are passing:

{% highlight bash %}
aws securityhub get-insights-results \
  --insight-arn "arn:aws:securityhub:::insight/securityhub/default/17" \
  --region us-east-1
{% endhighlight %}

Insight 17 is the built-in "Top resources by counts of failed CIS requirements" insight. The built-in insights are useful for a quick overview without building custom queries.

## Best Practices

**Disable controls you cannot remediate before you can remediate them.** When you first enable a standard in an existing account, you will have a wave of failing controls from historic configuration drift. Suppress or disable controls for findings you have documented exceptions for, rather than leaving a 30% compliance score sitting in the dashboard permanently. A suppressed finding with a reason and an expiry note is better than a 30% score that nobody takes seriously.

**Use `SECURITY_CONTROL` mode, not `STANDARD_CONTROL`.** The consolidated finding mode reduces noise in accounts running multiple standards. A single control failure generates one finding regardless of how many standards reference that control. This is the default for new accounts but older accounts may still be in `STANDARD_CONTROL` mode. Check your existing configuration and migrate if needed — it requires re-enabling Security Hub in older accounts.

**Filter EventBridge rules on `WorkflowState = NEW`.** Without this filter, updating a finding (suppressing it, changing its status) retriggers the EventBridge rule and sends a duplicate notification. This is the most common reason teams end up with noisy alerting and start ignoring Security Hub emails.

**Tag your SNS topic and EventBridge rule with the owning team.** Security Hub findings cross service boundaries. A GuardDuty finding about unusual EC2 behavior might be relevant to the platform team, while a Macie finding about S3 bucket permissions is relevant to the data team. If your organization routes SNS by tag or uses a findings management platform (Jira, PagerDuty), tagging early saves time when you need to route findings to the right queue later.

**Enable Security Hub in all regions, even unused ones.** An attacker who compromises your account may spin up resources in a region you do not normally monitor. If Security Hub is not enabled there, GuardDuty detections in that region never appear in your hub. The cost of enabling Security Hub in idle regions is minimal — you pay per finding, and an idle region generates very few findings. The cost of missing detections in an unmonitored region is much higher.

**Automate finding suppression for known-good configurations.** If your architecture has a legitimate reason for a specific finding to exist — for example, an S3 bucket that intentionally has no lifecycle policy because it is a compliance archive — suppress it programmatically using `aws_securityhub_insight` or the `aws_securityhub_automation_rule` resource (available in provider 5.x). Manual suppression in the console does not survive Security Hub being re-enabled and is not tracked in version control.

## Conclusion

After applying this Terraform configuration, you have Security Hub enabled with consolidated finding generation, both CIS v1.4.0 and FSBP standards running automated checks, finding aggregation pulling results from all linked regions into a single view, and HIGH and CRITICAL findings routed through EventBridge to SNS with a human-readable notification format.

The next steps from here depend on your operational model. If you are in an AWS Organizations setup, look at the Security Hub delegated administrator feature — it lets you enable Security Hub across all member accounts from a single management account and aggregate findings centrally without configuring each account independently. If you want to go deeper on finding automation, the `aws_securityhub_automation_rule` resource lets you define suppression and enrichment rules as code, so your known-good exceptions are tracked in Terraform rather than clicked into a console.

Happy scripting!
