#ifndef VOX_LOAD_STAGE_LOG_H
#define VOX_LOAD_STAGE_LOG_H
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <time.h>

// Formatting must not allocate in the caller's V arena. A timer callback may
// repeatedly run inside one retained workspace before that workspace retires.
static inline void vox_load_stage_begin_log(int pid, uint64_t id, uint64_t count,
    const char *label, size_t length) {
    fprintf(stderr, "Vox instruction stage begin: %d %llu %llu %.*s\n", pid,
        (unsigned long long)id, (unsigned long long)count, (int)length, label);
}
static inline void vox_load_stage_end_log(int pid, uint64_t id, uint64_t count) {
    fprintf(stderr, "Vox instruction stage end: %d %llu %llu\n", pid,
        (unsigned long long)id, (unsigned long long)count);
}
static inline void vox_load_stage_unavailable_log(int pid, uint64_t id, int error) {
    fprintf(stderr, "Vox instruction stage unavailable: %d %llu error=%d\n", pid,
        (unsigned long long)id, error);
}
// Calling-thread CPU and monotonic wall nanoseconds at the same boundary, on a
// separate line so instruction-stage parsers keep their exact formats.
static inline void vox_thread_stage_time_log(int pid, uint64_t id, const char *edge) {
#if defined(__APPLE__)
    fprintf(stderr, "Vox thread stage time: %d %llu %s %llu %llu\n", pid, (unsigned long long)id, edge,
        (unsigned long long)clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID),
        (unsigned long long)clock_gettime_nsec_np(CLOCK_UPTIME_RAW));
#else
    (void)pid; (void)id; (void)edge;
#endif
}
static inline void vox_thread_stage_begin_log(int pid, uint64_t id, uint64_t count,
    const char *label, size_t length) {
    fprintf(stderr, "Vox thread instruction stage begin: %d %llu %llu %.*s\n", pid,
        (unsigned long long)id, (unsigned long long)count, (int)length, label);
    vox_thread_stage_time_log(pid, id, "begin");
}
static inline void vox_thread_stage_end_log(int pid, uint64_t id, uint64_t count) {
    vox_thread_stage_time_log(pid, id, "end");
    fprintf(stderr, "Vox thread instruction stage end: %d %llu %llu\n", pid,
        (unsigned long long)id, (unsigned long long)count);
}
static inline void vox_thread_stage_unavailable_log(int pid, uint64_t id, int error) {
    fprintf(stderr, "Vox thread instruction stage unavailable: %d %llu error=%d\n", pid,
        (unsigned long long)id, error);
}
#endif
