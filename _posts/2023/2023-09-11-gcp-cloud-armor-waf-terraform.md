---
title: 'GCP Cloud Armor Terraform: WAF Policy with OWASP CRS'
author: Victor Silva
date: 2023-09-11T19:11:25+00:00
layout: post
permalink: /gcp-cloud-armor-waf-terraform/
excerpt: "Default-allow Cloud Armor policies offer no real protection. Build a google_compute_security_policy with OWASP CRS rules and rate-based bans in Terraform."
categories:
  - GCP
  - Security
tags:
  - GCP Cloud Armor Terraform
  - google_compute_security_policy
  - Cloud Armor WAF rules
  - GCP WAF security policy
  - OWASP CRS Terraform
  - evaluatePreconfiguredWaf
  - rate_based_ban GCP
  - GCP security policy Terraform
---

When you put a workload behind a Google Cloud external Application Load Balancer, you get global reach, automatic DDoS mitigation at the network layer, and a managed TLS termination point. What you do not get by default is any application-layer inspection. A SQL injection payload, an XSS probe, or a Log4Shell exploit string goes straight through to your backend service unless you explicitly configure something to stop it. That something is Cloud Armor.

If you are coming from Azure, Cloud Armor is conceptually closest to Azure Application Gateway WAF or Azure Front Door WAF — it inspects HTTP/HTTPS requests using a ruleset derived from the OWASP Core Rule Set and lets you write custom rules in a CEL-based expression language. If you are coming from AWS, the closest equivalent is AWS WAF attached to a CloudFront distribution or Application Load Balancer. The key GCP-specific detail that trips people up is where in the load balancer architecture Cloud Armor attaches, and what the default policy actually does when you first enable it. Both of those details have real security consequences.

This post walks through Cloud Armor's architecture, builds a production-ready security policy using `google_compute_security_policy` in Terraform — including geo-blocking, OWASP CRS preconfigured WAF rules, and rate-based bans — attaches it to a backend service, and covers the misconfigurations that make otherwise well-configured WAF policies effectively useless.

## Cloud Armor Architecture

### Where Cloud Armor Sits

Cloud Armor security policies attach to **backend services**, not to frontend forwarding rules or target HTTPS proxies. This is a meaningful distinction. A single security policy can be associated with multiple backend services, but the enforcement point is always at the backend service, not at the LB frontend. Traffic must pass through the external ALB to be inspected — anything that reaches your backend through a path that bypasses the LB also bypasses Cloud Armor.

```
Internet
    │
    ▼
[Global Anycast IP]
    │
    ▼
[Forwarding Rule]
    │
    ▼
[Target HTTPS Proxy]
    │
    ▼
[URL Map]
    │
    ├── /api/*  ──► [Backend Service: api-backend]  ◄── Cloud Armor Policy
    │
    └── /*      ──► [Backend Service: web-backend]  ◄── Cloud Armor Policy
```

Enforcement happens at Google's edge Points of Presence — malicious traffic is evaluated and dropped before it ever reaches your Cloud Run service, GKE workload, or GCE instance group. The practical implication is that your backends see only traffic that passed the policy evaluation, which also means your Cloud Logging bandwidth and backend request volume are cleaner — blocked requests appear in the load balancer logs, not in application logs.

### Rule Evaluation Model

Cloud Armor policies contain ordered rules. Each rule has a numeric priority, a match condition, and an action. Rules are evaluated in **ascending priority order** — lower numbers are evaluated first. The first rule whose match condition is satisfied wins, and its action is applied immediately. No further rules are evaluated for that request.

The default rule is always present at priority `2147483647` (the maximum 32-bit integer value). GCP ships this default rule with an `allow` action. That means if you create a security policy, add a few WAF rules, and attach it to a backend service without changing the default rule, any request that does not match one of your explicit rules passes through unchallenged. This is a posture that feels like security but provides none — it is the WAF equivalent of a firewall with a final `permit any any`. The first thing you should do with any production Cloud Armor policy is change the default rule to `deny(403)`.

The policy type for a global external ALB is `CLOUD_ARMOR`. If you are working with serverless backends (Cloud Run, Cloud Functions, App Engine), you would use `CLOUD_ARMOR_EDGE` — but that type has different capabilities and is out of scope for this post.

## Prerequisites

To follow along you will need:

