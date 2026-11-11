#!/usr/bin/env bash
# Validates the proposed fix for the post's prefix-scoped CI policy (policy_mode=prefix_split):
#   stmt 1: OBJECT_INSPECT on the bucket (no object condition) -> ListObjects / workspace listing works
#   stmt 2: READ/CREATE/OVERWRITE/DELETE only where target.object.name = /network\/*/
# Also checks the workspace_key_prefix trap: default "tf-state-env" puts workspaces outside network/.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/52-ci-prefix-fix.txt") 2>&1
WAIT="${POLICY_WAIT:-120}"
export SUPPRESS_LABEL_WARNING=True
KEYS="$LAB_DIR/keys"; BK="$BUCKET_NAME"
[[ -f "$KEYS/operator.pem" ]] || { echo "run 50-iam-tests.sh first (creates operator key)"; exit 1; }

tfv() { (cd "$LAB_DIR/iam-test" && terraform output -raw "$1"); }
op()  { oci --config-file "$KEYS/oci_config" --profile OP "$@"; }
op_backend() { # key [workspace_key_prefix]
  local extra=( 'auth = "ApiKey"' "tenancy_ocid = \"$TENANCY_OCID\"" "user_ocid = \"$(tfv user_id)\""
                "fingerprint = \"$(tfv fingerprint)\"" "private_key_path = \"$KEYS/operator.pem\"" )
  [[ -n "${2:-}" ]] && extra+=( "workspace_key_prefix = \"$2\"" )
  probe_backend "$1" "${extra[@]}"
}
tfp() { (cd "$LAB_DIR/probe" && terraform "$@" 2>&1); }
check() { # expect(ok|deny) label rc output
  local exp="$1" label="$2" rc="$3" out="$4"
  if [[ "$exp" == ok && $rc -eq 0 ]] || [[ "$exp" == deny && $rc -ne 0 ]]; then pass "$label"
  else fail "$label (rc=$rc)"; echo "$out" | grep -E 'Error|Operation Name|"code"|"message"' | head -4; fi
}

hdr "Apply prefix_split policy"
(cd "$LAB_DIR/iam-test" && terraform apply -auto-approve -input=false \
  -var tenancy_ocid="$TENANCY_OCID" -var compartment_id="$COMPARTMENT_OCID" \
  -var compartment_name="$COMPARTMENT_NAME" -var region="$REGION" -var bucket_name="$BK" \
  -var config_file_profile="$OCI_CLI_PROFILE" -var public_key_path="$KEYS/operator_public.pem" \
  -var policy_mode=prefix_split >/dev/null) || { fail "iam-test apply prefix_split"; exit 1; }
(cd "$LAB_DIR/iam-test" && terraform output -json statements | python3 -c 'import json,sys;[print(s) for s in json.load(sys.stdin)]')

echo '{"probe":1}' > "$RESULTS/m.json"
oci os object put --bucket-name "$BK" --name apps/secret.tfstate --file "$RESULTS/m.json" --force >/dev/null
echo "waiting ${WAIT}s for IAM propagation (also re-adds group membership removed by D)..."; sleep "$WAIT"

hdr "CLI: object ops"
o=$(op os object list --bucket-name "$BK" --prefix network/ 2>&1);      check ok   "list network/" $? "$o"
o=$(op os object list --bucket-name "$BK" --prefix apps/ 2>&1);         check ok   "list apps/ (names visible bucket-wide: expected trade-off)" $? "$o"
o=$(op os object put --bucket-name "$BK" --name network/x.json --file "$RESULTS/m.json" --force 2>&1); check ok "put network/" $? "$o"
o=$(op os object put --bucket-name "$BK" --name network/x.json --file "$RESULTS/m.json" --force 2>&1); check ok "overwrite network/" $? "$o"
o=$(op os object get --bucket-name "$BK" --name network/x.json --file /dev/null 2>&1);                 check ok "get network/" $? "$o"
o=$(op os object get --bucket-name "$BK" --name apps/secret.tfstate --file /dev/null 2>&1);            check deny "get apps/ (other stack's state)" $? "$o"
o=$(op os object put --bucket-name "$BK" --name apps/x.json --file "$RESULTS/m.json" --force 2>&1);    check deny "put apps/" $? "$o"
o=$(op os object delete --bucket-name "$BK" --name apps/secret.tfstate --force 2>&1);                 check deny "delete apps/" $? "$o"
o=$(op os object delete --bucket-name "$BK" --name network/x.json --force 2>&1);                      check ok "delete network/" $? "$o"

hdr "Terraform: network/terraform.tfstate with workspace_key_prefix=network/env  <-- SCREENSHOT"
op_backend "network/terraform.tfstate" "network/env"
o=$(probe_init 2>&1); check ok "init" $? "$o"
o=$(tfp apply -auto-approve -input=false -var revision="s1-$(date +%s)"); check ok "apply 1" $? "$o"
o=$(tfp apply -auto-approve -input=false -var revision="s2-$(date +%s)"); check ok "apply 2 (overwrite)" $? "$o"
echo "$o" | tail -3
o=$(tfp workspace new dev); check ok "workspace new dev (network/env/dev/...)" $? "$o"
o=$(tfp apply -auto-approve -input=false -var revision="dev1"); check ok "apply in workspace dev" $? "$o"
o=$(tfp workspace list); check ok "workspace list" $? "$o"; echo "$o"
tfp workspace select default >/dev/null

hdr "Terraform: default workspace_key_prefix (tf-state-env) -> workspaces land outside network/"
op_backend "network/terraform.tfstate"
probe_init >/dev/null 2>&1
o=$(tfp workspace new staging); rc=$?
o2=$(tfp apply -auto-approve -input=false -var revision=stg1); rc2=$?
[[ $rc -ne 0 || $rc2 -ne 0 ]] && pass "default prefix: non-default workspace denied (needs workspace_key_prefix under network/)" \
                              || fail "default prefix: workspace outside network/ was allowed"
echo "$o2" | grep -E 'Error|Operation Name' | head -3
tfp workspace select default >/dev/null 2>&1

hdr "Terraform: apps/terraform.tfstate -> denied"
op_backend "apps/terraform.tfstate"
probe_init >/dev/null 2>&1
o=$(tfp apply -auto-approve -input=false -var revision=1); check deny "apply on apps/" $? "$o"

hdr "terraform_remote_state of apps/ from a network/ runner -> denied"
o=$(op os object get --bucket-name "$BK" --name apps/secret.tfstate --file - 2>&1); check deny "read other stack state" $? "$o"

# cleanup lab objects (admin)
for n in apps/secret.tfstate; do oci os object delete --bucket-name "$BK" --name "$n" --force >/dev/null 2>&1; done
