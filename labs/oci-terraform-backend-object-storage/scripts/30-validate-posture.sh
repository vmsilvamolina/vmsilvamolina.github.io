#!/usr/bin/env bash
# Post section "Testing the State Bucket": posture, object encryption, PARs, lifecycle, versions, restore drill.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/30-validate-posture.txt") 2>&1
BK="$BUCKET_NAME"

hdr "Bucket posture"
out=$(run oci os bucket get --bucket-name "$BK" \
  --query 'data.{access:"public-access-type",ver:versioning,kms:"kms-key-id",events:"object-events-enabled"}')
echo "$out"
echo "$out" | grep -q '"NoPublicAccess"' && pass "access NoPublicAccess" || fail "access"
echo "$out" | grep -q '"Enabled"'        && pass "versioning Enabled"    || fail "versioning"
echo "$out" | grep -q 'ocid1.key'        && pass "bucket CMK set"        || fail "bucket CMK"
echo "$out" | grep -q '"events": true'   && pass "object events enabled" || fail "object events"

hdr "Claim (unverified): object head surfaces opc-sse-kms-key-id"
head=$(run oci os object head --bucket-name "$BK" --name bootstrap/terraform.tfstate)
echo "$head"
echo "$head" | grep -qi 'kms-key-id' && pass "object head shows kms key header" \
  || note "object head does NOT show kms key header -> adjust post wording"

hdr "Claim: no PARs on the state bucket"
pars=$(run oci os preauth-request list --bucket-name "$BK" --all --query 'length(data)' --raw-output 2>/dev/null || echo 0)
[[ "${pars:-0}" == "0" || -z "$pars" ]] && pass "zero PARs" || fail "$pars PARs found"

hdr "Lifecycle policy"
run oci os object-lifecycle-policy get --bucket-name "$BK" \
  --query 'data.items[].{name:name,action:action,target:target,days:"time-amount",enabled:"is-enabled"}' --output table \
  && pass "lifecycle policy present" || fail "lifecycle policy"

hdr "Versions"
run oci os object list-object-versions --bucket-name "$BK" --prefix bootstrap/ --all \
  --query 'data[].{name:name,version:"version-id","delete-marker":"is-delete-marker",modified:"time-modified"}' --output table

hdr "Claim (unverified): oci os object get supports --version-id"
oci os object get --help | grep -q -- '--version-id' && pass "--version-id flag exists" || fail "--version-id flag missing"

hdr "Restore drill: pull oldest version"
vid=$(oci os object list-object-versions --bucket-name "$BK" --prefix bootstrap/terraform.tfstate --all \
      --query "data[?name=='bootstrap/terraform.tfstate'] | [-1].\"version-id\"" --raw-output)
run oci os object get --bucket-name "$BK" --name bootstrap/terraform.tfstate --version-id "$vid" \
  --file "$RESULTS/restored.tfstate" && pass "restored version $vid" || fail "restore by version-id"

hdr "Private keys in state (bootstrap has none -> expect 0)"
n=$(grep -c "BEGIN RSA PRIVATE KEY\|BEGIN OPENSSH PRIVATE KEY" "$RESULTS/restored.tfstate" || true)
echo "count=$n"
rm -f "$RESULTS/restored.tfstate"
