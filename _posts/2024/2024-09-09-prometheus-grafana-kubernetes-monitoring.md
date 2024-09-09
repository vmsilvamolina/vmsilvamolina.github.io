---
title: "Prometheus and Grafana: monitoring a Kubernetes cluster from scratch"
author: Victor Silva
date: 2024-09-09T20:08:47+00:00
layout: post
permalink: /prometheus-grafana-kubernetes-monitoring/
excerpt: "Most Kubernetes clusters run in production for weeks before anyone asks 'what is actually happening in there?' This post walks through deploying the kube-prometheus-stack with Helm, exploring the default Grafana dashboards, writing your first PromQL query, and wiring up a practical alert rule — all from a clean cluster."
categories:
  - Observability
tags:
  - prometheus
  - grafana
  - kubernetes
  - monitoring
  - cncf
---

Most Kubernetes clusters run in production for weeks before anyone asks "what is actually happening in there?" Node CPU graphs live somewhere in the cloud provider console, pod restarts get noticed only when users complain, and alert rules are a vague item on the backlog. Then one Saturday morning a node runs out of memory and takes half the workloads with it, and you spend four hours reconstructing what happened from logs that were already rotated.

Prometheus and Grafana close that gap. Prometheus is a CNCF graduated project — it has been the de-facto Kubernetes monitoring standard for years and the ecosystem around it is enormous. Grafana turns the data Prometheus collects into dashboards and alert rules that actually get acted on. Together they give you a real-time and historical view of everything happening in your cluster.

This post covers deploying the `kube-prometheus-stack` Helm chart, understanding what it installs and why, exploring the dashboards it ships out of the box, writing a handful of PromQL queries to answer real operational questions, and setting up an alert rule that pages you before a problem becomes an outage.

## How the Stack Fits Together

Before touching Helm, it is worth understanding the moving parts. The `kube-prometheus-stack` chart bundles several components that work together:

**Prometheus** scrapes metrics endpoints exposed by your cluster components and workloads, stores the time series data in its local TSDB, and evaluates alerting rules on each scrape cycle.

**Alertmanager** receives alerts fired by Prometheus and handles routing, grouping, silencing, and fan-out to destinations like Slack, PagerDuty, or email. It runs as a separate process specifically to survive Prometheus restarts.

**Grafana** connects to Prometheus as a data source and renders the stored time series as dashboards. It also has its own alerting engine, but for Kubernetes monitoring most teams use Prometheus alerting rules and treat Grafana purely as a visualization layer.

**kube-state-metrics** watches the Kubernetes API and exposes metrics about the state of cluster objects — Deployment replicas, Pod phase, PersistentVolumeClaim binding status, and so on. Without this, Prometheus has no visibility into the Kubernetes control plane.

**Prometheus Node Exporter** runs as a DaemonSet and exposes hardware and OS-level metrics from each node — CPU, memory, disk, network interface counters.

The data flow looks like this:

```
Kubernetes API server  ──┐
kube-state-metrics     ──┤
Node Exporter (DaemonSet) ┤── scrape ──> Prometheus TSDB
cAdvisor (kubelet)     ──┤
App /metrics endpoints ──┘
                                │
                        AlertManager ──> Slack / PagerDuty
                                │
                           Grafana ──> Browser
```

The chart wires all of this together and ships with a set of pre-built dashboards and alert rules maintained by the community under the `kubernetes-mixin` project. You get a working observability stack in one `helm upgrade`.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.26 or higher
- Helm 3.10 or later installed and configured against your cluster
- `kubectl` with cluster-admin access
- Enough capacity for the stack — on a typical 3-node cluster, the full `kube-prometheus-stack` uses roughly 500m CPU and 2Gi memory at steady state

Verify your cluster version and Helm version before starting:

{% highlight bash %}
kubectl version --short
helm version --short
{% endhighlight %}

Check that your cluster has sufficient resources available:

{% highlight bash %}
kubectl describe nodes | grep -A 4 "Allocated resources"
{% endhighlight %}

