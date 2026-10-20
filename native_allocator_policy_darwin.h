#ifndef VOX_NATIVE_ALLOCATOR_POLICY_DARWIN_H
#define VOX_NATIVE_ALLOCATOR_POLICY_DARWIN_H

#include <crt_externs.h>
#include <errno.h>
#include <libproc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// libmalloc reads this setting before application constructors run. Restart
// once before V's globals, document work or the GUI are initialized so native
// font/paint allocations use its space-efficient policy from the beginning.
// exec preserves the PID, arguments, inherited descriptors and bundle identity.
// The setting is inherited by helpers, so they need no additional restart.
__attribute__((constructor)) static void vox_initialize_native_allocator_policy(void)
{
    // An explicit caller setting, including "0", owns the allocator policy.
    if (getenv("MallocSpaceEfficient") != NULL) return;
    char executable[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if (proc_pidpath(getpid(), executable, sizeof executable) <= 0
        || executable[0] != '/' || *_NSGetArgv() == NULL) return;
    if (setenv("MallocSpaceEfficient", "1", 0) != 0) return;
    execv(executable, *_NSGetArgv());
    int failure = errno;
    unsetenv("MallocSpaceEfficient");
    fprintf(stderr, "Vox: cannot restart with the compact native allocator: %s\n",
        strerror(failure));
}

#endif
