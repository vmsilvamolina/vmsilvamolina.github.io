---
title: 'Getting Started with Falco for Runtime Security in Kubernetes'
author: Victor Silva
date: 2024-02-12T10:00:00+00:00
layout: post
permalink: /falco-runtime-security-kubernetes/
excerpt: "Most Kubernetes security tools stop at the cluster perimeter. Falco watches what happens inside - at the syscall level. This post walks through installing Falco with modern-eBPF, writing a custom rule, and routing alerts with Falco Sidekick."
categories:
  - Security
  - DevOps
tags:
  - Falco
  - Kubernetes
  - CNCF
  - Runtime Security
  - eBPF
  - DevSecOps
---

You've hardened your cluster with network policies, scanned your images for CVEs, and locked down RBAC. Then a compromised container drops a reverse shell at 2 AM and none of those controls fire a single alert. That's the gap runtime security fills, and that's exactly what Falco is built for.

Falco is a CNCF graduated project that operates at the system call layer. It doesn't care about image layers or admission webhooks - it watches what processes actually do once they're running. If a container spawns a shell, reads `/etc/shadow`, or exfiltrates credentials from the service account mount, Falco catches it in real time and routes the alert wherever you need it.

This post walks through a production-grade Falco installation on Kubernetes using the modern eBPF driver, a pair of custom detection rules mapped to MITRE ATT&CK, and Falco Sidekick to forward events to Slack and a SIEM webhook.

## How Falco Works

Before touching a single Helm value, it's worth understanding the moving parts.

**Syscall capture** - Falco sits between the kernel and user space, capturing every system call made by every process on the node. When a process opens a file, executes a binary, or creates a network connection, the kernel emits a syscall event. Falco intercepts those events using one of three driver options:

- `kmod` - a kernel module compiled and inserted at runtime. It works, but loading an unsigned module in production makes many security teams uncomfortable.
- `ebpf` - a classic eBPF probe that uses CO-RE (Compile Once, Run Everywhere) when possible, but still requires a BPF-capable kernel around 4.14+.
- `modern-ebpf` - the recommended option for kernels 5.8 and above. It ships entirely in userspace, requires no kernel module insertion, and leverages CO-RE by default. This is what we'll use.

**Rules engine** - Once Falco captures a syscall event, it evaluates it against a rules file. Each rule is a YAML document with a `condition` (a boolean expression over event fields), an `output` format string, and a `priority`. The default rules ship in `/etc/falco/falco_rules.yaml`. Your custom rules go in `falco_rules.local.yaml` (or, when installed via Helm, in a `customRules` values block). Rules in the local file override or append to defaults.

**Falco Sidekick** - Falco itself writes alerts to stdout, a file, or an HTTP endpoint. Sidekick is the fan-out layer that picks up those HTTP events and forwards them to over 50 destinations including Slack, Alertmanager, PagerDuty, S3, Elasticsearch, and generic webhooks. It ships with a web UI that gives you a real-time dashboard of alert volumes by priority and rule.

The data flow looks like this:

```
Kernel syscall events
        |
   Falco DaemonSet (modern-ebpf probe)
        |
   Rules evaluation
        |
   HTTP output -> Falco Sidekick (port 2801)
        |
   +-----------+-----------+
   |           |           |
 Slack      Webhook      WebUI
           (SIEM)
```

Simple architecture, serious signal.

## Prerequisites

Before you start, make sure you have:

- A Kubernetes cluster running version 1.25 or higher
- Helm 3 installed and configured against your cluster
- Worker nodes running Linux kernel 5.8 or above (check with `uname -r`)
- `kubectl` access with cluster-admin privileges for the `falco` namespace
- If you're on GKE, note that GKE Autopilot does not support Falco because it does not allow privileged DaemonSets. Use GKE Standard instead.

You can verify your kernel version across all nodes quickly:

{% highlight bash %}
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kernelVersion}{"\n"}{end}'
{% endhighlight %}

All nodes should report 5.8 or higher to use `modern-ebpf`. If some nodes are older, fall back to the `ebpf` driver for those and plan a node upgrade.

## Installing Falco via Helm

Add the official Falco Helm repository and update your local index:

{% highlight bash %}
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
{% endhighlight %}

For a quick install with all defaults and the flags we care about, this one-liner works:

{% highlight bash %}
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --version 3.8.0 \
  --set driver.kind=modern-ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.webui.enabled=true \
  --set falco.json_output=true \
  --set collectors.containerd.enabled=true \
  --set collectors.containerd.socket=/run/containerd/containerd.sock
{% endhighlight %}

That gets you running. But for anything beyond a quick demo, you want a values file you can version-control and review in pull requests. Here's the full configuration I use:

