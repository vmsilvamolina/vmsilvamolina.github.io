---
title: "KEDA: event-driven autoscaling in Kubernetes with Azure Service Bus"
author: Victor Silva
date: 2025-04-14T19:19:55+00:00
layout: post
permalink: /keda-kubernetes-azure-service-bus/
excerpt: "HPA scales on CPU and memory, but most real workloads scale on work — messages in a queue, events in a stream. KEDA bridges that gap by letting Kubernetes scale any workload to the exact depth of an Azure Service Bus queue, including all the way down to zero. This post walks through installing KEDA, provisioning a Service Bus queue, and watching a consumer deployment scale in and out as messages arrive."
categories:
  - Kubernetes
tags:
  - keda
  - kubernetes
  - azure
  - service-bus
  - cncf
---

When you deploy a message consumer on Kubernetes and route it through HPA, you quickly run into a fundamental mismatch. HPA watches CPU and memory. Your consumer's actual load is the number of messages waiting in a queue. When a batch job drops 10,000 messages at midnight, CPU on your idle pods stays near zero until they start processing — by which time you're already behind. When the queue drains, those pods sit at full replica count burning compute until the next HPA cycle decides to scale them back down.

This is the event-driven scaling problem, and HPA was never built to solve it. The Horizontal Pod Autoscaler is excellent at what it does, but it operates on metrics that lag behind the real signal. What you actually want is: when the queue has messages, scale up; when the queue is empty, scale down to zero. That is exactly what KEDA does.

KEDA — Kubernetes Event-Driven Autoscaling — is a CNCF graduated project that extends the Kubernetes autoscaling model to any external event source. It sits alongside the standard HPA, adds a layer of event source adapters called scalers, and lets you declare scaling behavior directly against Azure Service Bus queues and topics, Kafka consumer groups, Redis lists, Prometheus queries, and dozens of other sources. You write a `ScaledObject`, point it at a queue, set a threshold, and KEDA handles the rest — including scaling the deployment all the way to zero replicas when there is nothing to process.

This post walks through installing KEDA via Helm, creating an Azure Service Bus namespace and queue with the Azure CLI, configuring a `ScaledObject` that targets that queue, deploying a consumer workload, and observing the scale-in and scale-out behavior end to end.

## How KEDA Works

KEDA introduces two custom resources: `ScaledObject` and `TriggerAuthentication`.

A `ScaledObject` is the link between a Kubernetes workload (a `Deployment`, `StatefulSet`, or `Job`) and an external scaler. It defines the minimum and maximum replica count, the polling interval, and one or more triggers — each trigger being a scaler with its own configuration pointing at an external event source.

A `TriggerAuthentication` (or its cluster-scoped variant, `ClusterTriggerAuthentication`) holds the credentials the scaler needs to query the event source. This keeps connection strings and tokens out of the `ScaledObject` itself and lets you manage secrets independently.

Under the hood, KEDA runs two components: the **Metrics Adapter** and the **Operator**. The Metrics Adapter exposes external and custom metrics to the Kubernetes metrics pipeline so the standard HPA can act on them — KEDA does not replace HPA, it feeds it. The Operator watches `ScaledObject` resources and manages the HPA lifecycle on your behalf: creating it, configuring it with the right metric name and target, and tearing it down when you delete the `ScaledObject`.

The data flow for an Azure Service Bus trigger looks like this:

```
Azure Service Bus (queue depth)
         |
  KEDA Metrics Adapter
  (polls queue, exposes metric)
         |
  Kubernetes HPA
  (calculates desired replicas)
         |
  Deployment (consumer pods)
         |
  Scale-to-zero when queue is empty
```

The scale-to-zero capability is the part that HPA alone cannot provide. HPA requires at least one active metric provider, and with zero pods there is no CPU or memory to read. KEDA works around this by acting as the metric provider itself and managing the transition from zero to one replica when the queue first receives messages.

