#ifndef VOX_HN_ENGINE_CALLBACK_CPU_H
#define VOX_HN_ENGINE_CALLBACK_CPU_H
#include <stdint.h>
#include <time.h>
/* Optional diagnostic of the calling thread only. This excludes scheduling
 * waits and other threads; it is not a whole-engine CPU counter. */
static uint64_t vox_hn_thread_cpu_ns(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts) != 0) return UINT64_MAX;
    return (uint64_t)ts.tv_sec * UINT64_C(1000000000) + (uint64_t)ts.tv_nsec;
}
#endif