If you are on a local cluster like kind or minikube for testing, scale down Prometheus retention and resource requests as shown in the values file below — the defaults are sized for production.

## Installing kube-prometheus-stack via Helm

Add the `prometheus-community` Helm repository:

{% highlight bash %}
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
{% endhighlight %}

For a quick exploration you can install with all defaults:

{% highlight bash %}
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version 61.3.2
{% endhighlight %}

That gets you running, but the default values include persistence disabled, which means Prometheus loses all its data on pod restart. For anything beyond a quick demo, use a values file you can version-control. Here is a production-appropriate starting point:

{% highlight yaml %}
# prometheus-stack-values.yaml

prometheus:
  prometheusSpec:
    retention: 15d
    retentionSize: "10GB"
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 15Gi
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 500m
        memory: 1Gi
    # Scrape interval - default is 30s, 15s gives finer granularity
    # at the cost of higher cardinality
    scrapeInterval: "30s"
    evaluationInterval: "30s"

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: standard
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi

grafana:
  adminPassword: "change-me-in-production"
  persistence:
    enabled: true
    size: 5Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

# kube-state-metrics and node-exporter ship with sensible defaults
# Leave them unless you need to tune
{% endhighlight %}

Deploy with the values file:

{% highlight bash %}
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --version 61.3.2 \
  -f prometheus-stack-values.yaml
{% endhighlight %}

The chart creates a significant number of resources. Watch the rollout:

{% highlight bash %}
kubectl rollout status deployment/kube-prometheus-stack-grafana -n monitoring
kubectl rollout status deployment/kube-prometheus-stack-kube-state-metrics -n monitoring
kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring
{% endhighlight %}

Once everything is Running, check that Prometheus has discovered its scrape targets:

{% highlight bash %}
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
{% endhighlight %}

Open `http://localhost:9090/targets` in your browser. You should see targets for `apiserver`, `kubelet`, `node-exporter`, `kube-state-metrics`, `alertmanager`, `grafana`, and `prometheus` itself — all in state `UP`.

## Exploring the Default Grafana Dashboards

Port-forward to Grafana:

{% highlight bash %}
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
{% endhighlight %}

Open `http://localhost:3000`. Log in with `admin` and the password you set in your values file. Navigate to **Dashboards** in the left sidebar. The chart pre-imports a full set of dashboards from the `kubernetes-mixin` project. The ones you will use most are:

- **Kubernetes / Compute Resources / Cluster** — a cluster-wide view of CPU and memory requests vs limits vs actual usage across all namespaces. This is the first dashboard to open when something feels wrong with the cluster as a whole.

- **Kubernetes / Compute Resources / Namespace (Pods)** — drill into a single namespace to see which pods are consuming the most resources. Filter by namespace at the top.

- **Kubernetes / Nodes** — per-node view of CPU, memory, disk, and network. Useful when you suspect a specific node is under pressure.

- **Kubernetes / Persistent Volumes** — shows available vs used capacity for every PVC in the cluster. Add an alert from here before a volume fills up silently.

- **Alertmanager / Overview** — shows the current state of firing alerts and recent alert history. Come here first when an alert wakes you up to understand what else is happening.

Take five minutes to click through each dashboard before you write any queries. The pre-built panels show you what Prometheus already knows about your cluster and give you a feel for the metrics available.

## Writing PromQL Queries

PromQL is the query language Prometheus uses to retrieve and compute over time series data. It is worth learning the basics because the pre-built dashboards do not answer every question, and when they do not you need to write your own.

Open the Prometheus expression browser at `http://localhost:9090/graph`.

### CPU Usage by Pod

The `container_cpu_usage_seconds_total` metric is a monotonically increasing counter. To get the per-second rate over the last five minutes, use `rate()`:

{% highlight text %}
rate(container_cpu_usage_seconds_total{namespace="default", container!=""}[5m])
{% endhighlight %}

