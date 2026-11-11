#!/usr/bin/env bash
# Post sections "How the backend uses Object Storage" + "The State Lock" + gotcha "Lock files pile up as versions".
# Holds a lock with a sleeping apply, then runs a second plan that must fail with LockInfo.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/40-lock-test.txt") 2>&1
BK="$BUCKET_NAME"; KEY="lock-test/terraform.tfstate"

probe_backend "$KEY" "${admin_auth[@]}"
probe_init >/dev/null || { fail "probe init"; exit 1; }
cd "$LAB_DIR/probe"
run terraform apply -auto-approve -input=false -var revision=0 >/dev/null

hdr "Terminal 1: apply holding the lock for 60s (background)"
terraform apply -auto-approve -input=false -var revision="hold-$(date +%s)" -var hold_seconds=60 \
  > "$RESULTS/40-holder.txt" 2>&1 &
holder=$!
seen=0
for _ in $(seq 1 20); do
  oci os object head --bucket-name "$BK" --name "$KEY.lock" >/dev/null 2>&1 && { seen=1; break; }; sleep 2
done
[[ $seen -eq 1 ]] || { fail "never saw $KEY.lock while holder ran (see results/40-holder.txt)"; wait "$holder"; exit 1; }

hdr "Terminal 2: terraform plan while locked  <-- SCREENSHOT"
run terraform plan -lock-timeout=0s -input=false; rc=$?
[[ $rc -ne 0 ]] && pass "second plan blocked by lock" || fail "second plan was NOT blocked"

hdr "Lock object visible  <-- SCREENSHOT"
run oci os object list --bucket-name "$BK" --prefix lock-test/ --query 'data[].name' --output table
run oci os object get --bucket-name "$BK" --name "$KEY.lock" --file - | python3 -m json.tool

hdr "Claim: lock object has no SSE header but bucket default CMK covers it"
run oci os object head --bucket-name "$BK" --name "$KEY.lock"

wait "$holder"
hdr "After apply: lock gone"
if oci os object head --bucket-name "$BK" --name "$KEY.lock" >/dev/null 2>&1; then
  fail ".lock still present after apply"
else
  pass ".lock removed after apply"
fi

hdr "Gotcha (inference): each run leaves noncurrent .lock versions"
for i in 1 2 3; do terraform apply -auto-approve -input=false -var revision="loop-$i" >/dev/null; done
run oci os object list-object-versions --bucket-name "$BK" --prefix lock-test/ --all \
  --query 'data[].{name:name,"delete-marker":"is-delete-marker",modified:"time-modified"}' --output table
n=$(oci os object list-object-versions --bucket-name "$BK" --prefix "$KEY.lock" --all --query 'length(data)' --raw-output)
[[ "${n:-0}" -gt 1 ]] && pass "lock versions accumulate ($n after 5 runs)" || note "lock versions: ${n:-0} (inference not confirmed)"

hdr "force-unlock with a wrong ID fails cleanly"
run terraform force-unlock -force 00000000-0000-0000-0000-000000000000; rc=$?
[[ $rc -ne 0 ]] && pass "force-unlock wrong ID rejected" || note "force-unlock wrong ID returned 0"
