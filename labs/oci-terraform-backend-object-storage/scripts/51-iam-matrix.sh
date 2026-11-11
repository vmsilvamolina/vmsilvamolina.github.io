#!/usr/bin/env bash
# Isolates the two variables behind test A vs B: OBJECT_OVERWRITE and the "read buckets" statement.
# For each policy mode, as the non-admin operator: raw CLI ops + terraform init/apply/apply.
# Then re-runs the negative test (D) polling until the removed member is actually denied.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/51-iam-matrix.txt") 2>&1
WAIT="${POLICY_WAIT:-120}"
MODES=(${MODES:-four four_rb five_norb five})
export SUPPRESS_LABEL_WARNING=True
KEYS="$LAB_DIR/keys"; BK="$BUCKET_NAME"
[[ -f "$KEYS/operator.pem" ]] || { echo "run 50-iam-tests.sh first (creates operator key)"; exit 1; }

tfv() { (cd "$LAB_DIR/iam-test" && terraform output -raw "$1"); }
op()  { oci --config-file "$KEYS/oci_config" --profile OP "$@"; }
iam_apply() {
  (cd "$LAB_DIR/iam-test" && terraform apply -auto-approve -input=false \
    -var tenancy_ocid="$TENANCY_OCID" -var compartment_id="$COMPARTMENT_OCID" \
    -var compartment_name="$COMPARTMENT_NAME" -var region="$REGION" -var bucket_name="$BK" \
    -var config_file_profile="$OCI_CLI_PROFILE" -var public_key_path="$KEYS/operator_public.pem" \
    -var policy_mode="$1" >/dev/null) || { fail "iam-test apply mode=$1"; exit 1; }
  (cd "$LAB_DIR/iam-test" && terraform output -json statements | python3 -c 'import json,sys;[print(s) for s in json.load(sys.stdin)]')
}
code() { python3 -c 'import sys,re;t=sys.stdin.read();m=re.search(r"\"code\": \"([^\"]+)\"",t) or re.search(r"Error Code: (\w+)",t);print(m.group(1) if m else "error")'; }
res()  { if [[ $1 -eq 0 ]]; then echo "ok"; else echo "DENY:$(echo "$2" | code)"; fi; }

echo '{"probe":1}' > "$RESULTS/m.json"
table="| mode | read buckets | OVERWRITE | list | put new | put overwrite | get | delete | tf init | tf apply 1 | tf apply 2 |\n|---|---|---|---|---|---|---|---|---|---|---|"

for m in "${MODES[@]}"; do
  hdr "MODE $m"
  iam_apply "$m"
  oci os object put --bucket-name "$BK" --name matrix/fixed.json --file "$RESULTS/m.json" --force >/dev/null  # admin pre-creates
  echo "waiting ${WAIT}s for IAM propagation..."; sleep "$WAIT"

  ts=$(date +%s)
  o=$(op os object list --bucket-name "$BK" --prefix matrix/ 2>&1); r_list=$(res $? "$o")
  o=$(op os object put --bucket-name "$BK" --name "matrix/new-$ts.json" --file "$RESULTS/m.json" 2>&1); r_new=$(res $? "$o")
  o=$(op os object put --bucket-name "$BK" --name matrix/fixed.json --file "$RESULTS/m.json" --force 2>&1); r_ow=$(res $? "$o")
  [[ "$r_ow" != ok ]] && echo "$o" | grep -E '"code"|"message"|operation_name'
  o=$(op os object get --bucket-name "$BK" --name matrix/fixed.json --file /dev/null 2>&1); r_get=$(res $? "$o")
  o=$(op os object delete --bucket-name "$BK" --name "matrix/new-$ts.json" --force 2>&1); r_del=$(res $? "$o")

  key="matrix-$m/terraform.tfstate"
  probe_backend "$key" 'auth = "ApiKey"' "tenancy_ocid = \"$TENANCY_OCID\"" "user_ocid = \"$(tfv user_id)\"" \
    "fingerprint = \"$(tfv fingerprint)\"" "private_key_path = \"$KEYS/operator.pem\""
  r_a1="-"; r_a2="-"
  if o=$(probe_init 2>&1); then
    r_init=ok
    o=$(cd "$LAB_DIR/probe" && terraform apply -auto-approve -input=false -var revision=1 2>&1); r_a1=$(res $? "$o")
    [[ "$r_a1" != ok ]] && echo "$o" | grep -E 'Error:|Operation Name' | head -3
    o=$(cd "$LAB_DIR/probe" && terraform apply -auto-approve -input=false -var revision=2 2>&1); r_a2=$(res $? "$o")
    [[ "$r_a2" != ok ]] && { echo "--- tf apply 2 ($m)  <-- SCREENSHOT candidate"; echo "$o" | grep -E 'Error|Operation Name|Status Code' | head -6; }
  else
    r_init=$(res 1 "$o"); echo "$o" | grep -E 'Error:|Operation Name' | head -3
  fi
  oci os object delete --bucket-name "$BK" --name "$key.lock" --force >/dev/null 2>&1

  rb=$([[ "$m" == four || "$m" == five_norb ]] && echo no || echo yes)
  ow=$([[ "$m" == four* ]] && echo no || echo yes)
  row="| $m | $rb | $ow | $r_list | $r_new | $r_ow | $r_get | $r_del | $r_init | $r_a1 | $r_a2 |"
  echo "$row"; table="$table\n$row"
  note "matrix $row"
done

printf "\n%b\n" "$table" | tee "$RESULTS/51-matrix.md"

# ---------------------------------------------------------------------------
hdr "D (retry): outsider, polling until denied"
iam_apply five >/dev/null
sleep "$WAIT"
gid=$(oci iam group list --compartment-id "$TENANCY_OCID" --name tfstate-lab-operators --query 'data[0].id' --raw-output)
uid=$(tfv user_id)
op os object list --bucket-name "$BK" --prefix matrix/ >/dev/null 2>&1 && echo "precheck: member can list" || echo "precheck: member CANNOT list"
oci iam group remove-user --group-id "$gid" --user-id "$uid" --force >/dev/null
start=$(date +%s)
for i in $(seq 1 24); do
  sleep 30
  if ! o=$(op os object list --bucket-name "$BK" --prefix matrix/ 2>&1); then
    secs=$(( $(date +%s) - start ))
    echo "$o" | grep -E '"code"|"status"|"message"'
    pass "D outsider denied after ~${secs}s (membership removal propagation)"
    probe_backend "matrix-five/terraform.tfstate" 'auth = "ApiKey"' "tenancy_ocid = \"$TENANCY_OCID\"" "user_ocid = \"$uid\"" \
      "fingerprint = \"$(tfv fingerprint)\"" "private_key_path = \"$KEYS/operator.pem\""
    echo "--- outsider terraform init  <-- SCREENSHOT"
    probe_init 2>&1 | grep -E 'Error|Status Code|Message' | head -4
    exit 0
  fi
done
fail "D outsider still allowed after 12 min"