## Prerequisites

You will need:

- A Kubernetes cluster running version 1.27 or higher
- `kubectl` configured against the target cluster
- Helm 3 installed
- The Azure CLI (`az`) authenticated to an Azure subscription

Verify your cluster connection and Helm installation:

{% highlight bash %}
kubectl cluster-info
kubectl get nodes
helm version --short
{% endhighlight %}

Verify Azure CLI authentication:

{% highlight bash %}
az account show --query "{name:name, id:id}" -o table
{% endhighlight %}

If the last command returns your subscription name and ID, you are ready to proceed.

## Setting Up Azure Service Bus

First, set some environment variables to keep the commands readable:

{% highlight bash %}
RESOURCE_GROUP="rg-keda-demo"
LOCATION="eastus"
NAMESPACE="sb-keda-demo-$RANDOM"
QUEUE_NAME="keda-queue"
{% endhighlight %}

Create the resource group and Service Bus namespace. The `Basic` tier supports queues; if you need topics and subscriptions, use `Standard` or `Premium`.

{% highlight bash %}
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

az servicebus namespace create \
  --name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Basic
{% endhighlight %}

Create the queue:

{% highlight bash %}
az servicebus queue create \
  --name $QUEUE_NAME \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP
{% endhighlight %}

Retrieve the connection string for the root manage shared access key. In production you would create a dedicated authorization rule with send-only and listen-only keys; for this walkthrough the root key is sufficient:

{% highlight bash %}
CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list \
  --name RootManageSharedAccessKey \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --query primaryConnectionString \
  -o tsv)

echo $CONNECTION_STRING
{% endhighlight %}

Keep the value of `CONNECTION_STRING` — you will use it in the next section.

## Installing KEDA

Add the KEDA Helm repository and update:

{% highlight bash %}
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
{% endhighlight %}

Install KEDA into its own namespace:

{% highlight bash %}
helm upgrade --install keda kedacore/keda \
  --namespace keda \
  --create-namespace \
  --version 2.14.0
{% endhighlight %}

Wait for the KEDA components to reach Running state:

{% highlight bash %}
kubectl rollout status deployment/keda-operator -n keda
kubectl rollout status deployment/keda-operator-metrics-apiserver -n keda
kubectl rollout status deployment/keda-admission-webhooks -n keda
{% endhighlight %}

Confirm the custom resource definitions were registered:

{% highlight bash %}
kubectl get crd | grep keda
{% endhighlight %}

You should see `scaledobjects.keda.sh`, `triggerauthentications.keda.sh`, `clustertriggerauthentications.keda.sh`, and a few others. If those CRDs are present, KEDA is ready.

## Deploying the Consumer Workload

Create a namespace for the demo:

{% highlight bash %}
kubectl create namespace keda-demo
{% endhighlight %}

Store the Service Bus connection string as a Kubernetes Secret:

{% highlight bash %}
kubectl create secret generic azure-servicebus-secret \
  --from-literal=connection-string="$CONNECTION_STRING" \
  --namespace keda-demo
{% endhighlight %}

Now deploy a minimal consumer. This example uses a small container that reads messages from the queue. In a real scenario this would be your actual application; the important detail is the deployment name, which you will reference in the `ScaledObject`.

{% highlight yaml %}
# consumer-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: servicebus-consumer
  namespace: keda-demo
spec:
  replicas: 0
  selector:
    matchLabels:
      app: servicebus-consumer
  template:
    metadata:
      labels:
        app: servicebus-consumer
    spec:
      containers:
        - name: consumer
          image: mcr.microsoft.com/azure-cli:latest
          command:
            - /bin/sh
            - -c
            - |
              while true; do
                echo "Processing messages..."
                sleep 5
              done
          env:
            - name: AZURE_SERVICEBUS_CONNECTION_STRING
              valueFrom:
                secretKeyRef:
                  name: azure-servicebus-secret
                  key: connection-string
{% endhighlight %}