This returns one time series per container. To aggregate to pod level, sum across all containers within each pod:

{% highlight text %}
sum by (pod, namespace) (
  rate(container_cpu_usage_seconds_total{namespace="default", container!=""}[5m])
)
{% endhighlight %}

### Memory Usage vs Requested

One of the most useful operational queries is comparing actual memory consumption against what was requested. If a pod consistently uses significantly more than it requested, it is a candidate for OOMKill when the node comes under pressure:

{% highlight text %}
sum by (pod, namespace) (container_memory_working_set_bytes{container!=""})
/
sum by (pod, namespace) (
  kube_pod_container_resource_requests{resource="memory", container!=""}
)
{% endhighlight %}

A result greater than 1.0 means the pod is using more memory than it requested. Sort descending to find the most over-provisioned pods.

### Pods Not in Running Phase

This is the query I run first when something is wrong and I do not know where to look. It shows every pod that is not in a Running or Succeeded phase:

{% highlight text %}
kube_pod_status_phase{phase!~"Running|Succeeded"} == 1
{% endhighlight %}

The label set on each result tells you the pod name, namespace, and phase — Pending, Failed, or Unknown.

### Node Memory Pressure

To see how much memory is available on each node as a percentage:

{% highlight text %}
(
  node_memory_MemAvailable_bytes
  / node_memory_MemTotal_bytes
) * 100
{% endhighlight %}

Values below 10% warrant immediate attention. Add this to a Grafana panel on your node dashboard with a threshold color at 15%.

This is where PromQL becomes genuinely useful — you can combine metrics from different exporters (Node Exporter, kube-state-metrics, cAdvisor) with arithmetic and aggregation operators to answer questions that no single pre-built dashboard covers.

## Setting Up an Alert Rule

Pre-built dashboards are reactive — they show you what happened. Alert rules are proactive — they tell you before something becomes an outage. Let's write one for a common scenario: a pod restarting repeatedly, which in Kubernetes means either a crashing application or an OOMKill loop.

The metric is `kube_pod_container_status_restarts_total`. A restart counter that increases by more than 5 in the past 15 minutes indicates a crash loop that needs attention.

Create a PrometheusRule resource:

{% highlight yaml %}
# pod-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: pod-health-alerts
  namespace: monitoring
  labels:
    # These labels must match the ruleSelector in your Prometheus spec
    # kube-prometheus-stack sets release: kube-prometheus-stack by default
    release: kube-prometheus-stack
