#!/usr/bin/env bash
# Post section "No PARs, and Someone Is Watching": are GETs on the state object logged, and does the query work?
# Run after 40/50 so there is traffic. Logs are best effort: may take several minutes to appear.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/60-access-logs.txt") 2>&1
cd "$LAB_DIR/bootstrap"

lg=$(terraform output -raw log_group_id); rl=$(terraform output -raw read_log_id)
start=$(date -u -v-3H +%Y-%m-%dT%H:%M:%SZ); end=$(date -u +%Y-%m-%dT%H:%M:%SZ)

hdr "Generate a read"
run oci os object get --bucket-name "$BUCKET_NAME" --name bootstrap/terraform.tfstate --file /dev/null

hdr "Query from the post (grammar unverified)  <-- SCREENSHOT (also run it in Console > Logging > Search)"
q="search \"$COMPARTMENT_OCID/$lg/$rl\" | where data.bucketName = '$BUCKET_NAME' and data.requestAction = 'GET' | select datetime, data.principalName, data.clientIpAddress, data.requestResourcePath, data.statusCode"
echo "$q"
out=$(oci logging-search search-logs --search-query "$q" --time-start "$start" --time-end "$end" 2>&1)
echo "$out" | head -60
if echo "$out" | grep -q '"summary"'; then
  cnt=$(echo "$out" | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["summary"]["result-count"])' 2>/dev/null)
  pass "post query parses (results=$cnt)"
else
  fail "post query rejected -> fix grammar in post"
fi

hdr "Fallback: raw query, inspect field names"
q2="search \"$COMPARTMENT_OCID/$lg/$rl\" | sort by datetime desc"
oci logging-search search-logs --search-query "$q2" --time-start "$start" --time-end "$end" --limit 3 \
  > "$RESULTS/60-raw-log.json" 2>&1
python3 - "$RESULTS/60-raw-log.json" <<'PY'
import json,sys
try:
    r=json.load(open(sys.argv[1]))["data"]["results"]
except Exception as e:
    print("no parseable results:", e); sys.exit()
print(f"{len(r)} raw events")
if r:
    d=r[0]["data"]["logContent"]["data"]
    print("fields:", sorted(d.keys()))
    for f in ["bucketName","principalName","clientIpAddress","requestAction","requestResourcePath","statusCode"]:
        print(f"  {f}: {'present' if f in d else 'MISSING'}")
PY
echo "If 0 events: wait 5-10 min and re-run (Oracle: best-effort delivery)."
