#!/usr/bin/env bash
# Apply the bootstrap stack with LOCAL state (post: "Bootstrapping the Object Storage State Bucket").
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/10-deploy.txt") 2>&1
cd "$LAB_DIR/bootstrap"

cat > terraform.tfvars <<TFV
tenancy_ocid        = "$TENANCY_OCID"
compartment_id      = "$COMPARTMENT_OCID"
region              = "$REGION"
bucket_name         = "$BUCKET_NAME"
config_file_profile = "$OCI_CLI_PROFILE"
TFV

hdr "terraform init / apply (local state)"
run terraform init -input=false
start=$(date +%s)
if run terraform apply -auto-approve -input=false; then
  pass "bootstrap apply in $(( $(date +%s) - start ))s"
else
  fail "bootstrap apply (if KMS authorization error: re-run once, post says propagation lag)"
  exit 1
fi
run terraform output