spec:
  groups:
    - name: pod.health
      interval: 1m
      rules:
        - alert: PodCrashLooping
          expr: |
            increase(kube_pod_container_status_restarts_total[15m]) > 5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {% raw %}{{ $labels.pod }}{% endraw %} in namespace {% raw %}{{ $labels.namespace }}{% endraw %} is crash looping"
            description: "Container {% raw %}{{ $labels.container }}{% endraw %} has restarted {% raw %}{{ $value | humanize }}{% endraw %} times in the last 15 minutes."

        - alert: PodNotReady
          expr: |
            kube_pod_status_ready{condition="true"} == 0
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod {% raw %}{{ $labels.pod }}{% endraw %} in namespace {% raw %}{{ $labels.namespace }}{% endraw %} is not ready"
            description: "Pod has been in a not-ready state for more than 10 minutes."

        - alert: NodeMemoryPressure
          expr: |
            (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {% raw %}{{ $labels.instance }}{% endraw %} is low on memory"
            description: "Available memory is {% raw %}{{ $value | humanizePercentage }}{% endraw %} of total."
{% endhighlight %}

Apply it:

{% highlight bash %}
kubectl apply -f pod-alerts.yaml
{% endhighlight %}

The `PrometheusRule` CRD is installed by the chart. The Prometheus Operator watches for resources with this CRD and automatically loads the rules into Prometheus — no restart required.

Verify that Prometheus picked up the rules:

{% highlight bash %}
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
{% endhighlight %}

Navigate to `http://localhost:9090/rules`. You should see a `pod.health` group with your three rules in state `inactive` (no current firing) or `firing` if one of the conditions is already met.

## Testing and Validation

Let's intentionally trigger the `PodCrashLooping` alert to verify the full pipeline works. Deploy a pod that exits immediately on every start:

{% highlight bash %}
kubectl create deployment crash-test \
  --image=busybox \
  --replicas=1 \
  -- /bin/sh -c "exit 1"
{% endhighlight %}

Within a few minutes the pod will enter a `CrashLoopBackOff` state. Verify it:

{% highlight bash %}
kubectl get pods -l app=crash-test
{% endhighlight %}

Watch the restart counter in Prometheus. Run this query in the expression browser:

{% highlight text %}
increase(kube_pod_container_status_restarts_total{pod=~"crash-test.*"}[15m])
{% endhighlight %}

You should see the value climb. After the counter exceeds 5 and the `for: 5m` window passes, the alert will move to `firing` state in `http://localhost:9090/alerts`.

Check Alertmanager received it:

{% highlight bash %}
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
{% endhighlight %}

Open `http://localhost:9093`. The `PodCrashLooping` alert should appear in the active alerts list with the pod name, namespace, and container label attached.

Once you have confirmed the end-to-end flow, clean up the test deployment:

{% highlight bash %}
kubectl delete deployment crash-test
{% endhighlight %}

## Best Practices

**Configure Alertmanager receivers before you need them.** The default installation routes all alerts to a `null` receiver — they fire and disappear silently. Add a Slack or PagerDuty receiver in your values file before you deploy to production. An alert that nobody sees is the same as no alert.

**Set requests and limits on every workload you run.** Prometheus collects the resource request and actual usage data, but the dashboards only show you useful comparisons when the request values exist. Pods without resource requests look healthy even when they are consuming an unfair share of a node.

**Tune your scrape interval based on your use case.** The default 30-second interval is appropriate for most workloads. If you have a high-churn environment with many short-lived pods, consider increasing it to 60 seconds to reduce cardinality. If you need sub-30-second resolution for latency-sensitive services, drop it to 15 seconds on a per-job basis rather than globally.

**Use recording rules for expensive queries.** If a Grafana dashboard panel runs a complex PromQL expression on every load, it adds latency and load to Prometheus. Pre-compute expensive queries into recording rules in a `PrometheusRule` resource and reference the resulting metric name in your dashboard panels instead.

**Monitor Prometheus itself.** The chart ships a default alert for Prometheus storage running out of space, but watch `prometheus_tsdb_head_series` as well — this is your cardinality gauge. Unbounded cardinality growth (from labels with high-entropy values like request IDs or user IDs on metrics) is the most common cause of Prometheus becoming slow or running out of memory.

**Do not ship secrets in your values file.** The `grafana.adminPassword` field ends up in Helm's release history in plain text if you put it in values directly. Use a Kubernetes Secret and reference it via `grafana.admin.existingSecret`:

{% highlight yaml %}
grafana:
  admin:
    existingSecret: grafana-admin-credentials
    userKey: admin-user
    passwordKey: admin-password
{% endhighlight %}

Create the secret separately and keep it out of your GitOps repository or use a secrets management tool like Vault or Sealed Secrets.

## Conclusion

With the `kube-prometheus-stack` deployed you have metrics flowing from every cluster component into Prometheus, a Grafana instance pre-loaded with production-quality dashboards, and the ability to write PromQL queries to answer operational questions your dashboards do not cover. The three alert rules added in this post — crash looping pods, not-ready pods, and node memory pressure — cover a significant fraction of the incidents that interrupt Kubernetes operators on nights and weekends.

From here the natural next steps are wiring Alertmanager to a real notification channel, building application-specific dashboards for your own services, and adding custom metrics from your application code using a Prometheus client library. The infrastructure is in place; the observability you get out of it scales directly with how much you invest in the layer above it.

Happy scripting!
