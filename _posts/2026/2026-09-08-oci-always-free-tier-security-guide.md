---
title: 'OCI Always Free Tier Security: A Zero-Bill Lab Guide'
author: Victor Silva
date: 2026-09-08T21:59:38+00:00
layout: post
permalink: /oci-always-free-tier-security-guide/
excerpt: "Running an OCI Always Free tier security lab? The real threat is your bill. Lock spend down with compartment quotas, budget alerts, and Cloud Guard."
categories:
  - OCI
  - Security
tags:
  - oci-always-free
  - oci-security
  - cloud-guard
  - compartment-quotas
  - oci-budgets
  - cryptomining-defense
  - oracle-cloud-infrastructure
  - cis-oci-foundations
---

When you stand up a home lab on Oracle Cloud Infrastructure's Always Free tier, the instinct is to threat-model the workloads first: which ports are open, what sits on the public subnet, whether the database is encrypted at rest. On an OCI Always Free tier security lab, that is the wrong first move. The asset most likely to be attacked, and the one with the largest blast radius, is your billing relationship with Oracle. A leaked Console password or an API key committed to a public repo does not just get an attacker a shell on a 1 GB micro instance. On the wrong account type, it gets them a fleet of GPU shapes mining Monero on your credit card until the invoice email wakes you up.

So this post treats spend as the threat model. Everything else — network exposure, IAM hygiene, audit retention — still matters, and we will get to all of it, but the organizing principle is: **an attacker who compromises this tenancy must not be able to cost me money.** That single constraint drives an early architectural decision that most "OCI free tier" write-ups skip entirely.

## The decision: pure Always Free versus Pay As You Go

There are three things people call "the free tier" and conflate constantly:

- **Free Trial** — US$300 in credits, 30 days, provision anything. When the trial ends, paid resources are reclaimed unless you upgrade; Always Free resources keep running.
- **Always Free** — a fixed set of resources that never expire, capped by hard quotas. With no payment method on file, exceeding a cap means the API call fails or an idle resource gets reclaimed. The spend ceiling is literally zero, and Oracle enforces it for you.
- **Pay As You Go (PAYG)** — you add a payment method and pay only for usage above the Always Free allowances. You keep every Always Free resource, you skip the "Out of host capacity" queue for paid shapes, and — this is the part that matters for a security lab — you unlock Cloud Guard, Security Zones, and Security Advisor.

