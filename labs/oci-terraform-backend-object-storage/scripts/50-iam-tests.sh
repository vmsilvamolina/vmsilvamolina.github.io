#!/usr/bin/env bash
# The key test of the post: does the HashiCorp four-permission policy break on the 2nd apply (OBJECT_OVERWRITE)?
# Then: prefix scoping with target.object.name, ListObjects under that policy, and the negative test.
# Every check is gated: if init (or auth) fails, the result is INCONCLUSIVE, never PASS.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/50-iam-tests.txt") 2>&1
WAIT="${POLICY_WAIT:-90}"   # seconds for IAM policy propagation after each policy change
export SUPPRESS_LABEL_WARNING=True
inconclusive() { note "INCONCLUSIVE $*"; }

KEYS="$LAB_DIR/keys"
if [[ ! -f "$KEYS/operator.pem" ]]; then
  openssl genrsa -out "$KEYS/operator.pem" 2048 2>/dev/null
  chmod 600 "$KEYS/operator.pem"
  openssl rsa -pubout -in "$KEYS/operator.pem" -out "$KEYS/operator_public.pem" 2>/dev/null
fi

tfv() { (cd "$LAB_DIR/iam-test" && terraform output -raw "$1"); }

iam_apply() { # mode
  (cd "$LAB_DIR/iam-test" && terraform init -input=false >/dev/null && terraform apply -auto-approve -input=false \
    -var tenancy_ocid="$TENANCY_OCID" -var compartment_id="$COMPARTMENT_OCID" \
    -var compartment_name="$COMPARTMENT_NAME" -var region="$REGION" -var bucket_name="$BUCKET_NAME" \
    -var config_file_profile="$OCI_CLI_PROFILE" -var public_key_path="$KEYS/operator_public.pem" \
    -var policy_mode="$1" >/dev/null) || { fail "iam-test apply mode=$1"; exit 1; }
  (cd "$LAB_DIR/iam-test" && terraform output -json statements | python3 -c 'import json,sys;[print(s) for s in json.load(sys.stdin)]')
  cat > "$KEYS/oci_config" <<CFG
[OP]
user=$(tfv user_id)
fingerprint=$(tfv fingerprint)
tenancy=$TENANCY_OCID
region=$REGION
key_file=$KEYS/operator.pem
CFG
  chmod 600 "$KEYS/oci_config"
  echo "waiting ${WAIT}s for IAM propagation..."; sleep "$WAIT"
}

op() { oci --config-file "$KEYS/oci_config" --profile OP "$@"; }

wait_auth() { # new user/API key can take minutes to authenticate
  for i in $(seq 1 30); do
    op os ns get >/dev/null 2>&1 && { echo "operator authenticates after ~$((i*10))s of polling"; return 0; }
    sleep 10
  done
  fail "operator never authenticated (5 min)"; exit 1
}

op_backend() { # key [workspace_key_prefix]
  local extra=( 'auth = "ApiKey"' "tenancy_ocid = \"$TENANCY_OCID\"" "user_ocid = \"$(tfv user_id)\""
                "fingerprint = \"$(tfv fingerprint)\"" "private_key_path = \"$KEYS/operator.pem\"" )
  [[ -n "${2:-}" ]] && extra+=( "workspace_key_prefix = \"$2\"" )
  probe_backend "$1" "${extra[@]}"
}

probe_apply() { (cd "$LAB_DIR/probe" && terraform apply -auto-approve -input=false -var revision="$1" 2>&1); }
is_authz() { grep -qE 'NotAuthorized|BucketNotFound|ObjectNotFound|40[34]'; }

# ---------------------------------------------------------------------------
hdr "TEST A: four-permission policy (HashiCorp docs)"
iam_apply four
wait_auth
KEY="overwrite-test/terraform.tfstate"
for v in $(oci os object list-object-versions --bucket-name "$BUCKET_NAME" --prefix "$KEY" --all \
           --query 'data[].join(`|`, [name, "version-id"])' --raw-output 2>/dev/null | python3 -c 'import json,sys;[print(x) for x in json.load(sys.stdin)]' 2>/dev/null); do
  oci os object delete --bucket-name "$BUCKET_NAME" --name "${v%%|*}" --version-id "${v##*|}" --force >/dev/null 2>&1
done
op_backend "$KEY"

if run probe_init; then
  hdr "A1: first apply (creates state object) -> expect success"
  if out=$(probe_apply 1); then
    echo "$out" | tail -3; pass "A1 first apply with 4 perms succeeded"
    hdr "A2: second apply (overwrites state object) -> post expects FAILURE  <-- SCREENSHOT"
    if out=$(probe_apply 2); then
      echo "$out" | tail -3
      fail "A2 REFUTED: second apply succeeded without OBJECT_OVERWRITE -> post opening must change"
    else
      echo "$out" | tail -25
      echo "$out" | is_authz && pass "A2 CONFIRMED: 2nd apply denied without OBJECT_OVERWRITE" \
                             || inconclusive "A2 failed for a non-authz reason"
    fi
  else
    echo "$out" | tail -25; inconclusive "A1 failed (4 perms cannot even create state)"
  fi
else
  inconclusive "A: init as operator failed"
fi
oci os object delete --bucket-name "$BUCKET_NAME" --name "$KEY.lock" --force >/dev/null 2>&1

