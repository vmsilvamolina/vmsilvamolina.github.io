---
title: "GCP Security Command Center: automating findings with Cloud Functions"
author: Victor Silva
date: 2024-11-11T19:55:08+00:00
layout: post
permalink: /gcp-security-command-center-cloud-functions/
excerpt: "GCP Security Command Center surfaces misconfigurations and threats across your Google Cloud environment, but a finding sitting in a dashboard does not fix anything. This post walks through wiring SCC notifications to a Cloud Function via Pub/Sub so that a new HIGH or CRITICAL finding automatically triggers a Slack alert — and the response runs without anyone opening a console."
categories:
  - Cloud Security
tags:
  - gcp
  - security-command-center
  - cloud-functions
  - cloud-security
  - automation
---

Security Command Center can tell you that a Cloud Storage bucket in your production project is publicly readable, that a service account has owner-level permissions it should not have, or that a VM has a known exploitable vulnerability in its guest OS. What it cannot do out of the box is act on those findings automatically. The default workflow is: finding appears in the SCC dashboard, someone checks the dashboard, someone files a ticket, someone fixes the issue. The gap between "finding created" and "finding resolved" is entirely manual, and in practice it is measured in days, not minutes.

This post closes that gap. I will show you how to enable Security Command Center, configure a notification feed that publishes findings to a Pub/Sub topic, and deploy a Python Cloud Function that fires on every new HIGH or CRITICAL finding and sends a formatted alert to a Slack channel. All of it deployed with `gcloud`. By the end, a new critical misconfiguration in your GCP environment will reach your team in Slack within seconds of SCC detecting it.

## How SCC Notifications Work

Before writing any code it is worth understanding the data flow, because the architecture directly shapes the deployment steps.

```
SCC Finding (HIGH/CRITICAL)
        |
        v
  Notification Config
  (filter + Pub/Sub topic)
        |
        v
  Pub/Sub Topic
        |
        v
  Cloud Function (Pub/Sub trigger)
        |
        v
  Slack Webhook
```

Security Command Center evaluates your GCP resources continuously. When it creates or updates a finding that matches a notification config's filter, it publishes the finding as a JSON message to a Pub/Sub topic you specify. A Cloud Function with a Pub/Sub trigger picks up that message, parses it, and takes whatever action you define — in this case, posting to Slack.

The notification config is the key piece. It holds both the filter (which findings to publish) and the destination topic. You can have multiple notification configs pointing to different topics with different filters. A reasonable setup has one topic for HIGH/CRITICAL findings that pages the on-call channel, and a separate topic for MEDIUM and LOW findings that goes to a lower-noise review channel.

## Prerequisites

You will need:

- `gcloud` CLI installed and authenticated to the target project
- The Security Command Center API enabled — Standard or Premium tier (the free tier does not support notification configs)
- A Slack incoming webhook URL
- Python 3.11 or later for local testing
- The following IAM roles on the project or organization:
  - `roles/securitycenter.admin` to create notification configs
  - `roles/pubsub.admin` to create topics and subscriptions
  - `roles/cloudfunctions.admin` to deploy the function
  - `roles/iam.serviceAccountAdmin` to create the function's service account

Verify your active project and authentication:

{% highlight bash %}
gcloud config get-value project
gcloud auth list
{% endhighlight %}

Enable the required APIs if they are not already on:

{% highlight bash %}
gcloud services enable \
  securitycenter.googleapis.com \
  pubsub.googleapis.com \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com
{% endhighlight %}

Set a shell variable for your project ID — you will use it throughout:

{% highlight bash %}
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
{% endhighlight %}

## Setting Up the Pub/Sub Topic

Create the topic that SCC will publish findings to:

{% highlight bash %}
gcloud pubsub topics create scc-findings-high-critical \
  --project="$PROJECT_ID"
{% endhighlight %}

Security Command Center publishes messages using a service account in the format `service-org-PROJECT_NUMBER@gcp-sa-scc.iam.gserviceaccount.com`. This identity needs permission to publish to your topic:

{% highlight bash %}
gcloud pubsub topics add-iam-policy-binding scc-findings-high-critical \
  --member="serviceAccount:service-org-${PROJECT_NUMBER}@gcp-sa-scc.iam.gserviceaccount.com" \
  --role="roles/pubsub.publisher" \
  --project="$PROJECT_ID"
{% endhighlight %}

## Creating the SCC Notification Config

A notification config specifies which findings to publish and where to publish them. The filter syntax is identical to the filter expressions used in the SCC Findings page in the console, so you can prototype your filter there before committing it to the config.