Here is the tension. Cloud Guard (OCI's CSPM and workload-protection service) and Security Zones (policy enforcement that denies non-compliant API calls outright) are **not available on a pure Always Free tenancy**. They require a paid account type. Both are free to *use* once the account is PAYG — you pay nothing for Cloud Guard's standard detectors or for Security Zones — but you cannot turn them on at all without a card on file.

{% highlight text %}
                    ┌─────────────────────────────────────────────┐
                    │  Do you want Cloud Guard / Security Zones /  │
                    │  Security Advisor in your lab?               │
                    └───────────────┬─────────────────────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │ NO                                        │ YES
              ▼                                           ▼
   ┌───────────────────────┐                 ┌────────────────────────────┐
   │  Pure Always Free      │                 │  Convert to PAYG           │
   │  No payment method     │                 │  Payment method on file    │
   │  Spend ceiling = $0     │                 │  $0 at free-tier usage     │
   │  Oracle enforces it     │                 │  Stolen creds CAN bill you │
   │                         │                 │  → quotas + budgets are    │
   │  Native security stack  │                 │    now mandatory, not      │
   │  partly unavailable     │                 │    optional                │
   └───────────────────────┘                 └────────────────────────────┘
{% endhighlight %}

My recommendation: **if you are learning the OCI-native security services, convert to PAYG and put the guardrails from section five in place before you do anything else.** The guardrails are not hard, they are the point of the exercise, and building them is better lab practice than avoiding the problem. If your lab is about self-hosted tooling and you never intend to touch Cloud Guard, stay on pure Always Free and enjoy the fact that Oracle is holding the circuit breaker for you.

Either way, most of the useful security services are free on a pure Always Free tenancy. Let's be precise about what you actually get.

## What the OCI Always Free tier gives you in 2026

The Always Free allowances move. Oracle changed them without much notice in 2026 — most significantly, the Ampere A1 Flex compute allowance was **halved on 15 June 2026**, from 4 OCPU / 24 GB down to roughly 2 OCPU / 12 GB (1,500 OCPU-hours plus 9,000 GB-hours per month) for pure Always Free accounts. PAYG accounts still get the old 4 OCPU / 24 GB of A1 for free. Because these numbers drift, treat the table below as a snapshot and verify against the live [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm) document before you design around any single limit.

| Resource | Always Free allowance (2026 snapshot) | Notes for a security lab |
|---|---|---|
| Ampere A1 Flex compute | ~2 OCPU / 12 GB total (1,500 OCPU-h + 9,000 GB-h / month) | Halved 15 Jun 2026. Home region only. Split across 1–2 instances. |
| AMD `VM.Standard.E2.1.Micro` | 2 instances, 1/8 OCPU + 1 GB RAM each | Ephemeral public IP each. Home region only. Good for a always-on sidecar. |
| Block Volume | 200 GB total (boot + block), 5 backups | Min boot volume 47 GB. Two full instances eat most of this. |
| Object Storage | 20 GB combined (Standard + IA + Archive), 50,000 requests/month | This cap bites when you export audit logs — plan lifecycle rules. |
| Autonomous Database | 2 ADB, 1 ECPU, 20 GB each, 20 sessions | Auto-stops after 7 days idle; permanently reclaimed after 90 cumulative idle days. |
| VCN | 2 per tenancy | Quick-start wizard adds a `0.0.0.0/0 → TCP 22` ingress rule. Remove it. |
| Flexible Load Balancer | 1, fixed 10 Mbps (min = max) | Only free at exactly 10 Mbps, and only for tenancies created after 15 Dec 2020. |
| Network Load Balancer | 1 Always Free NLB (L4) | Separate allowance from the flexible LB. |
| Monitoring | 500M ingestion + 1B retrieval datapoints / month | Enough for alarms on every instance you can afford to run. |
| Notifications | 1M HTTPS + 1,000 email / month | The delivery path for budget and alarm alerts. |
| Logging | 10 GB / month ingestion, shared across all custom logs | VCN Flow Logs count against this. Sample aggressively if noisy. |
| Audit | Always on, 365-day retention, cannot be disabled | Free. The risk is not exporting before the window rolls. |
| Connector Hub | Service free for everyone; 2 Always Free connectors | The glue for routing logs to Object Storage. |
| Vault | Software-protected keys/versions unlimited; 150 secrets | HSM-protected keys and Virtual Private Vaults are **not** free. |
| Certificates | 5 CAs, 150 certificates | Private CA + TLS certs, free. |
| Bastion | Free on free and paid | Managed SSH session TTL 30–180 min. Needs Cloud Agent + Bastion plugin. |
| Outbound data transfer | 10 TB / month per the doc | See the gotchas section — 2026 third-party reporting says egress charges were removed globally. Verify. |

### Is Cloud Guard free on OCI? Which security services work on pure Always Free

| Service | Pure Always Free? | Comment |
|---|---|---|
| Cloud Guard (CSPM + workload protection) | No | Requires a paid/PAYG account type. Free to use once paid. |
| Security Zones | No | Requires paid. Free once paid. |
| Security Advisor | No | Depends on Cloud Guard + Security Zones. |
| Vulnerability Scanning Service (VSS) | Yes | Host, container, and IaC scans, all free. |
| Bastion | Yes | Free everywhere. |
| Vault (software keys, shared vault) | Yes | Free within the key/secret limits. |
| Certificates | Yes | Private CA and TLS certificates, free. |
| Audit | Yes | Always on, 365 days, free. |
| Logging + VCN Flow Logs | Yes | Free up to the shared 10 GB/month ingestion cap. |
| Connector Hub | Yes | Free for everyone; 2 Always Free connectors. |
| WAF | Treat as "not reliably free" | A regional WAF policy attaches to the free flexible LB; edge WAF is metered. Confirm on the live pricing page. |

The takeaway: even without a card on file, you can run VSS, Bastion, Vault, Certificates, Audit, and Flow Logs. That is a legitimate security baseline. What you give up is the managed CSPM layer — the continuous configuration checks and the activity detectors — which you would otherwise get from [Cloud Guard detection rules](/oci-cloud-guard-detection-rules/) and [Security Zones](/oci-security-zones/).

## What security tooling actually fits in 2 OCPU / 12 GB

Before June 2026 the classic advice was "run Wazuh on the free A1 and you're set." That advice is now wrong. A single-node Wazuh all-in-one wants a minimum of 2 vCPU / 4 GB and really wants 4 vCPU / 8 GB — it consumes your entire A1 allowance and leaves nothing for anything else. Re-budget everything against the current numbers.

| Stack | Footprint (post-June-2026) | Verdict |
|---|---|---|
| Tailscale/WireGuard subnet router + Pi-hole + unbound | 0.25–0.5 vCPU, 512 MB–1 GB, 10 GB disk | **Top pick.** Fits on an AMD E2.1.Micro, leaving the A1 free. |
| Gitea + 1 CI runner (Checkov/Trivy/tfsec in-pipeline) | ~1 vCPU, 1.5–2 GB, 20–30 GB | **Top pick.** Private DevSecOps pipeline on the A1. |
| Prometheus + Grafana + Loki (single node, short retention) | ~1 vCPU, 2–3 GB, 30–50 GB | **Top pick.** Alerting backbone for cost/egress/auth anomalies. |
| Vaultwarden | ~0.25 vCPU, 512 MB, 5 GB | **Top pick (small).** Runs on an AMD micro. |
| Scheduled Trivy/Grype/Nuclei scanning box (cron) | 1–2 vCPU + 2–4 GB during scans | Fits if scheduled and co-located with the CI box. |
| Wazuh single-node all-in-one | min 2 vCPU / 4 GB, rec. 4 vCPU / 8 GB, 50 GB | Marginal. Dedicated build only — nothing else fits alongside. |
| Greenbone / OpenVAS (GVM) | 2 vCPU / 4–8 GB, 40+ GB | Tight. Feasible solo, painful with anything else. |
| T-Pot (full) | 6–8 GB RAM, 2+ vCPU, 128 GB disk | Does not fit. A hand-picked subset (cowrie + dionaea in Docker) fits in ~1 vCPU / 1–2 GB. |
| CodeQL runner | ~8 GB+ for non-trivial databases | Small repos only. |

The strongest lab you can build on a pure Always Free tenancy today is: an AMD micro running **WireGuard/Tailscale plus a DNS sinkhole** as the only private entry point (this kills public SSH and gives you DNS telemetry), the A1 running **Gitea plus a CI runner** with [Checkov/Trivy/tfsec](/trivy-github-actions-container-iac-scanning/) and [SBOM generation](/sbom-trivy-syft/) for a private supply-chain pipeline, and — if you have headroom — **Prometheus + Grafana + Loki** ([the same stack from the Kubernetes monitoring post](/prometheus-grafana-kubernetes-monitoring/)) as the place your cost and audit alarms land. If a SIEM is the entire point of your lab, reserve the whole A1 for a dedicated Wazuh node and accept that nothing else runs beside it.

## Free OCI security services to turn on immediately

Everything in this section is free on a pure Always Free tenancy. Do it on day one, before you deploy a single workload.

### Vulnerability Scanning Service

VSS gives you CIS benchmark checks, CVE detection, and open-port reporting on your compute hosts, plus container image and IaC scanning. Host scans need the Oracle Cloud Agent with the **Vulnerability Scanning** plugin enabled on the instance (it ships on the standard Oracle Linux images; enable the plugin in the instance's `agent_config`).

Create a recipe and a target that scans a whole compartment, so any instance you launch later is picked up automatically:

{% highlight bash %}
oci vulnerability-scanning host scan-recipe create \
  --compartment-id "$COMP_OCID" \
  --display-name "cis-and-cve-daily" \
  --agent-settings '{"scanLevel":"STANDARD"}' \
  --cis-benchmark-settings '{"scanLevel":"STRICT"}' \
  --port-settings '{"scanLevel":"STANDARD"}' \
  --schedule '{"type":"DAILY"}'

oci vulnerability-scanning host scan-target create \
  --compartment-id "$COMP_OCID" \
  --host-scan-recipe-id "$RECIPE_ID" \
  --display-name "free-tier-hosts" \
  --target-compartment-id "$COMP_OCID"
{% endhighlight %}

The Terraform walkthrough for this — including the container and IaC scan recipes — is in the [OCI Vulnerability Scanning Service post](/oci-vulnerability-scanning-terraform/).

### Vault, the free way

The free path is the **default shared vault with software-protected keys**. Do not create a Virtual Private Vault — it is not free, and there is no free tier for it. Software keys have no version cap; you get 150 secrets with 40 versions each. That is more than enough for a lab's TLS keys, database credentials, and API tokens.

Give your automation on the A1 box access to secrets through an **instance principal and a dynamic group**, never a static API key. The pattern — dynamic group matching the instance OCID, policy granting `read secret-family` scoped to one compartment — is covered in the [OCI Vault secrets management post](/oci-vault-secrets-management-terraform/) and the [OCI IAM with Terraform post](/oci-iam-terraform/).

### Bastion instead of a public SSH port

Do not put SSH on the internet. Launch instances into a private subnet with the Bastion plugin enabled, stand up a Bastion resource against that subnet, and open sessions on demand:

{% highlight bash %}
oci bastion session create-managed-ssh \
  --bastion-id "$BASTION_ID" \
  --target-resource-id "$INSTANCE_OCID" \
  --target-os-username opc \
  --ssh-public-key-file ~/.ssh/id_ed25519.pub \
  --session-ttl 1800
{% endhighlight %}

Every session create and delete lands in Audit. Keys are injected for the session TTL and removed afterward — no permanent key material on the host. Full Terraform build, including the security list rule that must reference the bastion's `private_endpoint_ip_address` rather than a subnet CIDR, is in the [OCI Bastion Service post](/oci-bastion-service-terraform/).

### Logging with VCN Flow Logs, routed to Object Storage

Flow Logs are a CIS control (3.5) and they are free within the shared 10 GB/month Logging cap. Enable a flow log on your subnet, then use a Connector Hub to copy log records into an Object Storage bucket so you have them beyond the Logging retention window:

{% highlight bash %}
oci logging log create \
  --log-group-id "$LOG_GROUP_ID" \
  --display-name "vcn-flow-logs" \
  --log-type SERVICE \
  --configuration '{"source":{"sourceType":"OCISERVICE","service":"flowlogs","resource":"'"$SUBNET_OCID"'","category":"all"},"compartmentId":"'"$COMP_OCID"'"}' \
  --is-enabled true

oci sch service-connector create \
  --display-name "flowlogs-to-bucket" \
  --compartment-id "$COMP_OCID" \
  --source '{"kind":"logging","logSources":[{"compartmentId":"'"$COMP_OCID"'","logGroupId":"'"$LOG_GROUP_ID"'"}]}' \
  --target '{"kind":"objectStorage","bucketName":"security-logs","namespace":"'"$NAMESPACE"'"}'
{% endhighlight %}

Watch the 10 GB Logging cap. On a busy subnet, set the flow log category to a sampled subset or scope it to specific NSGs rather than `all`.

### Audit export

Audit is always on with 365-day retention and cannot be disabled — that already satisfies CIS 3.1. The gap is that the window rolls. If you want records older than a year, or you want them queryable outside the Console, add a second Connector Hub with an **audit** source pointing at the same bucket, and put a lifecycle policy on the bucket (section six) so it stays under the 20 GB Object Storage cap.

## Spend as a security control: compartment quotas and budget alerts

On PAYG, the only *synchronous* control on spend is a **compartment quota policy**. Quotas are evaluated at resource-creation time: if a `LaunchInstance` call asks for a shape whose core-count quota is zero, the call fails immediately. Budgets, by contrast, evaluate every 24 hours — a budget alert is a smoke alarm that tells you the house is already burning. Quotas are the breaker.

### The quota lockdown: compartment quotas to limit spend

Quota policy statements live in the **root (tenancy) compartment** only. The language mirrors IAM policy. The allowlist pattern is: zero out the entire `compute-core` family, then `set` back only the shapes you actually want, and separately zero the expensive families by wildcard.

{% highlight text %}
zero compute-core quotas in tenancy
set compute-core quota standard-a1-core-count to 2 in tenancy where request.region = sa-saopaulo-1
set compute-core quota standard-e2-core-count to 1 in tenancy where request.region = sa-saopaulo-1
zero compute-core quota /*gpu*/ in tenancy
zero compute-core quota /*dense-io*/ in tenancy
zero compute-core quota /*bm-*/ in tenancy
zero database quota /*exadata*/ in tenancy
set block-storage quota total-storage-gb to 200 in tenancy
set object-storage quota storage-bytes to 21474836480 in tenancy
zero load-balancer quota lb-100mbps-count in tenancy
zero load-balancer quota lb-400mbps-count in tenancy
{% endhighlight %}

Two things trip people up here. First, **you cannot restrict instance shape with an IAM policy condition** — there is no shape variable available at `INSTANCE_CREATE`. Shape control is done entirely through quotas, via the shape-family core-count quota names (`standard-a1-core-count`, `standard-e2-core-count`, `standard-e4-core-count`, the `gpu*` families, and so on). Second, the exact quota names vary by service and region. Use the Console's **"Create Quota Policy Stub"** and **"Available Quotas by Service"** helpers to get the precise names for your home region rather than guessing.

In Terraform:

{% highlight hcl %}
resource "oci_limits_quota" "free_tier_lockdown" {
  compartment_id = var.tenancy_ocid
  name           = "free-tier-lockdown"
  description    = "Block all paid shapes; allow only Always Free compute"
  statements = [
    "zero compute-core quotas in tenancy",
    "set compute-core quota standard-a1-core-count to 2 in tenancy where request.region = ${var.home_region}",
    "set compute-core quota standard-e2-core-count to 1 in tenancy where request.region = ${var.home_region}",
    "zero compute-core quota /*gpu*/ in tenancy",
    "zero compute-core quota /*dense-io*/ in tenancy",
    "zero database quota /*exadata*/ in tenancy",
    "set block-storage quota total-storage-gb to 200 in tenancy",
  ]
}
{% endhighlight %}

### The budget tripwire: a free-tier budget alert

Set a budget of **US$1** on the tenancy and wire two alert rules: a `FORECAST` rule at 100% (any forecasted spend at all) and an `ACTUAL` rule at an absolute one cent. On a healthy free-tier tenancy both should stay silent forever. Either one firing means something created a billable resource.

{% highlight bash %}
COMPARTMENT_ID=ocid1.tenancy.oc1..aaaa....
EMAIL="you@example.com"

BUDGET_ID=$(oci budgets budget create \
  --compartment-id "$COMPARTMENT_ID" \
  --target-type COMPARTMENT \
  --targets "[\"$COMPARTMENT_ID\"]" \
  --amount 1 --reset-period MONTHLY \
  --display-name "always-free-tripwire" \
  --query 'data.id' --raw-output)

oci budgets alert-rule create --budget-id "$BUDGET_ID" \
  --type FORECAST --threshold 1 --threshold-type PERCENTAGE \
  --recipients "$EMAIL" \
  --message "OCI forecast spend > 0 on the free-tier tenancy - investigate for credential abuse."

oci budgets alert-rule create --budget-id "$BUDGET_ID" \
  --type ACTUAL --threshold 0.01 --threshold-type ABSOLUTE \
  --recipients "$EMAIL" \
  --message "OCI ACTUAL spend recorded on the free-tier tenancy."
{% endhighlight %}

{% highlight hcl %}
resource "oci_budget_budget" "tripwire" {
  compartment_id = var.tenancy_ocid
  amount         = 1
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]
  display_name   = "always-free-tripwire"
}

resource "oci_budget_alert_rule" "forecast" {
  budget_id      = oci_budget_budget.tripwire.id
  type           = "FORECAST"
  threshold      = 1
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
  message        = "Forecast spend > 0 on free-tier tenancy"
}
{% endhighlight %}

Both budgets and quotas are authored with permissions in the **root compartment**, even though a budget can target a child compartment or a cost-tracking tag. The identity that owns them needs `manage usage-budgets in tenancy`.

### Crypto-mining protection: detecting abuse behaviourally

Quotas stop an attacker from launching a GPU shape. They do not stop an attacker from maxing out the CPU on the free instances you already run, or from using them as a proxy. Catch that with Monitoring alarms:

- **CPU pinned plus sustained egress.** An alarm on `CpuUtilization` staying near 100% correlated with elevated `BytesToNetwork` / `VnicToNetworkPackets` over a sustained window is the classic mining signature. On a lab box that is normally idle, this is a high-signal alarm.
- **Instance creation outside your pipeline.** An OCI Events rule matching `com.oraclecloud.computeapi.launchinstance.end`, filtered to exclude the principal your Terraform pipeline uses, tells you when *something else* is launching compute. This is the same signal [Resource Manager drift detection](/oci-resource-manager-drift-detection/) surfaces from the infrastructure side.
- **Launches of shapes not on the allowlist.** Even with quotas in place, an alarm on `LaunchInstance` for any shape outside your known-good list is a useful backstop and a record for the timeline.

Route all of these through Notifications to the same email as the budget alerts, and — if you have Grafana on the A1 — to a dashboard you actually look at.

Once you are on PAYG, layer Cloud Guard on top: enable the OCI-managed **Configuration** and **Activity** detector recipes and the managed threat-intelligence feed. Activity detectors flag anomalous instance launches and connections to known-bad IPs, which is exactly the mining-crew playbook. The setup is in the [Cloud Guard threat intelligence post](/oci-cloud-guard-threat-intelligence-terraform/).

### There is no "disable upgrade to paid" switch

Oracle does not offer a toggle that permanently locks a tenancy to $0. The closest approximations, in order of effectiveness:

1. **Do not add a payment method.** Pure Always Free means the ceiling is genuinely zero and Oracle enforces it. This is the strongest control, and the reason to think hard before converting to PAYG.
2. **Keep the Administrators group tiny.** One break-glass identity, used almost never, ideally the only member.
3. **Scope billing to break-glass only.** An IAM policy where only the break-glass identity can `manage tenancies` or touch billing/payment configuration.
4. **On PAYG, stack quotas + budgets + service-limit reductions.** Request service-limit decreases for shape families you never use, so even a quota mistake has a second wall behind it.

## Hardening checklist for a throwaway tenancy

Treat the lab tenancy as disposable and harden it like one. Each item maps to a control in the [CIS OCI Foundations Benchmark](https://www.cisecurity.org/benchmark/oracle_cloud).

- **Root compartment hygiene.** Nothing runs in the root compartment. One compartment per workload. This keeps quota and budget scoping clean and limits blast radius.
- **No API signing keys on any tenancy admin.** If an identity can administer the tenancy from the Console, it must not also carry API keys. Automation uses instance principals and dynamic groups, not a human admin's key. *(CIS 1.1–1.3 least privilege, 1.13 no API keys for tenancy admin.)*
- **MFA for every user.** Activate the seeded **"Security Policy for OCI Console"** sign-on policy in each identity domain. Its pre-built "MFA for all users" rule forces every local user to enroll a second factor and present it on every Console sign-in. Stage it with an admins-only rule first if you have other users. *(CIS 1.7 / 1.11.)*
- **A dedicated break-glass account.** Separate credentials, stored offline, MFA enrolled, used only to recover access or manage billing. Not your daily identity.
- **No `manage all-resources in tenancy` for working groups.** Grant verbs scoped to a compartment and a resource family. A CI runner that deploys infrastructure gets `manage` on the compartments it owns, nothing wider. See the [OCI IAM with Terraform post](/oci-iam-terraform/) for the policy patterns, and the [unused IAM permissions post](/oci-unused-iam-permissions/) for trimming grants back over time.
- **Remove the VCN wizard's `0.0.0.0/0 → TCP 22` rule.** The quick-start wizard ships it in the default security list. Delete it. *(CIS 2.1/2.2 no unrestricted SSH, 2.5 default security list restricts all.)*

{% highlight bash %}
oci network security-list update \
  --security-list-id "$DEFAULT_SL_ID" \
  --ingress-security-rules '[{"source":"10.0.0.0/16","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}}]' \
  --force
{% endhighlight %}

- **NSGs over security lists.** Network Security Groups are stateful and scoped to the resources you attach them to, rather than every VNIC in a subnet. Use them as the primary control and keep security lists minimal. *(CIS 2.x network exposure.)*
- **Prefer private subnets plus Bastion.** Every Always Free instance gets an ephemeral public IP by default. Put instances on private subnets and reach them through Bastion. *(CIS 2.x exposure.)*
- **Rotate auth tokens and keys.** Any auth token or API key you do issue gets a calendar reminder and a rotation. Lab credentials leak precisely because nobody rotates them.
- **Export audit to a lifecycle-managed bucket.** The Connector Hub from section four writes audit records to Object Storage. Put a lifecycle policy on that bucket — transition to Archive after 30 days, delete after your retention target — so it never approaches the 20 GB Always Free Object Storage cap. *(CIS 3.1 audit retention.)*
- **VCN Flow Logs enabled on every subnet.** *(CIS 3.5.)*

## Gotchas

**A1 capacity.** "Out of host capacity" errors on Ampere A1 launches are common and there is no paid queue-jump on pure Always Free. A1 instances can only run in your **home region**. Retry on a loop, try different availability domains, or script the launch with exponential backoff.

**Idle compute reclamation.** Oracle reclaims idle Always Free compute. The wording to know: an instance may be reclaimed when, over a 7-day period, its CPU utilization 95th percentile is below 20%, network utilization is below 20%, and (A1 only) memory utilization is below 20%. A lab box that only does something once a week can trip this. Give it a small always-on job — a scrape target, a heartbeat — if you need it to survive.

**A1 instances over the new limit.** If your account was created before 15 June 2026 and you had a 4 OCPU / 24 GB A1 instance, the portion over the new ~2 OCPU / 12 GB allowance is disabled and **deleted after 30 days** unless you upgrade to PAYG. Check your instances against the current allowance now.

**Autonomous Database reclamation.** An Always Free ADB **auto-stops after 7 days** of inactivity, and is **permanently reclaimed after 90 cumulative days** stopped or inactive. If you want to keep an ADB, log in and run a query against it more than once a week.

**Load Balancer.** Only the specific **10 Mbps flexible LB** is free, and only for tenancies created after 15 December 2020. Any bandwidth shape above 10 Mbps, or a second load balancer, is billed. The Network Load Balancer is a separate free allowance.

**Egress.** The Always Free doc still says **10 TB/month** of outbound transfer. Separately, February 2026 third-party reporting says Oracle removed outbound data-transfer charges globally across all regions. These two statements are not consistent, and Oracle's own documentation is the one that governs your bill — **verify the current outbound-transfer language on the live pricing and Always Free pages before you rely on either number.**

**Ephemeral public IPs change.** The public IP on an Always Free instance is ephemeral and is reassigned when you stop and start the instance. Do not hardcode it anywhere. If you need a stable address, that is another reason to front everything with WireGuard/Tailscale and Bastion.

**WAF is not reliably free.** A regional WAF policy can attach to the free flexible load balancer, and secondary sources mention a standing "first WAF instance + 10M requests/month" allowance for non-government tenancies — but this is exactly the kind of limit that changes. Confirm on the live WAF pricing page, and keep the distinction clear between an edge WAF (metered) and a regional WAF policy on the LB.

## Conclusion

A free-tier OCI security lab is worth building, but only if you build the threat model that matches it. The workloads are disposable; the billing account is not. Decide early whether you want the OCI-native security stack — Cloud Guard, Security Zones, Security Advisor — badly enough to convert to PAYG, and if you do, put the quota lockdown, the $1 budget tripwire, MFA-for-all, and a break-glass admin in place *before* you deploy anything. If you stay on pure Always Free, you still get VSS, Bastion, Vault, Certificates, Audit, and Flow Logs for nothing, and Oracle holds the circuit breaker on spend for you.

Then spend your OCPU budget deliberately: a private entry point with WireGuard and a DNS sinkhole, a Gitea-plus-CI supply-chain pipeline, and Prometheus/Grafana/Loki as the place your cost and audit alarms actually land. Re-check the Always Free allowances against the live doc every few months, because they move — the June 2026 A1 halving will not be the last change.

Build the guardrails first, break things second.

Happy scripting!
