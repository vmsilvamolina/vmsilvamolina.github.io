---
title: "OpenTelemetry: instrumenting a Python app and sending traces to Grafana"
author: Victor Silva
date: 2025-01-13T20:33:13+00:00
layout: post
permalink: /opentelemetry-python-traces-grafana/
excerpt: "When something breaks in a distributed system, logs alone rarely tell you the full story. This post walks through instrumenting a Python Flask app with OpenTelemetry, running the OTel Collector, and shipping traces to Grafana Tempo so you can follow a request from entry point to failure."
categories:
  - Observability
tags:
  - opentelemetry
  - python
  - grafana
  - traces
  - cncf
---

When something breaks in a distributed system, logs alone rarely tell you the full story. You can see that a request failed, but not which downstream call caused it, how long each hop took, or whether the failure was a first occurrence or the tail end of a cascade that started three services ago. That is the problem distributed tracing solves, and OpenTelemetry is the standard way to add it to your applications today.

OpenTelemetry is a CNCF incubating project that provides a unified set of APIs, SDKs, and tooling for generating, collecting, and exporting telemetry data — traces, metrics, and logs — from your applications. The key word is unified: OpenTelemetry is vendor-neutral and works with any compatible backend, so you instrument once and decide later where the data goes.

This post covers instrumenting a Python Flask application using OpenTelemetry's auto-instrumentation, adding manual spans for deeper visibility, running the OpenTelemetry Collector as a local sidecar, and shipping traces to Grafana Tempo for visualization in Grafana. By the end you will have a working local stack and a clear path to doing this in production.

## How the Stack Fits Together

Before writing any code, it is worth understanding the three distinct layers in an OpenTelemetry setup.

**The SDK** lives inside your application. It generates spans — records of individual operations with timestamps, attributes, and relationships to parent spans. In Python, the SDK ships as the `opentelemetry-sdk` package along with a set of instrumentation libraries that automatically patch well-known frameworks like Flask, Django, `requests`, and `sqlalchemy`.

**The Collector** is a standalone process that receives telemetry from your application over OTLP (the OpenTelemetry Protocol), processes it (batching, filtering, attribute enrichment), and exports it to one or more backends. Running a Collector between your app and the backend is strongly recommended over exporting directly from the SDK — it decouples your code from the backend choice and handles retries, buffering, and fan-out.

**The backend** stores and queries the trace data. In this post we use Grafana Tempo, which is purpose-built for distributed traces and integrates natively with Grafana.

The data flow looks like this:

```
Flask app (OTel SDK)
        |
        | OTLP/gRPC (port 4317)
        v
OTel Collector
        |
        | OTLP/gRPC (port 4317)
        v
Grafana Tempo
        |
        | TraceQL / HTTP
        v
Grafana (browser)
```

Each layer is independently replaceable. If you decide to move from Tempo to Jaeger or Zipkin later, you change one line in the Collector configuration and nothing in your application code.

## Prerequisites

You will need:

- Python 3.10 or higher
- Docker and Docker Compose
- Basic familiarity with Flask

Verify your Python and Docker versions before starting:

{% highlight bash %}
python3 --version
docker --version
docker compose version
{% endhighlight %}

All Python dependencies will be installed in a virtual environment, so there is no need to manage system packages.

## Setting Up the Python Application

Create a project directory and set up a virtual environment:

{% highlight bash %}
mkdir otel-demo && cd otel-demo
python3 -m venv .venv
source .venv/bin/activate
{% endhighlight %}

Install Flask and the OpenTelemetry packages. The `opentelemetry-instrumentation-flask` package handles automatic span generation for every incoming HTTP request. The `opentelemetry-exporter-otlp-proto-grpc` package sends traces to the Collector over gRPC:

{% highlight bash %}
pip install flask \
  opentelemetry-sdk \
  opentelemetry-api \
  opentelemetry-instrumentation-flask \
  opentelemetry-exporter-otlp-proto-grpc
{% endhighlight %}

Now create the application. This is a minimal Flask app with two endpoints — one that does a straightforward lookup and one that calls a slow downstream function to give us something interesting to look at in traces:

{% highlight python %}
# app.py

import time
import random
from flask import Flask, jsonify

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.flask import FlaskInstrumentor

# Configure the tracer provider with a resource that identifies this service
resource = Resource.create({"service.name": "otel-demo", "service.version": "1.0.0"})
provider = TracerProvider(resource=resource)