Notice `replicas: 0` in the spec. KEDA will manage the replica count entirely; setting it to zero in the manifest ensures that in the absence of a `ScaledObject` the deployment stays dormant.

Apply it:

{% highlight bash %}
kubectl apply -f consumer-deployment.yaml
{% endhighlight %}

## Configuring the ScaledObject

This is the core of the KEDA configuration. The `TriggerAuthentication` tells KEDA where to find the connection string, and the `ScaledObject` binds the queue to the deployment.

{% highlight yaml %}
# trigger-auth.yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: azure-servicebus-auth
  namespace: keda-demo
spec:
  secretTargetRef:
    - parameter: connection
      name: azure-servicebus-secret
      key: connection-string
{% endhighlight %}

{% highlight yaml %}
# scaled-object.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: servicebus-scaledobject
  namespace: keda-demo
spec:
  scaleTargetRef:
    name: servicebus-consumer
  minReplicaCount: 0
  maxReplicaCount: 10
  pollingInterval: 15
  cooldownPeriod: 60
  triggers:
    - type: azure-servicebus
      metadata:
        queueName: keda-queue
        messageCount: "5"
      authenticationRef:
        name: azure-servicebus-auth
{% endhighlight %}

A few fields worth understanding here.

`scaleTargetRef.name` points at the `servicebus-consumer` deployment you created above. KEDA will manage a corresponding HPA targeting that deployment.

`minReplicaCount: 0` enables scale-to-zero. When the queue is empty, KEDA scales the deployment to zero replicas. When messages arrive, it scales back to at least one replica before the HPA takes over for further scale-out.

`messageCount: "5"` is the target message count per replica. If the queue has 50 messages, KEDA targets 10 replicas (50 ÷ 5). If it has 5 messages, it targets 1 replica. This is the threshold knob you tune based on your consumer's processing speed.

`pollingInterval: 15` controls how often KEDA queries the Service Bus queue, in seconds. Lower values make scaling more responsive; higher values reduce API calls to the Service Bus management endpoint.

`cooldownPeriod: 60` sets how long KEDA waits after the queue drains before scaling the deployment back to `minReplicaCount`. This prevents thrashing when messages arrive in irregular bursts.

Apply both manifests:

{% highlight bash %}
kubectl apply -f trigger-auth.yaml
kubectl apply -f scaled-object.yaml
{% endhighlight %}

Verify the `ScaledObject` was accepted and is active:

{% highlight bash %}
kubectl get scaledobject -n keda-demo
{% endhighlight %}

The `READY` column should show `True` and the `ACTIVE` column should show `False` (because the queue is currently empty and the deployment is at zero replicas).

## Testing and Validation

With the `ScaledObject` in place, send some messages to the queue to trigger scaling. The Azure CLI can send messages to a Service Bus queue directly:

{% highlight bash %}
for i in $(seq 1 25); do
  az servicebus queue message send \
    --body "test-message-$i" \
    --queue-name $QUEUE_NAME \
    --namespace-name $NAMESPACE \
    --resource-group $RESOURCE_GROUP
done
{% endhighlight %}

This sends 25 messages. With a `messageCount` threshold of 5, KEDA should target 5 replicas. Watch the deployment scale up in real time:

{% highlight bash %}
kubectl get deployment servicebus-consumer -n keda-demo --watch
{% endhighlight %}

Within two polling intervals (30 seconds in this configuration) you should see the `READY` count increase from 0. Check the `ScaledObject` status for details:

{% highlight bash %}
kubectl describe scaledobject servicebus-scaledobject -n keda-demo
{% endhighlight %}

Look for the `Conditions` section — it shows the current metric value (queue depth), the desired replica count, and whether KEDA is actively scaling. You can also inspect the HPA that KEDA created automatically:

{% highlight bash %}
kubectl get hpa -n keda-demo
{% endhighlight %}

