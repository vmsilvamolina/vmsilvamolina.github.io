---
title: "Kubernetes Audit Logging: Policy, Fluent Bit, and Alerting"
author: Victor Silva
date: 2026-04-13T07:37:23+00:00
layout: post
permalink: /kubernetes-audit-logging/
excerpt: "Kubernetes audit logging records every kube-apiserver call in your cluster. Learn to write a production audit policy and ship logs with Fluent Bit."
categories:
  - Security
  - Kubernetes
tags:
  - kubernetes
  - observability
  - fluent-bit
  - kube-apiserver
  - devsecops
---

An incident happens. A secret is read, a ClusterRoleBinding is modified, someone runs `kubectl exec` into a production pod. You start the post-mortem and reach for the audit trail — and it is either missing, incomplete, or buried under so much noise that the relevant events are invisible. That is the exact situation audit logging is supposed to prevent, and it is surprisingly common because most teams configure it as an afterthought.

Kubernetes audit logging is built into `kube-apiserver` and gives you a structured JSON record of every API call made against your cluster: who did what, to which resource, when, and what the server returned. Done right, it is the forensic backbone of your cluster security posture. Done wrong, it either floods your log storage with garbage or silently drops the events you actually care about.

This post covers the full picture: how the audit pipeline works, how to write a production policy that suppresses noise first and captures high-value events at maximum fidelity, and how to ship those logs with Fluent Bit to Elasticsearch or Loki so your SIEM can alert on them.

## How Kubernetes Audit Logging Works

Every request to the Kubernetes API server moves through a defined lifecycle. The audit subsystem emits one event per stage that is relevant to your policy:

- **RequestReceived** — emitted the moment `kube-apiserver` receives the request, before any authorization or processing
- **ResponseStarted** — emitted when the response headers are sent but before the body is streamed (relevant mainly for watch calls)
- **ResponseComplete** — emitted when the full response is sent; this is the stage with the most useful context
- **Panic** — emitted when `kube-apiserver` encounters an internal error handling the request

The audit subsystem supports two backends simultaneously: a **log file backend** (`--audit-log-path`) that writes newline-delimited JSON to a file on the control-plane node, and a **webhook backend** (`--audit-webhook-config-file`) that POSTs events to an external HTTP endpoint. Most production setups use the file backend as the primary and ship from there.

The policy file (`--audit-policy-file`) controls what gets recorded and at what verbosity. Without a policy file, nothing is logged. The policy is evaluated top-to-bottom and the first matching rule wins, which is why rule order matters enormously.

The data flow looks like this:

```
 kubectl / CI pipeline / controller
           |
           v
    kube-apiserver
           |
     Audit pipeline
           |
    Policy evaluation
    (first match wins)
           |
      +----+----+
      |         |
  File backend  Webhook backend
  (audit.log)   (external endpoint)
      |
  Fluent Bit (DaemonSet on control-plane)
      |
  +---+---+
  |       |
  ES     Loki
```

Each audit event is a JSON object. The fields you will query most in a security context are:

