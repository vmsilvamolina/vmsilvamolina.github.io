#!/usr/bin/env bash
# Destroy everything. Vault + key go to PENDING_DELETION (OCI minimum 7 days) and still count against limits.
# The compartment is kept (delete it manually once the vault is gone).
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/90-teardown.txt") 2>&1

hdr "iam-test destroy (user, group, api key, policy)"
(cd "$LAB_DIR/iam-test" && [[ -f terraform.tfstate ]] && terraform destroy -auto-approve -input=false \
  -var tenancy_ocid="$TENANCY_OCID" -var compartment_id="$COMPARTMENT_OCID" \
  -var compartment_name="$COMPARTMENT_NAME" -var region="$REGION" -var bucket_name="$BUCKET_NAME" \
  -var config_file_profile="$OCI_CLI_PROFILE" -var public_key_path="$LAB_DIR/keys/operator_public.pem")
rm -rf "$LAB_DIR/keys"

hdr "Bring bootstrap state back to local"
cd "$LAB_DIR/bootstrap"
if [[ -f backend.tf ]]; then
  terraform state pull > terraform.tfstate.remote || { fail "state pull"; exit 1; }
  rm -f backend.tf
  terraform init -migrate-state -force-copy -input=false >/dev/null
  [[ -s terraform.tfstate ]] || mv terraform.tfstate.remote terraform.tfstate
  rm -f terraform.tfstate.remote
fi

hdr "Empty bucket (all versions)"
oci os object list-object-versions --bucket-name "$BUCKET_NAME" --all \
  --query 'data[].[name,"version-id"]' --raw-output 2>/dev/null \
  | python3 -c 'import json,sys;[print(n+"\t"+v) for n,v in json.load(sys.stdin)]' 2>/dev/null \
  | while IFS=$'\t' read -r n v; do
      oci os object delete --bucket-name "$BUCKET_NAME" --name "$n" --version-id "$v" --force >/dev/null && echo "deleted $n@$v"
    done

hdr "terraform destroy bootstrap"
run terraform destroy -auto-approve -input=false && pass "bootstrap destroyed" || fail "bootstrap destroy"
rm -rf "$LAB_DIR/probe/.terraform" "$LAB_DIR/probe/backend.hcl" "$LAB_DIR/probe/errored.tfstate"

echo
echo "Vault/key are PENDING_DELETION. Compartment $COMPARTMENT_NAME kept: delete it after the vault is gone."
