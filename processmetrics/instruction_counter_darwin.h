#ifndef VOX_PROCESS_INSTRUCTION_COUNTER_H
#define VOX_PROCESS_INSTRUCTION_COUNTER_H
#include <errno.h>
#include <stdint.h>
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
#endif
