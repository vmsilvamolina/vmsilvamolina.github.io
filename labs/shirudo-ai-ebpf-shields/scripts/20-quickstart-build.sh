#!/usr/bin/env bash
# Quickstart on the operator: test kernel artifact, build shirudo + shirudo-build, boot the target VM.
# Runs remotely under nohup; log in ~/qs-build.log on the VM.
source "$(dirname "$0")/lib.sh"
op 'cat > ~/qs-build.sh <<"EOS"
set -x
cd ~/shirudo
git log -1 --format="shirudo %h %ci"
ulimit -l; id; test -r /dev/kvm && test -w /dev/kvm && echo kvm ok
testing/vm/kernel-artifact.sh fetch
make -j"$(nproc)"
make shirudo-build
export PATH="$PWD:$PWD/tools/shirudo-build:$PATH"
./shirudo version
make -C testing vm VM_NAME=quickstart
echo QS_BUILD_EXIT=$?
EOS
nohup bash ~/qs-build.sh > ~/qs-build.log 2>&1 &
echo started'
