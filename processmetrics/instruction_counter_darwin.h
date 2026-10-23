#ifndef VOX_PROCESS_INSTRUCTION_COUNTER_H
#define VOX_PROCESS_INSTRUCTION_COUNTER_H
#include <dlfcn.h>
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <libproc.h>
#include <sys/resource.h>
#include <unistd.h>

static int vox_process_instructions(uint64_t *instructions)
{
    struct rusage_info_v4 usage = {0};
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V4, (rusage_info_t *)&usage) != 0)
        return errno;
    if (usage.ri_instructions == 0)
        return ENOTSUP;
    *instructions = usage.ri_instructions;
    return 0;
}

/* Optional private XNU ABI, matching tools/coalition_instruction_counts.py.
 * Request only the prefix through cycles; the kernel copies the smaller of its
 * full record and this buffer. Inherited coalition membership is not exclusive
 * browser ownership and must be checked independently by the benchmark. */
struct vox_coalition_resource_usage_prefix {
    uint64_t tasks_started;
    uint64_t tasks_exited;
    uint64_t before_qos[21];
    uint64_t cpu_time_eqos_len;
    uint64_t cpu_time_eqos[7];
    uint64_t cpu_instructions;
    uint64_t cpu_cycles;
};

_Static_assert(sizeof(struct vox_coalition_resource_usage_prefix) == 264,
    "Unexpected coalition resource prefix size");
_Static_assert(offsetof(struct vox_coalition_resource_usage_prefix, cpu_time_eqos_len) == 184,
    "Unexpected coalition QoS length offset");
_Static_assert(offsetof(struct vox_coalition_resource_usage_prefix, cpu_instructions) == 248,
    "Unexpected coalition instruction offset");
_Static_assert(offsetof(struct vox_coalition_resource_usage_prefix, cpu_cycles) == 256,
    "Unexpected coalition cycle offset");

typedef int (*vox_coalition_resource_usage_fn)(uint64_t, void *, size_t);

/* Fail closed on absent symbols, short PID records, unsupported resource layouts,
 * and invalid counters. Outputs remain zero on failure; all publish together. */
static int vox_coalition_instructions(uint64_t *coalition_id, uint64_t *instructions,
    uint64_t *tasks_started, uint64_t *tasks_exited)
{
    if (!coalition_id || !instructions || !tasks_started || !tasks_exited)
        return EINVAL;
    *coalition_id = *instructions = *tasks_started = *tasks_exited = 0;
    uint64_t ids[5] = {0}; /* two coalition IDs and three reserved words */
    errno = 0;
    int count = proc_pidinfo(getpid(), 20 /* PROC_PIDCOALITIONINFO */, 0, ids, sizeof(ids));
    if (count <= 0)
        return errno ? errno : EIO;
    if (count != sizeof(ids) || ids[0] == 0)
        return ENOTSUP;
    vox_coalition_resource_usage_fn usage_fn = (vox_coalition_resource_usage_fn)
        dlsym(RTLD_DEFAULT, "coalition_info_resource_usage");
    if (!usage_fn)
        return ENOTSUP;
    struct vox_coalition_resource_usage_prefix usage = {0};
    errno = 0;
    if (usage_fn(ids[0], &usage, sizeof(usage)) != 0)
        return errno ? errno : EIO;
    if (usage.cpu_time_eqos_len != 7 || usage.cpu_instructions == 0)
        return ENOTSUP;
    if (usage.tasks_exited > usage.tasks_started)
        return EIO;
    *coalition_id = ids[0];
    *instructions = usage.cpu_instructions;
    *tasks_started = usage.tasks_started;
    *tasks_exited = usage.tasks_exited;
    return 0;
}

static void vox_coalition_json_label(const char *label)
{
    fputc('"', stderr);
    for (const unsigned char *p = (const unsigned char *)(label ? label : ""); *p; ++p) {
        if (*p == '"' || *p == '\\') {
            fputc('\\', stderr);
            fputc(*p, stderr);
        } else if (*p < 0x20) {
            fprintf(stderr, "\\u%04x", (unsigned)*p);
        } else {
            fputc(*p, stderr);
        }
    }
    fputc('"', stderr);
}

/* Native capture uses this after successfully encoding the document PNG.
 * V navigation code instead reports its saved reading, without resampling. */
static inline void vox_coalition_instruction_checkpoint(const char *label)
{
    const char *enabled = getenv("VOX_PROFILE_INSTRUCTIONS");
    if (!enabled || !*enabled)
        return;
    uint64_t coalition_id = 0, instructions = 0, tasks_started = 0, tasks_exited = 0;
    int status = vox_coalition_instructions(&coalition_id, &instructions,
        &tasks_started, &tasks_exited);
    flockfile(stderr);
    if (status != 0) {
        fprintf(stderr, "Vox coalition instructions unavailable: %s error=%d\n",
            label ? label : "", status);
    } else {
        fputs("Vox coalition instructions: {\"label\":", stderr);
        vox_coalition_json_label(label);
        fprintf(stderr, ",\"coalition_id\":%" PRIu64 ",\"instructions\":%" PRIu64
            ",\"tasks_started\":%" PRIu64 ",\"tasks_exited\":%" PRIu64 "}\n",
            coalition_id, instructions, tasks_started, tasks_exited);
    }
    funlockfile(stderr);
}
#endif