- Terraform 1.3 or later
- The `google` provider version 4.x or later
- A GCP project with the Compute Engine API enabled
- `gcloud` CLI authenticated with a principal that has `roles/compute.securityAdmin` and `roles/compute.loadBalancerAdmin` on your target project
- An existing external Application Load Balancer with at least one backend service (or you can create the backend service from scratch alongside the policy)

Verify your setup:

{% highlight bash %}
terraform version
gcloud auth list
gcloud config get-value project
gcloud services list --filter="NAME:compute.googleapis.com"
{% endhighlight %}

Set your project as the default if it is not already:

{% highlight bash %}
gcloud config set project YOUR_PROJECT_ID
{% endhighlight %}

## Building the Security Policy with Terraform

The core resource is `google_compute_security_policy`. Let us build it up section by section, then look at the complete policy together at the end.

### Advanced Options Configuration

Before getting into individual rules, you need to configure some policy-level options that affect how the entire policy behaves. These defaults are not obvious, and two of them in particular will silently undermine your WAF if you leave them at their defaults.

{% highlight hcl %}
advanced_options_config {
  json_parsing                 = "STANDARD"
  log_level                    = "NORMAL"
  request_body_inspection_size = "64KB"
}
{% endhighlight %}

**`json_parsing = "STANDARD"`** is the most important of these. Without it, Cloud Armor inspects the raw request body as a plain string. If an attacker encodes a SQL injection payload as a JSON value — for example, `{"query": "1' OR '1'='1"}` — Cloud Armor's SQLi rules will not decode the JSON before inspection and the payload passes through undetected. With `json_parsing = "STANDARD"`, Cloud Armor parses JSON bodies and inspects the decoded values. Enable this for any backend that accepts JSON requests.

**`request_body_inspection_size`** defaults to 8 KB. For a REST API receiving moderately complex request bodies, 8 KB is often not enough to inspect the full body content, which means the tail of a large request is never evaluated. Increase this to `64KB` for most APIs. The maximum is `128KB`.

**`log_level`** controls what gets included in security policy logs. `VERBOSE` captures the full request headers and body, which is useful during initial tuning but captures authentication headers, cookies, and potentially sensitive POST data in your Cloud Logging stream. Use `NORMAL` in production and switch to `VERBOSE` only temporarily while tuning sensitivity levels. This is not a performance concern — it is a data retention and PII exposure concern.

### Rule 100: Trusted IP Allowlist

The first explicit rule establishes an allowlist for trusted IP ranges — your office egress, your CI/CD runner IPs, your monitoring infrastructure. These sources bypass all subsequent WAF rules and are always allowed through, regardless of what their requests look like. Placing this at priority 100 ensures it is evaluated before any deny rules.

{% highlight hcl %}
rule {
  action      = "allow"
  priority    = 100
  description = "Allow trusted IP ranges"
  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = ["203.0.113.0/24"]
    }
  }
}
{% endhighlight %}

Replace `203.0.113.0/24` with your actual trusted ranges. If you manage these ranges in a Terraform variable, you can pass a list directly into `src_ip_ranges`.

### Rule 200: Geo-Blocking

Geo-blocking rules use Cloud Armor's CEL expression language to match on `origin.region_code`, which is a two-letter ISO 3166-1 country code derived from the source IP's geolocation. This is useful for compliance requirements or for reducing your attack surface when you have no legitimate users in specific regions.

{% highlight hcl %}
rule {
  action      = "deny(403)"
  priority    = 200
  preview     = true
  description = "Geo-block high-risk regions"
  match {
    expr {
      expression = "origin.region_code == 'KP' || origin.region_code == 'IR'"
    }
  }
}
{% endhighlight %}

Notice `preview = true`. This is Cloud Armor's dry-run mode — the rule is evaluated and its match result is logged, but the action is not enforced. Use preview mode whenever you introduce a new blocking rule, and monitor Cloud Logging for false positives before flipping `preview` to `false`. This applies equally to geo-blocking rules and WAF rules; the patterns are predictable in theory but surprising in practice once real traffic flows through.

### Rules 1000–1003: OWASP CRS Preconfigured WAF Rules

This is the heart of the WAF configuration. Cloud Armor ships a managed ruleset based on OWASP CRS 4.22 accessible via the `evaluatePreconfiguredWaf()` CEL function. You reference specific rule sets by their versioned name — the pattern is `{attack-type}-v422-stable`.

The key sets you should enable for most web applications are:

