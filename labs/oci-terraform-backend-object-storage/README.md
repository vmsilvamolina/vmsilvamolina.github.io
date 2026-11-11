# Lab: Terraform OCI Backend — Securing State in Object Storage

Post: `_posts/2026/2026-11-09-oci-terraform-backend-object-storage.md` → `/oci-terraform-backend-object-storage/`

Cost: Always Free (DEFAULT vault, SOFTWARE key, 1 bucket, 2 service logs, 1 throwaway IAM user).
Time: ~25 min including IAM propagation waits.

## Run

```bash
cp lab.env.example lab.env   # fill TENANCY_OCID, profile, region
./scripts/00-preflight.sh    # versions, namespace, compartment, logging service names
./scripts/10-deploy.sh       # bootstrap stack, local state
./scripts/20-migrate.sh      # backend "oci" + migrate-state (AUTH=SecurityToken for the post's flow)
./scripts/30-validate-posture.sh
./scripts/40-lock-test.sh
./scripts/50-iam-tests.sh    # OBJECT_OVERWRITE, prefix policy, negative test
./scripts/51-iam-matrix.sh   # isolates OBJECT_OVERWRITE vs read buckets; outsider propagation
./scripts/52-ci-prefix-fix.sh # validates the split prefix policy + workspace_key_prefix
./scripts/60-access-logs.sh  # re-run after 5-10 min if no events
./scripts/90-teardown.sh
```

Every script appends `PASS/FAIL/NOTE` lines to `results/summary.txt`; full output in `results/NN-*.txt`.

## Results (run 2026-11-11)

Terraform 1.15.5 · `oracle/oci` v9.12.1 · OCI CLI 3.86.0 · sa-saopaulo-1 · Always Free tenancy.

| # | Claim in the post | Result | Evidence |
|---|---|---|---|
| 1 | 4-permission policy (HashiCorp docs) breaks on the 2nd apply; needs `OBJECT_OVERWRITE` | ✅ **confirmed** | 51 matrix: apply 1 ok, apply 2 `Failed to save state` on `PutObject` (404 `BucketNotFound`); CLI put-new ok, put-overwrite denied |
| 1b | `read buckets` statement is needed | ❌ **not needed** | `five_norb` (no read buckets) passes everything |
| 2 | `target.object.name = /network\/*/` is a prefix match | ✅ confirmed for object ops | 50 C0: PutObject `network/` ok, `apps/` denied |
| 3 | `ListObjects` may not evaluate `target.object.name` | ✅ **confirmed, and worse**: `terraform init` fails | 50 C1: `Failed to get existing workspaces` (ListObjects 404). **Fix validated (52)**: split `OBJECT_INSPECT` (bucket-only) from READ/CREATE/OVERWRITE/DELETE (prefix) + `workspace_key_prefix = "network/env"` |
| 4 | No `OBJECT_VERSION_DELETE` / `manage buckets` → can't purge versions or create PARs | ✅ confirmed | 50 B |
| 5 | Outsider gets `NotAuthorizedOrNotFound` / 404 | ✅ confirmed, wording: error is **`BucketNotFound` 404** | 51 D: denied ~124 s after group removal |
| 6 | Service log `service=objectstorage`, categories `read`/`write` | ✅ confirmed | `oci logging service list` |
| 7 | `oci os object head` shows `opc-sse-kms-key-id` | ❌ **no** — verify CMK with `oci os bucket get` | 30 |
| 8 | `oci os object get --version-id` | ✅ confirmed, restore works | 30 |
| 9 | Lock = `<key>.lock` via `If-None-Match: *`, LockInfo in error, removed after run | ✅ confirmed: `412 IfNoneMatchFailed` + Lock Info | 40 |
| 10 | Lock PUT has no SSE header | ✅ consistent (no SSE header on head of `.lock`) | 40 |
| 11 | Noncurrent `.lock` versions pile up | ✅ confirmed: every run = 1 version + 1 delete marker | 40 |
| 12 | Logging Search query grammar from the post works; fields exist | ✅ confirmed (131 events); extra useful fields: `isPar`, `authenticationType`, `userAgent`, `principalId` | 60 |
| 13 | KMS auth error right after policy create | not hit (with 30 s `time_sleep`) | 10 |
| 14 | Dot in bucket name rejected by backend | not run | — |
| 15 | Backend ApiKey args (`tenancy_ocid/user_ocid/fingerprint/private_key_path`) | ✅ work | 50/51 |

Extra findings not in the post:

- IAM propagation for a **new policy / user / API key** needed 90–120 s before results were stable; at 60–90 s ListObjects was still intermittently denied.
- Denials surface as **404 `BucketNotFound`**, never 401/403 — the post should say so where it shows expected errors.
- Default `workspace_key_prefix` (`tf-state-env`) puts non-default workspaces outside a stack prefix: `workspace new` fails on the lock PUT.
- A failed state persist leaves `errored.tfstate` (plaintext) in the working dir — now gitignored.
- Lab bug fixed along the way: `terraform_data` updates in place don't re-run provisioners → probe uses `triggers_replace`.

Raw output: `results/*.txt`, matrix: `results/51-matrix.md`.

## Screenshots

Save to `assets/images/postsImages/OCI_TFState_NN.png`. Terminal: dark theme, ~100 cols, crop to the relevant block, redact nothing except the tenancy OCID if you want.

| NN | What | Where in the post | Source |
|---|---|---|---|
| 01 | Console: bucket details (Visibility Private, Versioning Enabled, Encryption Key = tfstate-key, Emit Object Events) | after "The Versioned, Encrypted Bucket" bullets | Console > Storage > Buckets |
| 02 | Console: Lifecycle Policy Rules tab with both rules | end of "Lifecycle Instead of Retention Rules" | Console > bucket > Lifecycle Policy Rules |
| 03 | Console: Logs tab on the bucket, read + write enabled | end of "Object Storage Access Logs" | Console > bucket > Logs |
| 04 | Terminal: `terraform init -migrate-state` success + `oci os object list` showing `bootstrap/terraform.tfstate` | after the migrate code block | 20 |
| 05 | Terminal: second `terraform plan` failing with "Error acquiring the state lock" + Lock Info | "The State Lock" | 40 |
| 06 | Terminal: object list showing `.tfstate` and `.tfstate.lock` side by side | "The State Lock" | 40 |
| 07 | Terminal: 2nd apply with 4 perms → `Failed to save state` / `PutObject` — **the money shot** | "The OBJECT_OVERWRITE Test" and/or the opening | `MODES=four ./scripts/51-iam-matrix.sh` |
| 08 | Terminal: same apply succeeding after adding `OBJECT_OVERWRITE` | "The OBJECT_OVERWRITE Test" | 50 |
| 09 | Terminal: `list-object-versions` with the pile of `.lock` versions | gotcha "Lock files pile up as versions" | 40 |
| 10 | Console: Logging Search with a GET on `bootstrap/terraform.tfstate` showing principalName / IP | "No PARs, and Someone Is Watching" | 60 + Console |
| 11 | Terminal: outsider `terraform init` → `BucketNotFound` 404 | end of testing section | 51 (D) |
| 12 | Terminal: prefix policy → `init` fails `Failed to get existing workspaces` | CI prefix policy section | 50 (C1) |

## After running: update the post

Go through `results/summary.txt`. For each claim:

- **PASS** → remove the "I haven't verified / test it in your lab" hedge and state the observed result (keep the date + versions: Terraform x.y, provider x.y, CLI x.y).
- **FAIL** → correct the text/code in the post and the lab.
- **NOTE** → reword to match what was observed.

Then embed screenshots and run `/validate-post`.
