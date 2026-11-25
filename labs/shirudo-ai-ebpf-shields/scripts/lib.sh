#!/usr/bin/env bash
set -uo pipefail
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$LAB_DIR/results"; mkdir -p "$RESULTS"
source "$LAB_DIR/lab.env"
SSH_KEY="${SSH_KEY/#\~/$HOME}"
c_hdr=$'\e[1;36m'; c_off=$'\e[0m'
hdr() { printf '\n%s== %s ==%s\n' "$c_hdr" "$*" "$c_off"; }
vm_ip() { az vm show -d -g "$AZ_RG" -n "$AZ_VM" --query publicIps -o tsv; }
op() { ssh -q -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$LAB_DIR/.known_hosts" -o ServerAliveInterval=30 -i "$SSH_KEY" "azureuser@${OP_IP:-$(vm_ip)}" "$@"; }