This config publishes all ACTIVE findings with a severity of HIGH or CRITICAL:

{% highlight bash %}
gcloud scc notifications create scc-high-critical-to-pubsub \
  --organization="$(gcloud organizations list --format='value(name)' | head -1 | sed 's/organizations\///')" \
  --description="Publish HIGH and CRITICAL findings to Pub/Sub" \
  --pubsub-topic="projects/${PROJECT_ID}/topics/scc-findings-high-critical" \
  --filter='severity="HIGH" OR severity="CRITICAL"'
{% endhighlight %}

If you are working at project level rather than organization level, use `--project` instead of `--organization`:

{% highlight bash %}
gcloud scc notifications create scc-high-critical-to-pubsub \
  --project="$PROJECT_ID" \
  --description="Publish HIGH and CRITICAL findings to Pub/Sub" \
  --pubsub-topic="projects/${PROJECT_ID}/topics/scc-findings-high-critical" \
  --filter='severity="HIGH" OR severity="CRITICAL"'
{% endhighlight %}

Verify the config was created:

{% highlight bash %}
gcloud scc notifications list --project="$PROJECT_ID"
{% endhighlight %}

## Writing the Cloud Function

Create a directory for the function code:

{% highlight bash %}
mkdir scc-slack-notifier && cd scc-slack-notifier
{% endhighlight %}

### main.py

This is the full function. It receives a Pub/Sub message, decodes the SCC finding payload, and posts a formatted message to Slack:

{% highlight python %}
import base64
import json
import os
import urllib.request
import urllib.error
from datetime import datetime, timezone