{% highlight yaml %}
# falco-values.yaml

driver:
  kind: modern-ebpf
  loader:
    initContainer:
      enabled: false

collectors:
  containerd:
    enabled: true
    socket: /run/containerd/containerd.sock

falco:
  json_output: true
  json_include_output_property: true
  log_level: info
  priority: debug
  http_output:
    enabled: true
    url: "http://falco-falcosidekick:2801/"

falcosidekick:
  enabled: true
  webui:
    enabled: true
  config:
    slack:
      webhookurl: ""
      minimumpriority: "warning"
    webhook:
      address: "https://your-siem.example.com/falco"
      minimumpriority: "notice"
    customfields: "cluster:prod,env:production"
{% endhighlight %}

A few things to point out here. The `loader.initContainer.enabled: false` setting skips the init container that would otherwise try to download and compile a kernel module - we don't need that with `modern-ebpf`. The `http_output.url` points to Sidekick using its in-cluster service name, which Helm creates automatically. The `customfields` block adds static labels to every Falco event so your SIEM can filter by cluster and environment without parsing the event body.

The `slack.webhookurl` is intentionally empty here. We'll cover where to put the real value safely in the best practices section.

Deploy it:

{% highlight bash %}
helm upgrade --install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --version 3.8.0 \
  -f falco-values.yaml
{% endhighlight %}

## Writing Custom Rules

The default rule set covers a lot of ground, but your environment is specific. Two rules I add to every cluster from day one map directly to MITRE ATT&CK techniques that show up repeatedly in container breach post-mortems.

Add these under a `customRules` key in your values file:

{% highlight yaml %}
customRules:
  custom_rules.yaml: |-
    - rule: Shell Spawned in Container
      desc: A shell binary was executed inside a running container
      condition: >
        spawned_process and container
        and proc.name in (shell_binaries)
        and not container.image.repository in (allowed_shell_images)
      output: >
        Shell spawned in container
        (user=%user.name cmd=%proc.cmdline
        pod=%k8s.pod.name ns=%k8s.ns.name
        image=%container.image.repository)
      priority: WARNING
      tags: [container, shell, T1609]

    - rule: Sensitive File Read in Container
      desc: A process read a sensitive file inside a container
      condition: >
        open_read and container
        and (fd.name in (sensitive_files)
          or fd.name startswith /var/run/secrets/kubernetes.io/serviceaccount)
        and not proc.name in (allowed_readers)
      output: >
        Sensitive file read
        (user=%user.name file=%fd.name proc=%proc.name
        pod=%k8s.pod.name image=%container.image.repository)
      priority: ERROR
      tags: [container, credentials, T1552.001]

    - list: allowed_shell_images
      items: []

    - list: allowed_readers
      items: [fluentd, filebeat]
{% endhighlight %}

**Shell Spawned in Container (T1609)** catches any execution of a shell binary - `bash`, `sh`, `zsh`, `dash` - inside a running container. The `shell_binaries` macro is defined in the default rules file, so you get that for free. The `allowed_shell_images` list is empty to start; you'll add image repositories that legitimately need shell access (debugging sidecars, for example) as you tune the rule. Keep this list as short as possible.

**Sensitive File Read in Container (T1552.001)** fires when a process opens any of the paths in the default `sensitive_files` macro - things like `/etc/shadow`, `/etc/sudoers`, and `/root/.ssh/` - or anything under the Kubernetes service account token mount path. The `allowed_readers` list accounts for log shippers like Fluentd and Filebeat that legitimately read certain paths.

Both rules include the pod name, namespace, container image, and executing user in the output. That context makes the difference between an alert you can act on and one you ignore.

After adding the custom rules block to `falco-values.yaml`, re-run the Helm upgrade:

{% highlight bash %}
helm upgrade falco falcosecurity/falco \
  --namespace falco \
  --version 3.8.0 \
  -f falco-values.yaml
{% endhighlight %}

## Testing and Validation

Start by verifying the DaemonSet rolled out cleanly and the driver loaded:

{% highlight bash %}
kubectl rollout status daemonset/falco -n falco
{% endhighlight %}

Then check that Falco actually loaded the modern-ebpf probe:

{% highlight bash %}
kubectl logs -n falco daemonset/falco -c falco | grep -E "driver|ebpf|probe"
{% endhighlight %}

You should see a line mentioning `modern_ebpf` and no errors about failing to load a kernel module.

Now let's trigger the shell-in-container rule intentionally. Spin up a test pod:

{% highlight bash %}
kubectl run falco-test --image=ubuntu:22.04 --restart=Never -- sleep 3600
{% endhighlight %}

Wait a moment for it to reach Running state, then exec into it:

