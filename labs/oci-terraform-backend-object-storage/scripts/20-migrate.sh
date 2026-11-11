#!/usr/bin/env bash
# Add backend "oci" to bootstrap and migrate local state into the bucket it created.
# AUTH=SecurityToken ./20-migrate.sh  -> uses `oci session authenticate --profile-name tfstate` like the post.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/20-migrate.txt") 2>&1
cd "$LAB_DIR/bootstrap"
AUTH="${AUTH:-ApiKey}"

if [[ "$AUTH" == "SecurityToken" ]]; then
  hdr "oci session authenticate"
  run oci session authenticate --region "$REGION" --profile-name tfstate
  profile=tfstate
else
  profile="$OCI_CLI_PROFILE"
fi

cat > backend.tf <<HCL
terraform {
  backend "oci" {
    bucket              = "$BUCKET_NAME"
    namespace           = "$NAMESPACE"
    region              = "$REGION"
    key                 = "bootstrap/terraform.tfstate"
    auth                = "$AUTH"
    config_file_profile = "$profile"
  }
}
HCL
run cat backend.tf

hdr "terraform init -migrate-state"
run terraform init -migrate-state -force-copy -input=false && pass "migrate-state ($AUTH)" || { fail "migrate-state ($AUTH)"; exit 1; }

hdr "terraform plan (expect no changes)"
run terraform plan -detailed-exitcode -input=false; rc=$?
[[ $rc -eq 0 ]] && pass "plan after migration: no changes" || fail "plan after migration exit=$rc"

hdr "Remote object"
run oci os object list --bucket-name "$BUCKET_NAME" --prefix bootstrap/ --query 'data[].{name:name,size:size}' --output table

hdr "Remove local plaintext copies"
run rm -f terraform.tfstate terraform.tfstate.backup
ls terraform.tfstate* 2>/dev/null && fail "local state still present" || pass "no local terraform.tfstate left"
