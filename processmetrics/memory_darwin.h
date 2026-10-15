#ifndef VOX_PROCESS_MEMORY_H
#define VOX_PROCESS_MEMORY_H

#include <libproc.h>
#include <stdint.h>
#include <sys/resource.h>
#include <unistd.h>

static int vox_process_memory_bytes(uint64_t *bytes)
{
    struct rusage_info_v0 usage = {0};
    int status = proc_pid_rusage(getpid(), RUSAGE_INFO_V0, (rusage_info_t *)&usage);
    if (status == 0)
        *bytes = usage.ri_phys_footprint;
    return status;
}

#endif
