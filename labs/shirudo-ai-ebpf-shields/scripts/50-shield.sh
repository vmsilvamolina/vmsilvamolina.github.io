#!/usr/bin/env bash
# Build/sign the shield, load it on the target, re-run legit + exploit traffic, try to remove it as root,
# read its counters, unload it with the signed directive, and confirm the exploit works again.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/50-shield.txt") 2>&1
op "cat > ~/shirudo/lab/pingsvc-exec-guard.bpf.c" < "$LAB_DIR/shield/pingsvc-exec-guard.bpf.c"
op 'bash -s' <<'EOS'
set -u
cd ~/shirudo; export PATH="$PWD:$PWD/tools/shirudo-build:$PATH"
KEYS=/tmp/shirudo-test-vm-private-$(id -u)/operator-keys/keys
O() { printf '\n\e[1;32moperator$\e[0m %s\n' "$*"; eval "$@"; }
T() { printf '\n\e[1;33mtarget#\e[0m %s\n' "$*"; ~/bin/tgt "cd /workspace/shirudo; $*" </dev/null; }
O 'shirudo build lab/pingsvc-exec-guard.bpf.c --keys-dir "$KEYS" --vmlinux vendor/linux/vmlinux.h -o lab/pingsvc-exec-guard.upatch'
PAYLOAD=$(shirudo upatch info --json lab/pingsvc-exec-guard.upatch | jq -r .payload_sha256)
O 'shirudo build --unload pingsvc-exec-guard --payload-sha256 "$PAYLOAD" --keys-dir "$KEYS" -o lab/pingsvc-exec-guard.unload.upatch'
T 'shirudo upatch load lab/pingsvc-exec-guard.upatch'
T 'shirudo status | sed -n "/Loaded upatches/,/^$/p"'
T 'bash lab/exploit.sh'
T 'id; curl -s -o /dev/null -w "curl outside the service: %{http_code}\n" http://127.0.0.1:8080/?host=127.0.0.1; bash -c "echo bash outside the service works"'
T 'shirudo upatch map pingsvc-exec-guard guard_stats | grep -E "^(Name|Map|Type)|sum="'
T 'ls /run/shirudo/bpffs/upatches/pingsvc-exec-guard/'
T 'rm -f /run/shirudo/bpffs/upatches/pingsvc-exec-guard/link'
T 'id=$(bpftool link list | awk -F: "/lsm/{print \$1}" | tail -1); bpftool link list | grep -A1 "^$id:"; bpftool link detach id $id'
T 'curl -s --get --data-urlencode "host=127.0.0.1; id" http://127.0.0.1:8080/ | tail -2'
T 'shirudo status | sed -n "/^Tamper attempts/,/^$/p"'
T 'shirudo upatch unload lab/pingsvc-exec-guard.unload.upatch'
T 'curl -s --get --data-urlencode "host=127.0.0.1; id" http://127.0.0.1:8080/ | tail -1'
EOS