| Rule Set Name | Covers |
|---|---|
| `sqli-v422-stable` | SQL injection |
| `xss-v422-stable` | Cross-site scripting |
| `lfi-v422-stable` | Local file inclusion |
| `rfi-v422-stable` | Remote file inclusion |
| `rce-v422-stable` | Remote code execution |
| `java-v422-stable` | Java deserialization, Log4Shell |
| `scannerdetection-v422-stable` | Automated scanner fingerprints |

Each rule set accepts a `sensitivity` parameter from 1 to 4. Sensitivity 1 triggers only on high-confidence, low-ambiguity indicators — you will see the fewest false positives here, but some evasive payloads may not match. Sensitivity 4 casts the widest net but will generate false positives against legitimate requests in most applications, especially those that handle user-generated content or complex query strings. Start at sensitivity 1 with `preview = true`, observe the results for a few days, then decide whether to increase sensitivity or enforce.

{% highlight hcl %}
rule {
  action      = "deny(403)"
  priority    = 1000
  description = "OWASP CRS: SQL injection"
  match {
    expr {
      expression = "evaluatePreconfiguredWaf('sqli-v422-stable', {'sensitivity': 1})"
    }
  }
}

rule {
  action      = "deny(403)"
  priority    = 1001
  description = "OWASP CRS: Cross-site scripting"
  match {
    expr {
      expression = "evaluatePreconfiguredWaf('xss-v422-stable', {'sensitivity': 1})"
    }
  }
}

rule {
  action      = "deny(403)"
  priority    = 1002
  description = "OWASP CRS: LFI, RFI, and RCE combined"
  match {
    expr {
      expression = <<-EOT
        evaluatePreconfiguredWaf('lfi-v422-stable', {'sensitivity': 1}) ||
        evaluatePreconfiguredWaf('rfi-v422-stable', {'sensitivity': 1}) ||
        evaluatePreconfiguredWaf('rce-v422-stable', {'sensitivity': 1})
      EOT
    }
  }
}

rule {
  action      = "deny(403)"
  priority    = 1003
  description = "OWASP CRS: Java / Log4Shell"
  match {
    expr {
      expression = "evaluatePreconfiguredWaf('java-v422-stable', {'sensitivity': 2})"
    }
  }
}
{% endhighlight %}

The LFI/RFI/RCE rule at priority 1002 combines three related attack classes into a single rule using `||` in the CEL expression. This is cleaner than three separate rules and does not change the evaluation semantics — if any of the three sets match, the request is denied. For the `java-v422-stable` set, sensitivity 2 is appropriate because Log4Shell indicators are distinctive enough that sensitivity 2 adds meaningful coverage over sensitivity 1 without generating significant false positives. JNDI lookup strings do not appear in normal application traffic.

### Rules 2000–2001: Rate Limiting

Rate limiting in Cloud Armor comes in two flavors. The `throttle` action allows requests up to a threshold and returns 429 for requests that exceed it within the measurement window — the client is not blocked persistently, just slowed down. The `rate_based_ban` action does something stronger: once a client exceeds the ban threshold, it is blocked for the entire `ban_duration_sec` period, regardless of its subsequent request rate.

A global throttle at priority 2000 provides a basic per-IP rate limit across all paths:

{% highlight hcl %}
rule {
  action      = "throttle"
  priority    = 2000
  description = "Global per-IP rate limit"
  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = ["*"]
    }
  }
  rate_limit_options {
    conform_action = "allow"
    exceed_action  = "deny(429)"
    enforce_on_key = "IP"
    rate_limit_threshold {
      count        = 100
      interval_sec = 60
    }
  }
}
{% endhighlight %}

The global throttle is necessary but not sufficient. A credential stuffing attack that sends 20 requests per minute to `/auth/login` from a single IP will never trigger a 100 req/min global limit, but it will enumerate credentials effectively over hours. This is where path-specific rate-based banning matters:

{% highlight hcl %}
rule {
  action      = "rate_based_ban"
  priority    = 2001
  description = "Ban IPs with excessive login attempts"
  match {
    expr {
      expression = "request.path.matches('/auth/login')"
    }
  }
  rate_limit_options {
    conform_action   = "allow"
    exceed_action    = "deny(429)"
    enforce_on_key   = "IP"
    ban_duration_sec = 3600
    rate_limit_threshold {
      count        = 20
      interval_sec = 60
    }
    ban_threshold {
      count        = 50
      interval_sec = 120
    }
  }
}
{% endhighlight %}