def notify_slack(event, context):
    """Cloud Function triggered by a Pub/Sub message from SCC notifications."""

    # Decode the Pub/Sub message
    pubsub_message = event.get("data")
    if not pubsub_message:
        print("No data in Pub/Sub message, skipping.")
        return

    try:
        message_data = base64.b64decode(pubsub_message).decode("utf-8")
        notification = json.loads(message_data)
    except (ValueError, json.JSONDecodeError) as e:
        print(f"Failed to decode message: {e}")
        return

    finding = notification.get("finding", {})
    if not finding:
        print("No finding in notification, skipping.")
        return

    # Extract relevant fields
    severity = finding.get("severity", "UNKNOWN")
    category = finding.get("category", "UNKNOWN")
    state = finding.get("state", "UNKNOWN")
    resource_name = finding.get("resourceName", "UNKNOWN")
    finding_class = finding.get("findingClass", "UNKNOWN")
    event_time = finding.get("eventTime", "")
    finding_name = finding.get("name", "")
    description = finding.get("description", "No description available.")

    # Extract project from the resource name for context
    project_id = "unknown"
    if "/projects/" in resource_name:
        try:
            project_id = resource_name.split("/projects/")[1].split("/")[0]
        except IndexError:
            pass

    # Build the SCC console deep link
    scc_link = (
        f"https://console.cloud.google.com/security/command-center/findings"
        f"?project={project_id}"
    )

    # Format event time for readability
    formatted_time = event_time
    if event_time:
        try:
            dt = datetime.fromisoformat(event_time.replace("Z", "+00:00"))
            formatted_time = dt.strftime("%Y-%m-%d %H:%M:%S UTC")
        except ValueError:
            pass

    # Choose emoji and color based on severity
    severity_config = {
        "CRITICAL": {"color": "#FF0000", "label": "CRITICAL"},
        "HIGH": {"color": "#FF6600", "label": "HIGH"},
        "MEDIUM": {"color": "#FFCC00", "label": "MEDIUM"},
        "LOW": {"color": "#36A64F", "label": "LOW"},
    }
    config = severity_config.get(severity, {"color": "#808080", "label": severity})

    # Build Slack Block Kit payload
    slack_payload = {
        "attachments": [
            {
                "color": config["color"],
                "blocks": [
                    {
                        "type": "header",
                        "text": {
                            "type": "plain_text",
                            "text": f"[{config['label']}] SCC Finding: {category}",
                        },
                    },
                    {
                        "type": "section",
                        "fields": [
                            {"type": "mrkdwn", "text": f"*Severity:*\n{severity}"},
                            {"type": "mrkdwn", "text": f"*State:*\n{state}"},
                            {"type": "mrkdwn", "text": f"*Class:*\n{finding_class}"},
                            {"type": "mrkdwn", "text": f"*Project:*\n{project_id}"},
                            {
                                "type": "mrkdwn",
                                "text": f"*Detected:*\n{formatted_time}",
                            },
                        ],
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Resource:*\n`{resource_name}`",
                        },
                    },
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*Description:*\n{description}",
                        },
                    },
                    {
                        "type": "actions",
                        "elements": [
                            {
                                "type": "button",
                                "text": {"type": "plain_text", "text": "View in SCC"},
                                "url": scc_link,
                            }
                        ],
                    },
                ],
            }
        ]
    }

    # Send to Slack
    webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
    if not webhook_url:
        print("SLACK_WEBHOOK_URL environment variable not set.")
        return

    try:
        payload_bytes = json.dumps(slack_payload).encode("utf-8")
        req = urllib.request.Request(
            webhook_url,
            data=payload_bytes,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.getcode()
            print(f"Slack response: {status} for finding {finding_name}")
    except urllib.error.HTTPError as e:
        print(f"Slack HTTP error: {e.code} - {e.reason}")
    except urllib.error.URLError as e:
        print(f"Slack URL error: {e.reason}")
{% endhighlight %}

A few design decisions worth explaining. The function uses only the Python standard library — no third-party dependencies. `urllib.request` handles the Slack webhook call, which means `requirements.txt` stays empty and cold starts are fast. The Slack Block Kit attachment format gives you color-coded severity at a glance without requiring Slack apps or OAuth; incoming webhooks are enough.

The function is deliberately defensive about missing fields. SCC notifications can include partial finding objects depending on the notification type and the finding's lifecycle state. Calling `.get()` with defaults on every field prevents `KeyError` crashes on unexpected payloads.

### requirements.txt

{% highlight text %}
# No external dependencies required — standard library only
{% endhighlight %}

Leave this file in the directory but keep it empty. Cloud Functions expects it to be present.

## Deploying the Function

Create a dedicated service account for the function. It only needs logging permissions — the function does not call any GCP APIs directly:

{% highlight bash %}
gcloud iam service-accounts create scc-slack-notifier \
  --display-name="SCC Slack Notifier Function" \
  --project="$PROJECT_ID"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:scc-slack-notifier@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter"
{% endhighlight %}

Store the Slack webhook URL in Secret Manager rather than passing it as a plain environment variable. This keeps the URL out of deployment logs and Cloud Function metadata:

{% highlight bash %}
echo -n "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  | gcloud secrets create slack-webhook-url \
    --data-file=- \
    --project="$PROJECT_ID"

gcloud secrets add-iam-policy-binding slack-webhook-url \
  --member="serviceAccount:scc-slack-notifier@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor" \
  --project="$PROJECT_ID"
{% endhighlight %}

Now deploy the function. This uses the 2nd-gen Cloud Functions runtime, which is backed by Cloud Run and has better cold start characteristics than 1st-gen:

{% highlight bash %}
gcloud functions deploy scc-slack-notifier \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=. \
  --entry-point=notify_slack \
  --trigger-topic=scc-findings-high-critical \
  --service-account="scc-slack-notifier@${PROJECT_ID}.iam.gserviceaccount.com" \
  --set-secrets="SLACK_WEBHOOK_URL=slack-webhook-url:latest" \
  --memory=256Mi \
  --timeout=60s \
  --project="$PROJECT_ID"
{% endhighlight %}

The `--set-secrets` flag mounts the secret as an environment variable at runtime. The function reads it with `os.environ.get("SLACK_WEBHOOK_URL")`, and the actual URL value never appears in the deployment command or the function's environment variable listing in the console.

## Testing and Validation

### Publishing a test message manually

Before waiting for a real finding, publish a synthetic SCC notification directly to the Pub/Sub topic. This lets you validate the function and Slack integration immediately:

{% highlight bash %}
gcloud pubsub topics publish scc-findings-high-critical \
  --message='{
    "finding": {
      "name": "organizations/123456789/sources/0/findings/test-finding-001",
      "category": "PUBLIC_BUCKET_ACL",
      "severity": "HIGH",
      "state": "ACTIVE",
      "findingClass": "MISCONFIGURATION",
      "resourceName": "//storage.googleapis.com/projects/my-project/buckets/sensitive-data-bucket",
      "description": "A Cloud Storage bucket is publicly accessible.",
      "eventTime": "2024-11-11T10:00:00Z"
    }
  }' \
  --project="$PROJECT_ID"
{% endhighlight %}

Within a few seconds the function should fire and a formatted alert should appear in your Slack channel. If nothing appears, check the function logs:

{% highlight bash %}
gcloud functions logs read scc-slack-notifier \
  --gen2 \
  --region=us-central1 \
  --limit=50 \
  --project="$PROJECT_ID"
{% endhighlight %}