# The OTLP exporter sends spans to the OTel Collector
# OTEL_EXPORTER_OTLP_ENDPOINT defaults to localhost:4317 when not set
otlp_exporter = OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True)
provider.add_span_processor(BatchSpanProcessor(otlp_exporter))

trace.set_tracer_provider(provider)
tracer = trace.get_tracer(__name__)

app = Flask(__name__)
FlaskInstrumentor().instrument_app(app)


def fetch_user(user_id: int) -> dict:
    """Simulate a database lookup with variable latency."""
    with tracer.start_as_current_span("db.fetch_user") as span:
        span.set_attribute("db.system", "postgresql")
        span.set_attribute("db.operation", "SELECT")
        span.set_attribute("user.id", user_id)

        # Simulate latency
        latency = random.uniform(0.01, 0.08)
        time.sleep(latency)

        if user_id == 0:
            span.set_status(trace.StatusCode.ERROR, "user not found")
            raise ValueError(f"User {user_id} does not exist")

        return {"id": user_id, "name": f"user_{user_id}"}


@app.route("/users/<int:user_id>")
def get_user(user_id):
    with tracer.start_as_current_span("get_user_handler") as span:
        span.set_attribute("user.id", user_id)
        try:
            user = fetch_user(user_id)
            return jsonify(user)
        except ValueError as e:
            span.record_exception(e)
            span.set_status(trace.StatusCode.ERROR, str(e))
            return jsonify({"error": str(e)}), 404


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(port=5000, debug=False)
{% endhighlight %}

There are a few things worth pointing out here. The `FlaskInstrumentor` automatically creates a root span for every HTTP request — you get the URL, method, status code, and duration without any manual work. The manual spans (`db.fetch_user` and `get_user_handler`) nest inside that root span, giving you a timeline of what happened within each request. The `span.record_exception()` call attaches the full exception stack trace to the span as a structured event, which is far more useful than a log line when debugging errors.

## Running the OTel Collector and Grafana Stack

Create a `collector-config.yaml` file. This tells the Collector where to receive data, what to do with it, and where to send it:

{% highlight yaml %}
# collector-config.yaml

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  otlp:
    endpoint: tempo:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp]
{% endhighlight %}

The `batch` processor groups spans before forwarding them, which reduces network overhead. The exporter sends everything to Tempo using the OTLP protocol — Tempo has supported native OTLP ingestion since version 2.0, so there is no translation layer needed.

Now create the Docker Compose file that brings up the Collector, Tempo, and Grafana:

{% highlight yaml %}
# docker-compose.yaml

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.95.0
    command: ["--config=/etc/otel/config.yaml"]
    volumes:
      - ./collector-config.yaml:/etc/otel/config.yaml
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP

  tempo:
    image: grafana/tempo:2.4.1
    command: ["-config.file=/etc/tempo.yaml"]
    volumes:
      - ./tempo-config.yaml:/etc/tempo.yaml
      - tempo-data:/var/tempo
    ports:
      - "3200:3200"   # Tempo HTTP API
      - "4317"        # OTLP gRPC (internal only)

  grafana:
    image: grafana/grafana:10.3.3
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - ./grafana-datasources.yaml:/etc/grafana/provisioning/datasources/datasources.yaml
    ports:
      - "3000:3000"
    depends_on:
      - tempo

volumes:
  tempo-data:
{% endhighlight %}

You will need two more configuration files. First, `tempo-config.yaml`:

{% highlight yaml %}
# tempo-config.yaml

server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal

compactor:
  compaction:
    block_retention: 48h
{% endhighlight %}

And `grafana-datasources.yaml`, which pre-provisions Tempo as a data source so you do not have to configure it manually through the UI:

{% highlight yaml %}
# grafana-datasources.yaml

apiVersion: 1

datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: true
    jsonData:
      tracesToLogsV2:
        enabled: false
      serviceMap:
        datasourceUid: ""
      nodeGraph:
        enabled: true
{% endhighlight %}

Start the stack:

{% highlight bash %}
docker compose up -d
{% endhighlight %}

Verify all three containers are running:

{% highlight bash %}
docker compose ps
{% endhighlight %}

All three services should show `running`. The Collector logs are a good first stop if something is not working:

{% highlight bash %}
docker compose logs otel-collector
{% endhighlight %}

## Generating and Visualizing Traces

Start the Flask application in your virtual environment:

{% highlight bash %}
python3 app.py
{% endhighlight %}

Send a few requests to generate traces. Mix successful and error cases:

{% highlight bash %}
curl http://localhost:5000/users/42
curl http://localhost:5000/users/7
curl http://localhost:5000/users/0   # This will trigger the error path
curl http://localhost:5000/users/15
{% endhighlight %}

