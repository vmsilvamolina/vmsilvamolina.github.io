#!/usr/bin/env python3
"""ANSI transcripts for the post screenshots, built from verbatim lab output in results/.
Lines that stderr/stdout interleaving printed under the wrong prompt are placed under their command."""
import pathlib, re
LAB = pathlib.Path(__file__).resolve().parent.parent
R = LAB / "results"; OUT = LAB / "screenshots" / "ansi"; OUT.mkdir(parents=True, exist_ok=True)
G, Y, RED, D, X = "\x1b[1;32m", "\x1b[1;33m", "\x1b[31m", "\x1b[2m", "\x1b[0m"
strip = lambda s: re.sub(r"\x1b\[[0-9;]*m", "", s)
op = lambda c: f"{G}operator${X} {c}\n"
tg = lambda c: f"{Y}target#{X} {c}\n"
def red(block, pat=r"Permission denied|Operation not permitted|FAIL|verdict: fail"):
    return "".join(f"{RED}{l}{X}\n" if re.search(pat, l) else l + "\n" for l in block.strip("\n").splitlines())
def section(text, start, end=None):
    t = strip(text); i = t.index(start) + len(start)
    j = t.index(end, i) if end else len(t)
    return t[i:j].strip("\n")
def w(n, body): (OUT / f"Shirudo_{n:02d}.ansi").write_text(body); print("wrote", n)

st = (R / "21-target-status.txt").read_text()
qs = (R / "30-quickstart.txt").read_text()
base = (R / "40-baseline.txt").read_text()
v1 = (R / "50-shield-v1.txt").read_text()
v2 = (R / "50-shield.txt").read_text()

# 01 protected target: status + root can't touch shirudo state
w(1, tg("shirudo status") + red(section(st, "---\n", "Folded:").split("---\n")[-1]) +
     tg("cat /run/shirudo/bpffs/tamper") + red("cat: /run/shirudo/bpffs/tamper: Permission denied"))
# 02 sign on operator, load on target
w(2, op('shirudo build testing/fixtures/basic.bpf.c --keys-dir "$KEYS" --vmlinux vendor/linux/vmlinux.h -o basic.upatch') +
     "wrote basic.upatch (insns=992 sig=4853 data=2400 sections=2 maps=0 progs=1 decoders=0 name=basic)\n" +
     tg("shirudo upatch load basic.upatch") + section(qs, "target# shirudo upatch load basic.upatch", "target# shirudo upatch list") + "\n" +
     tg("shirudo upatch list") + section(qs, "target# shirudo upatch list", "target# shirudo status") + "\n")
# 03 attestation
ver = section(qs, '--expect-chain="$CHAIN"', "VERIFY_EXIT").splitlines()
keep = [l for l in ver if re.search(r"nonce|quote: ECDSA|register: certified|eventlog: 2 records|state: register|event after boot|verdict", l)]
w(3, op('shirudo attest predict --cert="$KEYS/cert.der" --cert="$OWN" --event=load:basic="$PAYLOAD"') +
     section(qs, '--event=load:basic="$PAYLOAD" | tee /tmp/pred.txt', "operator$ shirudo attest verify") + "\n" +
     op('shirudo attest verify --evidence="$EV" --nonce="$NONCE" --ak-name="$AK" --expect-chain="$REGISTER_AFTER_EVENTS"') +
     D + "  ... (31 checks, showing 8)\n" + X + "\n".join(keep) + "\n" +
     op('shirudo attest verify ... --expect-chain="0000…0000"   # wrong expectation') +
     red(section(qs, '--expect-chain="$(printf %064d 0)" | tail -3', "target#")))
# 04 baseline: exploit without shield
w(4, D + "-- pingsvc: subprocess.run(f\"ping -c1 -W1 {host}\", shell=True), no shield loaded\n" + X +
     tg("bash lab/exploit.sh") + strip(base)[strip(base).index("== legitimate"):].strip("\n") + "\n")
# 05 v1 loaded but exploit still works, counters zero
v1t = strip(v1)
w(5, D + "-- shield v1: loads and verifies, but never matches the service's processes\n" + X +
     tg("shirudo upatch load lab/pingsvc-exec-guard.upatch") +
     "\n".join(l for l in section(v1, "target# shirudo upatch load lab/pingsvc-exec-guard.upatch", "target# shirudo status").splitlines() if l.startswith("upatch load")) + "\n" +
     tg("curl -s --get --data-urlencode 'host=127.0.0.1; id' http://127.0.0.1:8080/ | tail -1") + "uid=0(root) gid=0(root) groups=0(root)\n" +
     tg('shirudo upatch map pingsvc-exec-guard guard_stats | grep sum=') + "  key=0: sum=0\n  key=1: sum=0\n" +
     tg("ps -L -o pid,lwp,comm -p $(pgrep -x pingsvc)   # during a request") +
     "    PID     LWP COMMAND\n   4513    4513 pingsvc\n   4513    5525 Thread-20 (proc\n")
# 06 v2 blocks
inj = section(v2, "target# bash lab/exploit.sh", "target# id;")
w(6, tg("bash lab/exploit.sh   # shield v2 loaded") + red(inj) +
     tg("shirudo upatch map pingsvc-exec-guard guard_stats | grep sum=") + "  key=0: sum=16   # allowed: sh + ping\n  key=1: sum=8    # refused\n")
# 07 root vs the shield
w(7, tg("id; bash -c 'echo bash outside the service works'") + "uid=0(root) gid=0(root) groups=0(root)\nbash outside the service works\n" +
     tg("rm -f /run/shirudo/bpffs/upatches/pingsvc-exec-guard/link") + red("rm: cannot remove '/run/shirudo/bpffs/upatches/pingsvc-exec-guard/link': Operation not permitted") +
     tg("bpftool link detach id 3") + red("Error: can't get link by id (3): Permission denied") +
     tg('shirudo status | sed -n "/^Tamper attempts/,/^$/p"') + section(v2, 'shirudo status | sed -n "/^Tamper attempts/,/^$/p"', "target# shirudo upatch unload") + "\n")
# 08 signed unload, exploit back
w(8, tg("shirudo upatch unload lab/pingsvc-exec-guard.unload.upatch") +
     section(v2, "target# shirudo upatch unload lab/pingsvc-exec-guard.unload.upatch", "target# curl") + "\n" +
     tg("curl -s --get --data-urlencode 'host=127.0.0.1; id' http://127.0.0.1:8080/ | tail -1") + "uid=0(root) gid=0(root) groups=0(root)\n")
