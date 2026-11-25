// SPDX-License-Identifier: GPL-2.0 OR BSD-2-Clause
/*
 * pingsvc command-injection shield.
 *
 * pingsvc runs `ping -c1 -W1 <host>` through /bin/sh with an unsanitized
 * host, so a request can append any command. Until the service is fixed,
 * refuse every execve() in the service's process tree except the two the
 * feature needs: the shell (dash) and ping. Everything else, `id`, `curl`,
 * `bash`, `cat`, gets -EPERM before the new image is loaded.
 *
 * Scope: a task belongs to the service when its thread group leader, or
 * the leader of one of its first MAX_DEPTH ancestors, has comm "pingsvc"
 * (the service sets it with PR_SET_NAME). Other tasks are not affected.
 *
 * Limits: shell builtins (echo, printf, redirection) never call execve()
 * and still run. comm is not an identity: a process can name itself
 * pingsvc, which only restricts that process. Written for preemptible
 * kernels (the test target is PREEMPT).
 */

#include "vmlinux.h"
#include <bpf/bpf_core_read.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#define EPERM		1
#define MAX_DEPTH	8
#define NAME_LEN	16

char _license[] SEC("license") = "Dual BSD/GPL";

enum { STAT_ALLOWED, STAT_REFUSED, STAT_MAX };

struct {
	__uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
	__uint(max_entries, STAT_MAX);
	__type(key, __u32);
	__type(value, __u64);
} guard_stats SEC(".maps");

static __always_inline bool name_is(const char *name, const char *want, int len)
{
	for (int i = 0; i < len; i++)
		if (name[i] != want[i])
			return false;
	return true;
}

/*
 * Check the thread group leader at each level, not only the task: a child's
 * real_parent is the thread that forked it, and runtimes name their worker
 * threads (Python 3.14 names them "Thread-N (...)"), so the comm the service
 * set lives on its leader.
 */
static __always_inline bool in_service(struct task_struct *task)
{
	char comm[NAME_LEN];

	for (int depth = 0; depth < MAX_DEPTH && task; depth++) {
		BPF_CORE_READ_STR_INTO(&comm, task, group_leader, comm);
		if (name_is(comm, "pingsvc", sizeof("pingsvc")))
			return true;
		task = BPF_CORE_READ(task, real_parent);
	}
	return false;
}

/* The file being executed must be bin/dash or bin/ping (usr-merged /bin). */
static __always_inline bool exec_allowed(struct linux_binprm *bprm)
{
	struct dentry *dentry = BPF_CORE_READ(bprm, file, f_path.dentry);
	char name[NAME_LEN] = {}, dir[NAME_LEN] = {};

	bpf_probe_read_kernel_str(name, sizeof(name),
				  BPF_CORE_READ(dentry, d_name.name));
	bpf_probe_read_kernel_str(dir, sizeof(dir),
				  BPF_CORE_READ(dentry, d_parent, d_name.name));
	if (!name_is(dir, "bin", sizeof("bin")))
		return false;
	return name_is(name, "dash", sizeof("dash")) ||
	       name_is(name, "ping", sizeof("ping"));
}

static __always_inline void count(__u32 key)
{
	__u64 *value = bpf_map_lookup_elem(&guard_stats, &key);

	if (value)
		__sync_fetch_and_add(value, 1);
}

SEC("lsm/bprm_check_security")
int BPF_PROG(pingsvc_exec_guard, struct linux_binprm *bprm, int ret)
{
	if (ret)
		return ret;
	if (!in_service(bpf_get_current_task_btf()))
		return 0;
	if (exec_allowed(bprm)) {
		count(STAT_ALLOWED);
		return 0;
	}
	count(STAT_REFUSED);
	return -EPERM;
}