{% highlight bash %}
kubectl exec -it falco-test -- /bin/bash -c "whoami"
{% endhighlight %}

That exec spawns `/bin/bash` inside the container. Falco should catch it within a second or two. In a second terminal, tail the Falco logs:

{% highlight bash %}
kubectl logs -n falco daemonset/falco -f | grep "Shell spawned"
{% endhighlight %}

You should see output like this:

```
{"output":"Shell spawned in container (user=root cmd=bash -c whoami pod=falco-test ns=default image=ubuntu)","priority":"WARNING","rule":"Shell Spawned in Container","source":"syscall","tags":["T1609","container","shell"],"time":"..."}
```

Now verify that Sidekick forwarded it:

{% highlight bash %}
kubectl logs -n falco deployment/falco-falcosidekick | grep -E "Sending|webhook"
{% endhighlight %}

You should see lines showing the event being dispatched to your configured outputs.

To access the Sidekick web UI locally:

{% highlight bash %}
kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802
{% endhighlight %}

Open `http://localhost:2802` in your browser. You'll see a dashboard with event counts by priority, a timeline, and a searchable event log. It's a fast way to spot noisy rules before you're paging through production logs.

Once you're satisfied the detections are working, clean up the test pod:

{% highlight bash %}
kubectl delete pod falco-test
{% endhighlight %}

## Best Practices

**Use modern-ebpf in production.** The `kmod` driver loads a kernel module at runtime, which bypasses Secure Boot on many distributions and introduces a kernel stability risk if the module has a bug. With `modern-ebpf`, the probe runs entirely in userspace using the BPF verifier as a safety layer. No module signing issues, no `dkms` headaches.

**Don't expose Sidekick without authentication.** The Sidekick listener on port 2801 accepts events from Falco without any authentication by default. It should never be exposed via an Ingress. Lock it down with a NetworkPolicy that allows ingress only from the Falco DaemonSet pods:

{% highlight yaml %}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: falco-sidekick-ingress
  namespace: falco
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: falcosidekick
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: falco
    ports:
    - port: 2801
      protocol: TCP
{% endhighlight %}

**Tune noisy rules with `override: append`, not by disabling them.** If the default `Read sensitive file untrusted` rule is firing for your log shipper, the temptation is to comment it out. Don't. Instead, use the `override` mechanism in your local rules to append exceptions:

{% highlight yaml %}
- rule: Read sensitive file untrusted
  override:
    condition: append
    value: and not proc.name in (my_trusted_reader)
{% endhighlight %}

This keeps the rule active for everything else while adding your specific exception. If you disable the rule entirely, you create a blind spot that a future attacker can walk through.

**Store Slack webhook URLs in a Kubernetes Secret.** Putting secrets in `values.yaml` means they end up in Helm's release history in plain text, and they get committed to your GitOps repo. Instead, create a Secret:

{% highlight bash %}
kubectl create secret generic falco-sidekick-slack \
  --from-literal=slackWebhookURL="https://hooks.slack.com/services/..." \
  -n falco
{% endhighlight %}

Then reference it in your Sidekick configuration using the `existingSecret` approach documented in the Falco Sidekick Helm chart values.

**Monitor for dropped events.** If Falco can't keep up with the syscall volume on a busy node, it drops events - which means blind spots. Falco exposes a `falco_events_dropped_total` metric via its built-in Prometheus endpoint. Add an alert on this counter. If you see drops, increase the `syscall_buf_size_preset` value in your Falco configuration (the default is `4`, range is `1` to `8`):

{% highlight yaml %}
falco:
  syscall_buf_size_preset: 6
{% endhighlight %}

Monitor the node CPU impact after changing this - a larger buffer reduces drops but increases memory consumption on each node.

**Tag rules with MITRE ATT&CK identifiers.** Both custom rules above include tags like `T1609` and `T1552.001`. Those tags flow through to Sidekick output, which means your SIEM can automatically correlate Falco alerts with your ATT&CK coverage matrix. It's a small addition that makes a real difference during an incident review.

## Conclusion

Falco fills a detection gap that most Kubernetes security stacks leave wide open. Image scanning and admission control prevent known-bad things from getting in, but they have nothing to say about what a running container does once it's there. Falco watches the syscall layer and fires in real time when something breaks your baseline.

The setup in this post - `modern-ebpf` driver, Sidekick for fan-out, and custom rules mapped to MITRE ATT&CK - gives you a solid foundation. From here, the work is tuning: shrinking your allowlists, adding environment-specific rules, and wiring Sidekick alerts into your incident response workflow.

Start with the two custom rules we wrote, let them run for a week, and pay attention to what fires. You'll learn more about what's actually running in your cluster from a week of Falco output than from any static scan report.

Happy scripting!
