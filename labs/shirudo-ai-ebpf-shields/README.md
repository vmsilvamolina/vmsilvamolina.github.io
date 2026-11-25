# Lab: Shirudo hands-on with an AI-written eBPF shield

Backs [/shirudo-ebpf-shields-ai-agent/](../../_posts/2026/2026-11-24-shirudo-ebpf-shields-ai-agent.md). Run 2026-11-24 against shirudo `main` @ `6514073a`.

- Operator host: Azure `Standard_D8s_v5`, `eastus`, Ubuntu 26.04, Trusted Launch (nested virtualization works), 128 GiB Premium SSD, SSH only from my IP.
- Target: shirudo test VM (QEMU + swtpm) on the CI kernel `7.4-shirudo-ci-20261123`, Ubuntu 26.04.1.

## Run

```bash
cp lab.env.example lab.env          # region must be allowed by your subscription's policies
scripts/10-deploy.sh                # RG, NSG (ssh from your /32), VM with infra/cloud-init.yaml
# on the VM: sudo loginctl enable-linger azureuser   (else the target dies with your SSH session)
scripts/20-quickstart-build.sh      # kernel artifact, make, make shirudo-build, make -C testing vm (nohup)
scripts/30-quickstart.sh            # tamper check, sign/load/list, attest predict+verify (ok and fail), unload
scripts/40-baseline.sh              # vulnerable pingsvc + exploit.sh with no shield
scripts/50-shield.sh                # build/sign shield + unload directive, load, exploit, root tamper, unload
python3 scripts/ss_build.py         # ANSI transcripts -> freeze -> assets/images/postsImages/Shirudo_NN.png
scripts/90-teardown.sh              # az group delete
```

`~/bin/tgt` on the operator (created during the lab, see the post) runs a command on the target as root with `shirudo` mapped to `shirudo-runtime`.

## Results

| Check | Result |
|---|---|
| Nested KVM on D8s_v5 with Trusted Launch | `/dev/kvm` present, `vmx` flags, test VM boots |
| Target status | `Status: ok`, all 7 conditions OK |
| Root reads a shirudo pin / non-runtime binary | `Permission denied` |
| Sign + load + list basic upatch | OK, register extended |
| `attest verify` with predicted register | `verdict: ok`; wrong expectation -> `verdict: fail` |
| Signed unload | OK |
| Exploit without shield | `id`, `/etc/shadow`, `curl`, `bash`, file write all succeed as root |
| Shield v1 (`task->comm`) | Loads `success`, blocks nothing, counters 0/0: Python 3.14 names worker threads, child's `real_parent` is the thread |
| Shield v2 (`task->group_leader->comm`) | `id`, `head`, `curl`, `bash` -> `Operation not permitted`; ping OK; counters allowed=16 refused=8; host outside the service unaffected |
| Builtin write (`echo > /tmp/pwned`) | Still succeeds (no execve) — documented limit |
| Root `rm` pin / `bpftool link detach` | `Operation not permitted` / `Permission denied`, counted as `PinUnlink` / `BpfCommand` |
| Signed unload of shield | Exploit works again |

Gotchas: Azure Policy "Allowed locations" on the subscription (eastus2 denied, error hidden by az CLI traceback; use `--debug`); `--security-type Standard` needs feature registration (Trusted Launch works); `--nsg-rule NONE` fails; `pkill -f pingsvc.py` kills your own SSH session (use `pkill -x pingsvc`).

Screenshots are composed from verbatim lines in `results/`; stderr lines printed out of order by SSH are placed under their command.