# ---------------------------------------------------------------------------
hdr "TEST B: five-permission policy (post's corrected policy)"
iam_apply five
if run probe_init; then
  out=$(probe_apply 3); rc=$?; echo "$out" | tail -4
  [[ $rc -eq 0 ]] && pass "B apply (overwrite) succeeds with OBJECT_OVERWRITE  <-- SCREENSHOT" || fail "B apply with 5 perms failed"
  out=$(probe_apply 4); rc=$?
  [[ $rc -eq 0 ]] && pass "B repeat apply succeeds" || fail "B repeat apply failed"
else
  fail "B: init as operator failed with 5 perms"
fi

hdr "B: OBJECT_VERSION_DELETE absent -> operator cannot purge history"
vid=$(oci os object list-object-versions --bucket-name "$BUCKET_NAME" --prefix "$KEY" --all \
      --query "data[?name=='$KEY'] | [-1].\"version-id\"" --raw-output)
echo "target version: $vid"
if [[ -n "$vid" && "$vid" != "None" ]]; then
  out=$(op os object delete --bucket-name "$BUCKET_NAME" --name "$KEY" --version-id "$vid" --force 2>&1); rc=$?
  echo "$out" | grep -E '"code"|"status"|"message"'
  [[ $rc -ne 0 ]] && pass "operator cannot delete a version" || fail "operator deleted a version"
else
  inconclusive "no state version to test version delete"
fi

hdr "B: operator cannot create a PAR"
out=$(op os preauth-request create --bucket-name "$BUCKET_NAME" --name lab-par --access-type ObjectRead \
      --object-name "$KEY" --time-expires "$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)" 2>&1); rc=$?
echo "$out" | grep -E '"code"|"status"|"message"'
[[ $rc -ne 0 ]] && pass "operator cannot create PAR" || fail "operator created a PAR (delete it!)"

# ---------------------------------------------------------------------------
hdr "TEST C: prefix-scoped policy target.object.name = /network\\/*/"
iam_apply prefix

hdr "C0: plain object ops under prefix policy (no terraform), via CLI"
echo '{}' > "$RESULTS/c0.json"
out=$(op os object put --bucket-name "$BUCKET_NAME" --name network/cli-probe.json --file "$RESULTS/c0.json" --force 2>&1); rc=$?
echo "$out" | grep -E '"code"|"status"|etag' | head -3
[[ $rc -eq 0 ]] && pass "C0 PutObject network/cli-probe.json allowed" || fail "C0 PutObject on network/ denied (pattern not a prefix match)"
out=$(op os object put --bucket-name "$BUCKET_NAME" --name apps/cli-probe.json --file "$RESULTS/c0.json" --force 2>&1); rc=$?
echo "$out" | grep -E '"code"|"status"' | head -2
[[ $rc -ne 0 ]] && pass "C0 PutObject apps/ denied" || fail "C0 PutObject apps/ allowed (too broad)"
out=$(op os object list --bucket-name "$BUCKET_NAME" --prefix network/ 2>&1); rc=$?
echo "$out" | grep -E '"code"|"status"|"name"' | head -3
[[ $rc -eq 0 ]] && pass "C0 ListObjects prefix=network/ allowed" || note "C0 ListObjects denied under target.object.name policy"

hdr "C1: terraform init/apply on network/terraform.tfstate"
op_backend "network/terraform.tfstate" "network/env"
if out=$(probe_init 2>&1); then
  pass "C1 init allowed under prefix policy"
  (probe_apply 1 >/dev/null && probe_apply 2 >/dev/null) && pass "C1 apply x2 on network/ allowed" || fail "C1 apply on network/ denied"
  hdr "C2: workspace new/list"
  (cd "$LAB_DIR/probe" && run terraform workspace new dev && run terraform workspace list) \
    && pass "C2 workspace ops work under prefix policy" || fail "C2 workspace ops denied"
  (cd "$LAB_DIR/probe" && terraform workspace select default >/dev/null 2>&1)
else
  echo "$out" | grep -E 'Error|Status Code|Message' | head -4
  echo "$out" | grep -q 'Failed to get existing workspaces' \
    && fail "C1 init DENIED: workspace ListObjects is blocked by target.object.name -> prefix policy unusable as written  <-- SCREENSHOT" \
    || fail "C1 init failed (other reason)"
fi

hdr "C3: apps/ denied"
op_backend "apps/terraform.tfstate"
if probe_init >/dev/null 2>&1; then
  out=$(probe_apply 1); rc=$?
  [[ $rc -ne 0 ]] && pass "C3 prefix policy denies apps/ apply" || fail "C3 prefix policy allowed apps/"
else
  inconclusive "C3 init on apps/ failed (consistent with C1 if C1 init also failed)"
fi
oci os object delete --bucket-name "$BUCKET_NAME" --name network/cli-probe.json --force >/dev/null 2>&1

# ---------------------------------------------------------------------------
hdr "TEST D: negative test, user outside the group  <-- SCREENSHOT"
iam_apply five   # restore a working policy so D isolates group membership
gid=$(oci iam group list --compartment-id "$TENANCY_OCID" --name tfstate-lab-operators --query 'data[0].id' --raw-output)
op_backend "$KEY"
probe_init >/dev/null 2>&1 && pass "D precheck: member can init" || inconclusive "D precheck: member cannot init"
run oci iam group remove-user --group-id "$gid" --user-id "$(tfv user_id)" --force >/dev/null
echo "waiting ${WAIT}s for membership change..."; sleep "$WAIT"
out=$(probe_init 2>&1); rc=$?
echo "$out" | grep -E 'Error|Status Code|Message' | head -4
[[ $rc -ne 0 ]] && pass "D outsider denied at init" || fail "D outsider could init"
echo "Membership is re-created by the next iam-test apply; 90-teardown.sh destroys everything."