Open Grafana at `http://localhost:3000`. Navigate to **Explore** in the left sidebar and make sure **Tempo** is selected as the data source. Click **Search** to switch to the trace search view.

In the service name dropdown, select `otel-demo`. Set the time range to **Last 15 minutes** and click **Run query**. You will see a list of traces, each showing the total duration and number of spans.

Click on any trace to open the waterfall view. You should see three nested spans: the root HTTP span generated automatically by `FlaskInstrumentor`, the `get_user_handler` span, and the `db.fetch_user` span at the bottom. The relative widths show you exactly how much time each layer took.

Click on the `db.fetch_user` span. In the attributes panel you will see the custom attributes you set — `db.system`, `db.operation`, and `user.id`. For the request to user ID 0, you will also see the exception event with the full stack trace attached.

This is where distributed tracing pays off: instead of matching log lines across files, you have a single structured record of the entire request lifecycle with typed attributes you can filter and aggregate.

## Testing and Validation

Let's verify the full pipeline is working correctly end to end. First, confirm the Collector is receiving spans from the application by checking its metrics endpoint:

{% highlight bash %}
curl -s http://localhost:8888/metrics | grep otelcol_receiver_accepted_spans
{% endhighlight %}

You should see a counter greater than zero. If it reads zero after sending requests, check that the application is running and that `localhost:4317` is reachable.

Confirm Tempo is storing traces by querying its API directly:

{% highlight bash %}
curl -s "http://localhost:3200/api/search?service.name=otel-demo" | python3 -m json.tool
{% endhighlight %}

The response should include a `traces` array with entries matching the requests you sent. Each entry contains a `traceID`, the root span name, the service name, and the start time.

To validate that error spans are being recorded correctly, search for traces where the status is `error` using TraceQL in Grafana's Explore panel:

{% highlight text %}
{ .service.name = "otel-demo" && status = error }
{% endhighlight %}

The request to user ID 0 should appear. Click into it and confirm the `db.fetch_user` span shows the error status and has the exception event attached.

## Best Practices

**Use `BatchSpanProcessor` in production, never `SimpleSpanProcessor`.** The `SimpleSpanProcessor` exports each span synchronously, which blocks the calling thread and adds latency to every request. `BatchSpanProcessor` buffers spans and flushes asynchronously. The only valid use case for `SimpleSpanProcessor` is debugging during development.

**Set `service.name` and `service.version` in your Resource.** These two attributes are indexed by most backends and are the primary filters in trace search. Without them, all your traces appear under an unnamed service and you lose the ability to correlate traces with deployments. Inject `service.version` from your CI pipeline using an environment variable so traces automatically identify which build generated them.

**Add span attributes that reflect your domain, not your stack.** The auto-instrumentation gives you HTTP method, route, and status code for free. What it cannot give you is `user.id`, `order.id`, or `tenant.id`. These business-level attributes are what make traces actionable during an incident — they let you filter to all traces for a specific user or order rather than sampling from the general population.

**Sample in the Collector, not in the SDK.** OpenTelemetry supports head-based sampling (decision at span creation) and tail-based sampling (decision after the full trace is complete). For most production workloads, tail-based sampling in the Collector is the right choice: it lets you keep 100% of error traces and slow traces while dropping a large fraction of healthy fast requests. This requires running the `otelcol-contrib` image, which includes the `tailsampling` processor.

**Keep the Collector configuration in version control.** The Collector is infrastructure. Its configuration determines what data reaches your backend, what gets dropped, and what attributes get enriched or redacted. Treat `collector-config.yaml` with the same rigor as any other IaC file — review changes in pull requests, test them in a staging environment, and deploy them through your standard pipeline.

## Conclusion

With a few dozen lines of Python and a three-container Docker Compose stack, you have a working distributed tracing setup: spans generated automatically by the Flask instrumentation layer, enriched with manual spans and business-level attributes, shipped through the Collector to Tempo, and visible in Grafana's waterfall view. The pipeline is backend-agnostic — swapping Tempo for Jaeger or a managed service like Grafana Cloud Traces means changing two lines in the Collector configuration and nothing else.

From here the natural next steps are adding instrumentation to the `requests` or `httpx` library for outgoing HTTP calls, enabling the `tailsampling` processor in the Collector for production-grade sampling, and extending the same setup to capture metrics and logs through the same OTel SDK so all three telemetry signals flow through a single pipeline.

Happy scripting!