This rule allows up to 20 login attempts per minute from a single IP. If that IP sends more than 50 requests to `/auth/login` within any 120-second window, it is banned for the next hour. The `ban_threshold` is evaluated against the cumulative count over the `interval_sec` window — the ban kicks in when the IP has been persistently aggressive, not just briefly over the limit. Adjust the thresholds based on your expected legitimate traffic patterns. A `/auth/login` endpoint that supports SSO redirects may see higher burst rates from legitimate users than a traditional username/password form.

### Default Rule: Deny by Default

The default rule at priority `2147483647` must be changed from the default `allow` to `deny(403)`. Any request that does not match any of the rules above will be denied:

{% highlight hcl %}
rule {
  action      = "deny(403)"
  priority    = "2147483647"
  description = "Default deny — explicit allow-list only"
  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = ["*"]
    }
  }
}
{% endhighlight %}

With this in place, your trust model is explicit: traffic is denied unless it came from a trusted IP (rule 100), passed all WAF checks (rules 1000–1003), and did not exceed rate limits (rules 2000–2001). This is a defense-in-depth posture rather than a default-allow posture with optional blocking.

## Complete Security Policy and Backend Attachment

Here is the full `google_compute_security_policy` resource consolidated, followed by the backend service attachment:

{% highlight hcl %}
resource "google_compute_security_policy" "web_waf" {
  name        = "web-waf-policy"
  description = "Production WAF policy — OWASP CRS + geo-block + rate limits"
  type        = "CLOUD_ARMOR"

  advanced_options_config {
    json_parsing                 = "STANDARD"
    log_level                    = "NORMAL"
    request_body_inspection_size = "64KB"
  }

  # Rule 100 — allow trusted IPs
  rule {
    action      = "allow"
    priority    = 100
    description = "Allow trusted IP ranges"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["203.0.113.0/24"]
      }
    }
  }

  # Rule 200 — geo-block
  rule {
    action      = "deny(403)"
    priority    = 200
    preview     = true
    description = "Geo-block high-risk regions"
    match {
      expr {
        expression = "origin.region_code == 'KP' || origin.region_code == 'IR'"
      }
    }
  }

  # Rule 1000 — SQLi
  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "OWASP CRS: SQL injection"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v422-stable', {'sensitivity': 1})"
      }
    }
  }

  # Rule 1001 — XSS
  rule {
    action      = "deny(403)"
    priority    = 1001
    description = "OWASP CRS: Cross-site scripting"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v422-stable', {'sensitivity': 1})"
      }
    }
  }

  # Rule 1002 — LFI + RFI + RCE combined
  rule {
    action      = "deny(403)"
    priority    = 1002
    description = "OWASP CRS: LFI, RFI, and RCE combined"
    match {
      expr {
        expression = <<-EOT
          evaluatePreconfiguredWaf('lfi-v422-stable', {'sensitivity': 1}) ||
          evaluatePreconfiguredWaf('rfi-v422-stable', {'sensitivity': 1}) ||
          evaluatePreconfiguredWaf('rce-v422-stable', {'sensitivity': 1})
        EOT
      }
    }
  }

  # Rule 1003 — Log4Shell / Java
  rule {
    action      = "deny(403)"
    priority    = 1003
    description = "OWASP CRS: Java / Log4Shell"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('java-v422-stable', {'sensitivity': 2})"
      }
    }
  }

  # Rule 2000 — throttle per IP
  rule {
    action      = "throttle"
    priority    = 2000
    description = "Global per-IP rate limit"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
    }
  }

  # Rule 2001 — rate-based ban on /auth/login
  rule {
    action      = "rate_based_ban"
    priority    = 2001
    description = "Ban IPs with excessive login attempts"
    match {
      expr {
        expression = "request.path.matches('/auth/login')"
      }
    }
    rate_limit_options {
      conform_action   = "allow"
      exceed_action    = "deny(429)"
      enforce_on_key   = "IP"
      ban_duration_sec = 3600
      rate_limit_threshold {
        count        = 20
        interval_sec = 60
      }
      ban_threshold {
        count        = 50
        interval_sec = 120
      }
    }
  }

  # Default rule — deny-by-default
  rule {
    action      = "deny(403)"
    priority    = "2147483647"
    description = "Default deny"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
{% endhighlight %}

Attaching the policy to a backend service requires a single attribute — `security_policy` on `google_compute_backend_service`. Enable request logging as well so you can correlate Cloud Armor decisions with backend traffic:

{% highlight hcl %}
resource "google_compute_backend_service" "api_backend" {
  name            = "api-backend-service"
  protocol        = "HTTPS"
  security_policy = google_compute_security_policy.web_waf.id

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  # backend and health check configuration omitted for brevity
}
{% endhighlight %}

Setting `sample_rate = 1.0` logs every request. During initial rollout this is exactly what you want — you need full visibility into what the policy is blocking and what it is allowing. You can reduce the sample rate after the policy has been stable for a few weeks.

## Key Misconfigurations to Avoid

### Serverless NEG Bypass

If your backend is Cloud Run or Cloud Functions, Cloud Armor only protects traffic that reaches the backend through the external ALB. Each Cloud Run service and Cloud Function also has a direct HTTPS URL — `https://SERVICE-HASH-REGION.a.run.app` — that bypasses your load balancer and Cloud Armor entirely. An attacker who discovers or guesses this URL has a path directly to your application with no WAF in front of it.

Fix this by restricting ingress on your serverless backends to internal traffic and traffic from the Global Load Balancer:

{% highlight bash %}
gcloud run services update SERVICE_NAME \
  --ingress=internal-and-cloud-load-balancing \
  --region=REGION
{% endhighlight %}

For Cloud Functions (2nd gen), the equivalent is:

{% highlight bash %}
gcloud functions deploy FUNCTION_NAME \
  --ingress-settings=internal-and-gclb
{% endhighlight %}

This is not a Cloud Armor configuration issue — it is a network ingress issue that makes Cloud Armor irrelevant if not addressed.

### JSON SQLi Bypass

Without `json_parsing = "STANDARD"` in `advanced_options_config`, an attacker can encode a SQL injection payload as a JSON value and it will not be recognized by the SQLi WAF rules. This is because the rules operate on the inspected value, and without JSON parsing enabled, the inspected value is the raw JSON string — not the decoded content within it. This bypass is straightforward to reproduce and is well-documented. Always enable `json_parsing = "STANDARD"`.

### Default-Allow Default Rule

As discussed above, the default rule ships as `allow`. A security policy with WAF rules but a default-allow fallback is not defense-in-depth — it is detection with selective blocking. Traffic that does not match any explicit rule (including new attack patterns, unusual user agents, or scanner traffic) passes through. Change the default rule to `deny(403)`.

### Verbose Logging in Production

`log_level = "VERBOSE"` logs the full request including headers and body. In practice this means Authorization headers, cookies, session tokens, and POST body content — potentially including passwords on login endpoints — end up in Cloud Logging. If your logging export goes to a SIEM or a long-retention bucket, you are accumulating sensitive data that creates a secondary breach vector and a compliance concern. Use `NORMAL` in production.

### No Path-Specific Rate Limits

A global per-IP throttle at 100 req/min does nothing against an attacker making 20 carefully-timed requests per minute to your authentication endpoint over several hours. This is a standard credential stuffing pattern and it will never trigger a global threshold. Add path-specific `rate_based_ban` rules for all sensitive endpoints: authentication, password reset, account recovery, and any endpoint that gates access to user data.

## Validating with gcloud and Cloud Logging

After running `terraform apply`, verify that the security policy is configured correctly and attached to your backend service.

Inspect the policy rules:

{% highlight bash %}
gcloud compute security-policies describe web-waf-policy \
  --format="table(rules.priority, rules.action, rules.description, rules.preview)"
{% endhighlight %}

The output should list all your rules in ascending priority order. Confirm that priority `2147483647` shows `deny(403)` — not `allow`.

Verify the policy is attached to your backend service:

{% highlight bash %}
gcloud compute backend-services describe api-backend-service \
  --global \
  --format="value(securityPolicy)"
{% endhighlight %}

This should return the full resource URL of `web-waf-policy`. If it returns empty, the policy is not attached.

Test that the SQLi rule is blocking correctly by sending a request with an obvious injection payload:

{% highlight bash %}
curl -s -o /dev/null -w "%{http_code}" \
  "https://YOUR_LB_IP/api/search?q=1'+OR+'1'='1"
{% endhighlight %}

You should receive a `403` response. If you get `200`, check that `preview` is not set to `true` on your SQLi rule and that the default rule is `deny(403)` rather than `allow`.

Test the rate-based ban rule by sending bursts of requests to the login endpoint:

{% highlight bash %}
for i in $(seq 1 25); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST https://YOUR_LB_IP/auth/login \
    -H "Content-Type: application/json" \
    -d '{"username":"test","password":"test"}'
done
{% endhighlight %}

Requests beyond the 20 req/min threshold should return `429`. After crossing the ban threshold, subsequent requests will return `429` for the duration of the ban window.

Query Cloud Logging for blocked requests to see what the WAF is catching:

{% highlight bash %}
gcloud logging read \
  'resource.type="http_load_balancer" AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --limit=20
{% endhighlight %}

Each log entry includes `jsonPayload.enforcedSecurityPolicy.name` (the matched rule's description), `jsonPayload.enforcedSecurityPolicy.priority` (the rule's priority), and `jsonPayload.enforcedSecurityPolicy.configuredAction` (the action taken). This is the primary surface for tuning — review blocked requests to identify false positives before removing `preview` mode from new rules.

To filter by a specific rule — for example, to see only requests blocked by the SQLi rule:

{% highlight bash %}
gcloud logging read \
  'resource.type="http_load_balancer"
   AND jsonPayload.enforcedSecurityPolicy.priority=1000
   AND jsonPayload.enforcedSecurityPolicy.outcome="DENY"' \
  --limit=50
{% endhighlight %}

## Best Practices

**Roll out new rules in preview mode first.** Every new rule — geo-blocking, new WAF sets, stricter sensitivity levels — should spend at least a week in `preview = true` with traffic flowing before you enforce it. The Cloud Logging query above filtered by priority gives you a clear view of what would have been blocked. This is especially important when increasing sensitivity levels from 1 to 2 or higher.

**Use numeric priority bands deliberately.** A consistent convention makes policies readable and easier to maintain: 1–199 for allowlists, 200–999 for geo/reputation blocks, 1000–1999 for OWASP WAF rules, 2000–2999 for rate limiting, and `2147483647` for the default rule. Leave gaps within each band so you can insert rules without renumbering.

**Separate policies per environment.** Use Terraform workspaces or separate module instantiations for dev, staging, and production policies. Your production WAF may have stricter sensitivity levels and more aggressive rate limits than staging. Sharing a policy across environments either forces you to tune against production traffic from the start or leaves production inadequately protected.

**Fix the serverless ingress before anything else.** No amount of Cloud Armor configuration protects a Cloud Run service whose direct URL is reachable from the internet. Ingress restriction is a prerequisite for WAF enforcement on serverless backends, not an optional hardening step.

**Test for JSON SQLi explicitly.** After enabling `json_parsing = "STANDARD"`, send a test request with a JSON-encoded payload and verify it is blocked. This is a common oversight during policy review because standard SQLi test payloads do not involve JSON encoding. Add a JSON-encoded case to your WAF validation suite.

**Pair Cloud Armor with Security Command Center.** Cloud Armor findings from adaptive protection (Cloud Armor's ML-based threat detection) surface in Security Command Center. If you are running SCC, enable adaptive protection on your policies to get automated threat intelligence on top of the static rule evaluation. This does not replace the rules above — it complements them with dynamic signals.

## Conclusion

Cloud Armor gives you a powerful application-layer control plane that operates at Google's edge, well upstream of your backend services. The architecture is clean — one policy can cover multiple backend services, enforcement is at the edge PoPs, and the CEL expression language gives you flexibility for custom rules that go well beyond what the preconfigured OWASP sets cover.

The configuration details that actually determine whether a Cloud Armor deployment provides meaningful protection are not particularly glamorous: enabling JSON parsing, setting the default rule to deny, sizing the body inspection window correctly, and adding path-specific rate limits for sensitive endpoints. Get those right with Terraform so they are version-controlled and consistently applied across environments, and you have a WAF that is auditable, repeatable, and actually effective.

From here, explore Cloud Armor adaptive protection for ML-based threat detection, and look at Cloud Armor edge security policies if you have Cloud CDN in your stack. Both build on the same `google_compute_security_policy` resource model and the patterns in this post transfer directly.

If you want to extend your GCP security posture beyond the edge, [automating Security Command Center findings with Cloud Functions](/gcp-security-command-center-cloud-functions/) pairs well with the Cloud Logging queries shown above — SCC surfaces Cloud Armor adaptive protection alerts alongside other threat findings. For the IAM side of the same Terraform project, [managing GCP IAM roles and service accounts with Terraform](/gcp-iam-fundamentals-terraform/) covers the principal and binding model that governs who can modify the security policies you just built. And if your backend services run on Kubernetes, [runtime security with Falco](/falco-runtime-security-kubernetes/) adds a host-level detection layer that complements what Cloud Armor enforces at the edge.

Happy scripting!
