#!/usr/bin/env bash
# Versions, namespace, compartment, and the logging service-name check the post flags as unverified.
source "$(dirname "$0")/lib.sh"
: > "$RESULTS/summary.txt"
exec > >(tee "$RESULTS/00-preflight.txt") 2>&1

hdr "Versions"
run terraform version
run oci --version
tfv=$(terraform version -json | python3 -c 'import json,sys;print(json.load(sys.stdin)["terraform_version"])')
python3 - "$tfv" <<'PY' && pass "terraform $tfv >= 1.12.0" || fail "terraform $tfv < 1.12.0"
import sys; v=tuple(int(x) for x in sys.argv[1].split('-')[0].split('.')); sys.exit(0 if v>=(1,12,0) else 1)
PY

hdr "Namespace (must NOT be the tenancy name)"
ns=$(oci os ns get --query data --raw-output) || { fail "oci os ns get"; exit 1; }
tname=$(oci iam tenancy get --tenancy-id "$TENANCY_OCID" --query 'data.name' --raw-output)
echo "namespace=$ns tenancy_name=$tname"
[[ "$ns" != "$tname" ]] && pass "namespace differs from tenancy name" || note "namespace equals tenancy name (old tenancy)"
set_env NAMESPACE "$ns"

hdr "Compartment $COMPARTMENT_NAME"
cid=$(oci iam compartment list --compartment-id "$TENANCY_OCID" --name "$COMPARTMENT_NAME" \
      --lifecycle-state ACTIVE --query 'data[0].id' --raw-output 2>/dev/null)
if [[ -z "$cid" || "$cid" == "None" ]]; then
  cid=$(run oci iam compartment create --compartment-id "$TENANCY_OCID" --name "$COMPARTMENT_NAME" \
        --description "Terraform state lab" --wait-for-state ACTIVE --query 'data.id' --raw-output)
  echo "created $cid"; sleep 20
fi
set_env COMPARTMENT_OCID "$cid"
pass "compartment $COMPARTMENT_NAME = $cid"

hdr "Existing vaults in compartment (Always Free allows a limited number of DEFAULT vaults)"
run oci kms management vault list --compartment-id "$cid" --all \
  --query 'data[].{name:"display-name",state:"lifecycle-state",type:"vault-type"}' --output table

hdr "Claim: objectstorage service log uses service=objectstorage, categories read/write"
oci logging service list --all > "$RESULTS/logging-services.json"
python3 - "$RESULTS/logging-services.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); d=d.get("data",d)
for s in d:
    if "objectstorage" in json.dumps(s).lower():
        print("service id:", s.get("id"), "| resource types:", [r.get("name") for r in s.get("resource-types",[])])
        for r in s.get("resource-types",[]):
            print("  categories:", [c.get("name") for c in r.get("categories",[])])
PY
echo
echo "Compare the output above with bootstrap/main.tf (service=objectstorage, category=read|write)."
