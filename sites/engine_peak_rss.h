#ifndef VOX_HN_ENGINE_PEAK_RSS_H
#define VOX_HN_ENGINE_PEAK_RSS_H
#include <stdint.h>
#include <sys/resource.h>
/* Self excludes clang children. wait4 may fold a reaped child's peak into the
 * parent's final rusage; querying RUSAGE_SELF at the visit checkpoint avoids it. */
static uint64_t vox_hn_self_peak_rss_bytes(void) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0 || usage.ru_maxrss <= 0) return 0;
#if defined(__APPLE__)
    return (uint64_t)usage.ru_maxrss;
#else
    return (uint64_t)usage.ru_maxrss * 1024;
#endif
}
#endif