KEDA names the HPA `keda-hpa-<scaledobject-name>`. Describing it shows the target metric, current value, and replica history — the same output you would see with a manually configured HPA.

Once the consumer has processed all messages (or you wait for the `cooldownPeriod` to expire with an empty queue), the deployment should scale back to zero:

{% highlight bash %}
kubectl get pods -n keda-demo --watch
{% endhighlight %}

You will see the pods enter `Terminating` state and disappear as the queue depth falls below the threshold and the cooldown expires.

To confirm the queue depth from the Azure side at any point:

{% highlight bash %}
az servicebus queue show \
  --name $QUEUE_NAME \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --query "countDetails.activeMessageCount" \
  -o tsv
{% endhighlight %}

## Best Practices

**Keep `TriggerAuthentication` separate from `ScaledObject`.** Separating credentials from scaling configuration lets you rotate secrets independently and reuse the same `TriggerAuthentication` across multiple `ScaledObject` resources that connect to the same Service Bus namespace. In a multi-team cluster, consider `ClusterTriggerAuthentication` so platform teams manage credentials once and application teams reference them by name.

**Use dedicated authorization rules with minimum permissions.** The root `RootManageSharedAccessKey` has full management access to the namespace. For a KEDA scaler you only need `Listen` rights on the queue. Create a scoped rule:

{% highlight bash %}
az servicebus queue authorization-rule create \
  --name keda-listen-rule \
  --queue-name $QUEUE_NAME \
  --namespace-name $NAMESPACE \
  --resource-group $RESOURCE_GROUP \
  --rights Listen
{% endhighlight %}

Use the connection string from this rule in your Kubernetes Secret instead of the root key.

**Tune `messageCount` based on your consumer's throughput.** The threshold is the single most important tuning parameter. Start by measuring how many messages per second a single consumer pod can process, then set `messageCount` so that your target replica count keeps pace with the ingest rate. A threshold that is too high means messages accumulate faster than pods are added; too low means you over-provision replicas for light traffic.

**Set a non-zero `minReplicaCount` for latency-sensitive consumers.** Scale-to-zero is ideal for batch workloads where a cold-start delay of a few seconds is acceptable. If your consumers are processing time-sensitive events, set `minReplicaCount: 1` to keep at least one pod warm. You still benefit from KEDA's event-driven scale-out without the cold-start penalty.

**Monitor KEDA operator logs when scaling behaves unexpectedly.** The most common issues — invalid credentials, incorrect queue name, or a misconfigured `TriggerAuthentication` — all surface in the operator logs:

{% highlight bash %}
kubectl logs deployment/keda-operator -n keda --tail=50
{% endhighlight %}

Look for lines referencing your `ScaledObject` name and the Azure Service Bus scaler. Error messages are explicit about what failed and usually point directly to the configuration field that needs correction.

## Conclusion

HPA covers the workloads where CPU and memory are meaningful scaling signals. KEDA covers the rest — and in most real production environments, event-driven consumers that process queues, streams, and topics make up a large share of the workload surface. The combination of scale-to-zero and externally-driven scaling thresholds means your consumers consume compute only when there is actual work to do.

The setup in this post — KEDA installed via Helm, a Service Bus queue with a dedicated listen-only authorization rule, a `TriggerAuthentication` backed by a Kubernetes Secret, and a `ScaledObject` with sensible polling and cooldown settings — is the pattern you will use for every event-driven consumer you deploy. Change the trigger type from `azure-servicebus` to `kafka`, `redis`, or `prometheus`, adjust the authentication block, and the rest of the `ScaledObject` structure stays the same.

From here, explore KEDA's `ScaledJob` resource for workloads that should run as one-shot jobs per message batch rather than long-running consumers, and look at `ClusterTriggerAuthentication` once you are managing more than a couple of scaled workloads in the same cluster.

Happy scripting!
