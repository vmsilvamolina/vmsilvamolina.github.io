#!/usr/bin/env bash
# Copy the vulnerable app into the shared checkout, start it on the target, run the exploit with NO shield.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/${OUT:-40-baseline}.txt") 2>&1
op 'mkdir -p ~/shirudo/lab'
for f in app/pingsvc.py app/exploit.sh; do op "cat > ~/shirudo/lab/$(basename $f)" < "$LAB_DIR/$f"; done
op 'chmod +x ~/shirudo/lab/*; ~/bin/tgt "pkill -x pingsvc; setsid nohup python3 /workspace/shirudo/lab/pingsvc.py >/dev/null 2>&1 < /dev/null & sleep 1; ps -o pid,comm,args -C pingsvc" </dev/null'
op '~/bin/tgt "bash /workspace/shirudo/lab/exploit.sh" </dev/null'
