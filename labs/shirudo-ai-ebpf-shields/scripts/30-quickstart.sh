#!/usr/bin/env bash
# Quickstart flow from Documentation/start/quickstart.rst on the Azure operator + test target.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/30-quickstart.txt") 2>&1
op 'bash -s' <<'EOS'
set -u
cd ~/shirudo; export PATH="$PWD:$PWD/tools/shirudo-build:$PATH"
KEYS=/tmp/shirudo-test-vm-private-$(id -u)/operator-keys/keys
O() { printf '\n\e[1;32moperator$\e[0m %s\n' "$*"; eval "$@"; }
T() { printf '\n\e[1;33mtarget#\e[0m %s\n' "$*"; ~/bin/tgt "cd /workspace/shirudo; $*" </dev/null; }
T 'cat /run/shirudo/bpffs/tamper'
T 'bpftool prog list 2>&1 | head -3 || true'
O 'shirudo build testing/fixtures/basic.bpf.c --keys-dir "$KEYS" --vmlinux vendor/linux/vmlinux.h -o basic.upatch'
O 'shirudo upatch info basic.upatch'
PAYLOAD=$(shirudo upatch info --json basic.upatch | jq -r .payload_sha256)
O 'shirudo build --unload basic --payload-sha256 "$PAYLOAD" --keys-dir "$KEYS" -o basic.unload.upatch'
T 'shirudo upatch load basic.upatch'
T 'shirudo upatch list'
T 'shirudo status | sed -n "/Loaded upatches/,/^$/p"'
NONCE=$(openssl rand -hex 32); echo "NONCE=$NONCE"
T "shirudo attest --nonce=$NONCE --output=/mnt/shirudo-out/ev.json"
EV=build/test-vm/vms/quickstart/result/ev.json
OWN=build/test-vm/host-bundle-bpf-next-verity/fixtures/own.der
O 'shirudo attest predict --cert="$KEYS/cert.der" --cert="$OWN" --event=load:basic="$PAYLOAD" | tee /tmp/pred.txt'
CHAIN=$(awk '/register_after_events/{print $2}' /tmp/pred.txt)
O 'shirudo attest verify --evidence="$EV" --nonce="$NONCE" --ak-name="$(jq -r .ak.name "$EV")" --expect-chain="$CHAIN"'
echo "VERIFY_EXIT=$?"
O 'shirudo attest verify --evidence="$EV" --nonce="$NONCE" --ak-name="$(jq -r .ak.name "$EV")" --expect-chain="$(printf %064d 0)" | tail -3'
T 'shirudo upatch unload basic.unload.upatch'
T 'shirudo upatch list'
EOS