- `verb` — the HTTP verb mapped to a Kubernetes action: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`
- `user.username` — the authenticated identity; for service accounts this is `system:serviceaccount:<namespace>:<name>`
- `objectRef.resource` — the resource type being acted on: `secrets`, `pods`, `clusterrolebindings`, etc.
- `objectRef.name` — the specific object name
- `sourceIPs` — the originating IP addresses
- `responseStatus.code` — the HTTP response code; `401` and `403` are particularly useful for security alerting
- `stage` — which pipeline stage emitted this event

## Audit Policy Levels

The policy file assigns one of four recording levels to each matched request. Choosing the right level per resource type is the difference between a useful audit trail and a storage bill you cannot explain.

| Level | What is recorded | When to use it |
|---|---|---|
| None | Nothing | High-volume noise: health checks, watch loops, controller heartbeats |
| Metadata | Request metadata only (verb, user, resource, timestamp) | Routine operations where you need the who-did-what but not the payload |
| Request | Metadata + request body | Mutations where you want to see exactly what was sent |
| RequestResponse | Full request + full response body | Secret reads, RBAC changes, exec — anything where the payload itself is evidence |

The `RequestResponse` level on a resource like `configmaps` with a `list` verb will include the full response body for every list call, which means every value in every ConfigMap in the response ends up in your audit log. That is both a storage problem and a security problem if the audit log destination is not properly secured. Be precise about which verbs you apply `RequestResponse` to.

## Writing a Production Audit Policy

The right approach is noise suppression first. Start by silencing the internal system traffic that would otherwise dominate your log volume — API server self-calls, kube-proxy watch loops, node status reconciliation, controller manager polls — and then escalate the recording level only for resources that carry security significance.

Here is the full production policy:

{% highlight yaml %}
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  # --- Noise suppression ---
  - level: None
    users: ["system:apiserver"]
    verbs: ["get"]
    resources:
      - group: ""
        resources: ["endpoints"]
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
      - group: ""
        resources: ["endpoints", "services"]
  - level: None
    userGroups: ["system:nodes"]
    verbs: ["get"]
    resources:
      - group: ""
        resources: ["nodes"]
  - level: None
    users: ["system:kube-controller-manager", "system:kube-scheduler"]
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["endpoints", "configmaps"]
  - level: None
    nonResourceURLs: ["/healthz*", "/readyz*", "/livez*", "/metrics", "/version"]

  # --- High-fidelity security captures ---
  - level: RequestResponse
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["secrets"]
  - level: RequestResponse
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "rbac.authorization.k8s.io"
        resources: ["roles", "clusterroles", "rolebindings", "clusterrolebindings"]
  - level: RequestResponse
    verbs: ["create"]
    resources:
      - group: ""
        resources: ["serviceaccounts/token"]
  - level: RequestResponse
    verbs: ["create"]
    resources:
      - group: ""
        resources: ["pods/exec", "pods/attach", "pods/portforward"]

  # --- Mutation capture ---
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: ""
        resources: ["configmaps"]
  - level: RequestResponse
    verbs: ["create", "delete"]
    resources:
      - group: ""
        resources: ["namespaces"]
  - level: Request
    verbs: ["create", "update", "patch", "delete"]
    resources:
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]

  # --- Metadata-level for pod lifecycle ---
  - level: Metadata
    verbs: ["create", "delete"]
    resources:
      - group: ""
        resources: ["pods"]

  # --- Catch-all ---
  - level: Metadata
    omitStages:
      - "ResponseStarted"
{% endhighlight %}

A few design decisions worth explaining.

The `omitStages: [RequestReceived]` at the top of the policy applies globally. `RequestReceived` fires before authorization, which means it doubles your log volume without adding any information about what actually happened. Omitting it cluster-wide is the single most impactful thing you can do for audit log volume.

The noise suppression rules at the top silence internal system identities doing routine reconciliation work. Without them, `system:kube-proxy` watch calls and `system:kube-controller-manager` list operations generate tens of thousands of events per hour on a busy cluster.

Secrets get `RequestResponse` on all verbs including reads. This is intentional. If an attacker or a misconfigured service account reads a secret, you want the full response in the log — including the base64-encoded values — so you can confirm exactly which credentials were exposed. This means the audit log destination must be treated as a sensitive data store, not a general-purpose logging endpoint.

The RBAC section captures `create`, `update`, `patch`, and `delete` on all four RBAC resource types. Privilege escalation via RBAC is one of the most common lateral movement techniques in compromised clusters, and you want full request and response fidelity when it happens.

The catch-all `Metadata` rule at the bottom ensures that any API group or resource not explicitly matched by an earlier rule still gets recorded at the metadata level. Without this rule, new custom resource types or API extensions introduced to your cluster would be silently dropped from the audit log.

### Applying the Policy

On a kubeadm-managed cluster, place the policy file on the control-plane node and reference it in the `kube-apiserver` static pod manifest:

{% highlight bash %}
# Copy the policy to the control-plane node
sudo cp audit-policy.yaml /etc/kubernetes/audit/audit-policy.yaml

# Add these flags to /etc/kubernetes/manifests/kube-apiserver.yaml
# under spec.containers[0].command:
#   - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml
#   - --audit-log-path=/var/log/kubernetes/audit/audit.log
#   - --audit-log-maxage=30
#   - --audit-log-maxbackup=10
#   - --audit-log-maxsize=100
{% endhighlight %}

The kubelet will restart `kube-apiserver` automatically when it detects a change to the static pod manifest. Verify the API server restarted cleanly and picked up the policy:

{% highlight bash %}
kubectl get pods -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system kube-apiserver-<node-name> | grep -i audit
{% endhighlight %}

On managed Kubernetes services (AKS, EKS, GKE), the control plane is not directly accessible. Each provider exposes audit logs through its own mechanism: AKS via Azure Monitor / Log Analytics, EKS via CloudWatch Logs, GKE via Cloud Logging. The policy configuration interface varies by provider, and managed audit log delivery can lag 5–15 minutes on AKS — it is not a real-time feed.

## Shipping Logs with Fluent Bit

Now that `kube-apiserver` is writing structured JSON to `/var/log/kubernetes/audit/audit.log` on your control-plane nodes, you need to get those logs into a queryable destination. Fluent Bit is the right tool here: it is lightweight, runs as a DaemonSet with tolerations, and has native output plugins for both Elasticsearch and Loki.

The key constraint is that audit logs only exist on control-plane nodes. Your Fluent Bit DaemonSet needs tolerations for the `control-plane` taint and a `nodeSelector` to target those nodes specifically.

### Fluent Bit ConfigMap

{% highlight yaml %}
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-audit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         5
        Daemon        Off
        Log_Level     info
        Parsers_File  parsers.conf

    [INPUT]
        Name              tail
        Path              /var/log/kubernetes/audit/audit.log
        Parser            json
        Tag               kube.audit
        Refresh_Interval  5
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On

    [FILTER]
        Name   record_modifier
        Match  kube.audit
        Record cluster prod-cluster-01
        Record log_type kubernetes_audit

    [OUTPUT]
        Name            es
        Match           kube.audit
        Host            elasticsearch.logging.svc.cluster.local
        Port            9200
        Index           kubernetes-audit
        Type            _doc
        Logstash_Format On
        Logstash_Prefix kubernetes-audit
        Retry_Limit     5

  parsers.conf: |
    [PARSER]
        Name        json
        Format      json
        Time_Key    requestReceivedTimestamp
        Time_Format %Y-%m-%dT%H:%M:%S.%LZ
{% endhighlight %}

If you are forwarding to Loki instead of Elasticsearch, replace the `[OUTPUT]` block:

{% highlight yaml %}
    [OUTPUT]
        Name            loki
        Match           kube.audit
        Host            loki.logging.svc.cluster.local
        Port            3100
        Labels          job=kubernetes-audit,cluster=prod-cluster-01
        Label_Keys      $verb,$user['username'],$objectRef['resource']
        Retry_Limit     5
{% endhighlight %}

### Fluent Bit DaemonSet

{% highlight yaml %}
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit-audit
  namespace: logging
  labels:
    app: fluent-bit-audit
spec:
  selector:
    matchLabels:
      app: fluent-bit-audit
  template:
    metadata:
      labels:
        app: fluent-bit-audit
    spec:
      serviceAccountName: fluent-bit
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
        - key: node-role.kubernetes.io/master
          operator: Exists
          effect: NoSchedule
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      containers:
        - name: fluent-bit
          image: fluent/fluent-bit:3.2
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 256Mi
          volumeMounts:
            - name: audit-log
              mountPath: /var/log/kubernetes/audit
              readOnly: true
            - name: config
              mountPath: /fluent-bit/etc
      volumes:
        - name: audit-log
          hostPath:
            path: /var/log/kubernetes/audit
            type: DirectoryOrCreate
        - name: config
          configMap:
            name: fluent-bit-audit-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit-audit
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit-audit
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluent-bit-audit
subjects:
  - kind: ServiceAccount
    name: fluent-bit
    namespace: logging
{% endhighlight %}

Apply the ConfigMap and DaemonSet to your cluster:

{% highlight bash %}
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f fluent-bit-audit-config.yaml
kubectl apply -f fluent-bit-audit-daemonset.yaml
{% endhighlight %}

Verify that the DaemonSet pods land only on control-plane nodes and are reading the audit log:

{% highlight bash %}
kubectl get pods -n logging -l app=fluent-bit-audit -o wide
kubectl logs -n logging daemonset/fluent-bit-audit | grep -E "audit|flush|chunk"
{% endhighlight %}

You should see one pod per control-plane node and log lines indicating it is tailing the audit log file.

## What to Alert On

Collecting audit logs is only half the work. The value comes from the alerts you build on top of them. Here are the five security patterns that should have active alerts in any production cluster.

### 1. Secret reads and lists

Any access to `secrets` outside your expected service accounts deserves investigation. In Elasticsearch:

{% highlight bash %}
# Kibana KQL
objectRef.resource: "secrets" AND verb: ("get" OR "list") AND NOT user.username: "system:serviceaccount:*"
{% endhighlight %}

In Loki (LogQL):

{% highlight bash %}
{job="kubernetes-audit"} | json | objectRef_resource="secrets" and verb=~"get|list" | line_format "{{.user_username}} accessed secret {{.objectRef_name}} in {{.objectRef_namespace}}"
{% endhighlight %}

### 2. Pod exec, attach, and portforward

An exec into a running pod is a major indicator of either legitimate debugging or active intrusion. Either way, you want to know about it. The response code `101` indicates a successful WebSocket upgrade (exec session established):

{% highlight bash %}
# KQL
objectRef.resource: "pods" AND objectRef.subresource: ("exec" OR "attach" OR "portforward") AND responseStatus.code: 101
{% endhighlight %}

### 3. RBAC mutations

Any create, update, patch, or delete against ClusterRoleBindings or RoleBindings in sensitive namespaces should alert immediately. Privilege escalation via RBAC is the most common post-compromise lateral movement path:

{% highlight bash %}
# KQL
objectRef.resource: ("clusterrolebindings" OR "rolebindings") AND verb: ("create" OR "update" OR "patch" OR "delete")
{% endhighlight %}

Correlate these events with the `requestObject` field, which at `RequestResponse` level will contain the full binding definition including the subject being granted access.

### 4. Failed authentication and authorization

A burst of `401` or `403` responses is either a misconfigured service account or credential scanning. Either warrants investigation:

{% highlight bash %}
# KQL — rate alert: more than 10 in 5 minutes from the same sourceIP
responseStatus.code: (401 OR 403) AND sourceIPs: *
{% endhighlight %}

Set this as a count-based alert in your SIEM rather than alerting on individual events — some 403s in normal operations are expected. A spike is the signal.

### 5. Anonymous requests

Any request authenticated as `system:anonymous` should be treated as a configuration error at minimum and a probing attempt at worst:

{% highlight bash %}
# KQL
user.username: "system:anonymous"
{% endhighlight %}

If anonymous authentication is disabled on your cluster (`--anonymous-auth=false` on the API server), this alert should never fire. If it does, something is wrong.

## Best Practices

**Always omit `RequestReceived` globally.** This stage fires before authorization and carries no additional information over `ResponseComplete` for security purposes. Keeping it doubles your audit log volume without any investigation value. Set it in `omitStages` at the top of your policy file, not per rule.

**Never apply `RequestResponse` to `list` verbs on high-volume resources.** A `RequestResponse` audit event for a `list secrets` call includes the full response body — every secret in the namespace in base64. On a namespace with 50 secrets being listed every 30 seconds by a controller, that is a significant storage and security exposure. Scope `RequestResponse` to specific verbs (`get`, `create`, `update`, `patch`, `delete`) and use `Metadata` or `Request` for `list` and `watch` on non-secret resources.

**Treat the audit log destination as a sensitive data store.** At `RequestResponse` level, audit events for secret reads contain base64-encoded secret values. Your Elasticsearch index or Loki stream for audit logs needs the same access controls as the secrets themselves. Restrict read access, enable encryption at rest, and do not route audit events through a general-purpose logging pipeline with broad access.

**Always include a catch-all rule at the bottom of your policy.** Without it, any API group or resource not explicitly matched by your rules is silently dropped. Custom resource definitions, new API groups added by operators, and future Kubernetes API additions all fall through the gap. The `Metadata` catch-all at the bottom of the production policy above ensures nothing is silently ignored.

**Account for managed Kubernetes audit log latency.** On AKS, audit logs delivered through Azure Monitor can lag 5–15 minutes. This means your audit-based alerts are not real-time — they are delayed. Design your incident response process with this in mind and do not rely on audit log alerts as your only detection layer for active incidents. Complement them with runtime security tools like Falco for real-time detection.

**Rotate and archive audit log files on the control-plane node.** The `--audit-log-maxage`, `--audit-log-maxbackup`, and `--audit-log-maxsize` flags on `kube-apiserver` control local rotation. Set them explicitly: 30 days retention, 10 backup files, 100MB per file is a reasonable starting point. Without these flags, a single audit log file can grow until it fills the control-plane root volume, which will crash `kube-apiserver`.

## Conclusion

Kubernetes audit logging is not a checkbox. Without a thoughtful policy, you either have silence where you need evidence or noise that makes the evidence unreachable. The approach in this post — suppress system traffic first, escalate to `RequestResponse` only for resources that carry security value, ship with Fluent Bit to a secured destination, and alert on the five patterns that actually indicate malicious activity — gives you a forensic trail you can actually use.

The policy and the Fluent Bit configuration are both starting points. Your first week of running them in production will surface internal system accounts you need to suppress and resources you want to escalate. Tune from there. Version your policy file in git alongside the rest of your cluster configuration.

Happy scripting!