Common failure modes: the Slack webhook URL is incorrect or revoked, the service account cannot access the secret (check the IAM binding), or the Pub/Sub message schema does not match what the function expects (check the `finding` key is present at the top level).

### Triggering a real SCC finding

To validate the end-to-end path with a genuine SCC finding, you can intentionally create a misconfiguration in a non-production project. Making a Cloud Storage bucket publicly readable is a reliable way to generate a HIGH finding quickly:

{% highlight bash %}
# Create a test bucket (use a non-production project)
gsutil mb -p "$PROJECT_ID" gs://scc-test-public-bucket-$(date +%s)

# Make it publicly readable — this will trigger SCC
gsutil iam ch allUsers:objectViewer gs://scc-test-public-bucket-*

# SCC typically creates the finding within 1–5 minutes
# Remove the misconfiguration immediately after testing
gsutil iam ch -d allUsers:objectViewer gs://scc-test-public-bucket-*
gsutil rb gs://scc-test-public-bucket-*
{% endhighlight %}

SCC's detection latency for storage misconfigurations is typically under five minutes for Standard tier. Once the finding appears in the SCC dashboard, the notification config should have already published it to Pub/Sub and the function should have fired.

## Best Practices

**Filter notifications tightly at the config level.** A notification config that publishes every finding regardless of severity will flood your Pub/Sub topic and drive up costs on active projects. Start with `severity="HIGH" OR severity="CRITICAL"` and `state="ACTIVE"`. Add `mute_state="UNMUTED"` to the filter to exclude findings you have explicitly muted in SCC — you muted them for a reason, and routing them to Slack anyway defeats the purpose of muting.

**Use Secret Manager, not environment variables, for webhook URLs.** Passing a Slack webhook URL as a plain Cloud Functions environment variable means it is visible to anyone with `cloudfunctions.functions.get` permission on the project. Secret Manager adds one IAM binding but keeps the credential out of the function's metadata. The `--set-secrets` flag in the deploy command makes this frictionless.

**Idempotency matters for Pub/Sub.** Pub/Sub delivers messages at least once, not exactly once. Your function may receive the same finding notification more than once if there is a processing failure or a retry. For a Slack alerting function this is usually acceptable — duplicate alerts are annoying but not dangerous. If your function takes a remediation action (removing a public IAM binding, disabling a service account), you need to make that action idempotent or track processed message IDs to avoid acting twice.

**Use 2nd-gen Cloud Functions for production.** The `--gen2` flag switches to the Cloud Run-backed runtime, which gives you longer timeouts (up to 60 minutes), more memory (up to 32 GB), and better cold start performance than 1st-gen. For a function doing HTTP calls to Slack, 1st-gen works fine in testing, but 2nd-gen is the current standard.

**Add dead-letter queues for reliability.** If the function throws an uncaught exception, Pub/Sub retries the delivery up to the subscription's retry policy limit. After that, the message is dropped. Configure a dead-letter topic on the Pub/Sub subscription to catch messages that fail all retries so you can inspect and replay them:

{% highlight bash %}
gcloud pubsub subscriptions modify-push-config \
  projects/"$PROJECT_ID"/subscriptions/scc-findings-high-critical-sub \
  --dead-letter-topic=projects/"$PROJECT_ID"/topics/scc-findings-dlq \
  --max-delivery-attempts=5
{% endhighlight %}

**Consider extending the function for remediation, not just alerting.** The Slack notification is the simplest possible response. The same Cloud Function pattern works for automated remediation: remove a public IAM binding from a bucket, revoke an overprivileged service account key, or add a resource label that triggers a downstream compliance workflow. The SCC finding payload includes the resource name, which is enough to construct most GCP API calls. Use the Google Cloud client library for Python (`google-cloud-storage`, `google-cloud-iam`) and the same service account pattern with tighter IAM permissions scoped to only what the remediation action requires.

## Conclusion

The pattern here is straightforward once the plumbing is in place: SCC detects a misconfiguration, a notification config routes it to Pub/Sub, a Cloud Function processes the message and acts on it. What you have at the end is an automatic Slack alert for every new HIGH or CRITICAL finding in your GCP environment, deployed entirely through `gcloud` with no manual console steps.

The Slack alert is a starting point. The same structure handles automated remediation, ticket creation in Jira or ServiceNow, or enrichment workflows that pull additional context before routing to the right team. The function code is the only thing that changes; the SCC, Pub/Sub, and Cloud Functions wiring stays the same.

Happy scripting!
