#ifndef VOX_LOAD_STAGE_LOG_H
#define VOX_LOAD_STAGE_LOG_H
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

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
static inline void vox_thread_stage_begin_log(int pid, uint64_t id, uint64_t count,
    const char *label, size_t length) {
    fprintf(stderr, "Vox thread instruction stage begin: %d %llu %llu %.*s\n", pid,
        (unsigned long long)id, (unsigned long long)count, (int)length, label);
}
static inline void vox_thread_stage_end_log(int pid, uint64_t id, uint64_t count) {
    fprintf(stderr, "Vox thread instruction stage end: %d %llu %llu\n", pid,
        (unsigned long long)id, (unsigned long long)count);
}
static inline void vox_thread_stage_unavailable_log(int pid, uint64_t id, int error) {
    fprintf(stderr, "Vox thread instruction stage unavailable: %d %llu error=%d\n", pid,
        (unsigned long long)id, error);
}
#endif
