#!/usr/bin/env bash
# Shared helpers. Source from every script.
set -uo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$LAB_DIR/results"
mkdir -p "$RESULTS" "$LAB_DIR/keys"

[[ -f "$LAB_DIR/lab.env" ]] || { echo "Missing $LAB_DIR/lab.env (copy lab.env.example)"; exit 1; }
# shellcheck disable=SC1091
source "$LAB_DIR/lab.env"
export OCI_CLI_PROFILE

c_ok=$'\e[32m'; c_bad=$'\e[31m'; c_dim=$'\e[2m'; c_hdr=$'\e[1;36m'; c_off=$'\e[0m'

hdr()  { printf '\n%s== %s ==%s\n' "$c_hdr" "$*" "$c_off"; }
run()  { printf "%s$ %s%s\n" "$c_dim" "$*" "$c_off" >&2; "$@"; }
pass() { printf '%sPASS%s %s\n' "$c_ok" "$c_off" "$*"; echo "PASS | $*" >> "$RESULTS/summary.txt"; }
fail() { printf '%sFAIL%s %s\n' "$c_bad" "$c_off" "$*"; echo "FAIL | $*" >> "$RESULTS/summary.txt"; }
note() { printf 'NOTE %s\n' "$*"; echo "NOTE | $*" >> "$RESULTS/summary.txt"; }

set_env() { # set_env KEY VALUE -> persist into lab.env
  local k="$1" v="$2"
  if grep -q "^export $k=" "$LAB_DIR/lab.env"; then
    sed -i '' "s|^export $k=.*|export $k=$v|" "$LAB_DIR/lab.env"
  else
    echo "export $k=$v" >> "$LAB_DIR/lab.env"
  fi
  export "$k=$v"
}

# Write a backend.hcl for the probe stack. Args: key [extra hcl lines...]
probe_backend() {
  local key="$1"; shift
  {
    echo "bucket    = \"$BUCKET_NAME\""
    echo "namespace = \"$NAMESPACE\""
    echo "region    = \"$REGION\""
    echo "key       = \"$key\""
    for l in "$@"; do echo "$l"; done
  } > "$LAB_DIR/probe/backend.hcl"
}

admin_auth=( 'auth                = "ApiKey"' "config_file_profile = \"$OCI_CLI_PROFILE\"" )

# Fresh init of the probe stack (drops local .terraform so each test is isolated)
probe_init() {
  rm -rf "$LAB_DIR/probe/.terraform" "$LAB_DIR/probe/.terraform.lock.hcl"
  (cd "$LAB_DIR/probe" && terraform init -reconfigure -input=false -backend-config=backend.hcl "$@")
}
