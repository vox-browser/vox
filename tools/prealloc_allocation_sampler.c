// Allocation-site sampler for -prealloc builds. A V runtime with the
// allocator hook calls v_prealloc_base_alloc_hook() for every allocation from
// a thread's base arena (memory that is never reset) when the program is built
// with `-d prealloc_alloc_hook`. `VOX_PREALLOC_SAMPLER=1 LADYBIRD_V_GC=prealloc
// sh build-prod-browser.sh` compiles this file and links it into the browser.
//
// Environment:
//   VOX_PREALLOC_SAMPLE_OUT       report path, written at exit or on SIGTERM
//                                 (required)
//   VOX_PREALLOC_SAMPLE_INTERVAL  bytes between samples (default 16384)
//   VOX_PREALLOC_SAMPLE_TRIGGER   only sample while this file exists
//
// The report uses the tools/gc_allocation_sampler.c format (`bytes samples 0
// frame...` after `# image BASE PATH` lines); summarize it with
// tools/gc_allocation_report.py.
#include <execinfo.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>

#define VOX_SAMPLE_DEPTH 28
#define VOX_SAMPLE_SLOTS 65536

typedef struct {
    uint64_t hash, bytes, count;
    int depth;
    void *frames[VOX_SAMPLE_DEPTH];
} VoxSampleSite;

static VoxSampleSite *vox_sample_sites;
static _Atomic uint64_t vox_sample_since;
static pthread_mutex_t vox_sample_lock = PTHREAD_MUTEX_INITIALIZER;
static uint64_t vox_sample_interval = 16384;
static const char *vox_sample_trigger;
static int vox_sample_state; // 0 uninitialized, 1 ready, 2 disabled
static __thread int vox_sample_busy;

// Writes with open/write and a stack buffer so that the SIGTERM handler can use
// it: a terminated browser never reaches atexit.
static void vox_sample_print(int fd, const char *format, ...) __attribute__((format(printf, 2, 3)));
static void vox_sample_print(int fd, const char *format, ...) {
    char line[1024];
    va_list arguments;
    va_start(arguments, format);
    int length = vsnprintf(line, sizeof(line), format, arguments);
    va_end(arguments);
    if (length > 0) write(fd, line, length < (int)sizeof(line) ? (size_t)length : sizeof(line) - 1);
}

static void vox_sample_write_report(void) {
    const char *path = getenv("VOX_PREALLOC_SAMPLE_OUT");
    if (!path || !vox_sample_sites) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return;
    for (uint32_t i = 0; i < _dyld_image_count(); i++)
        vox_sample_print(fd, "# image %p %s\n", (void *)_dyld_get_image_header(i), _dyld_get_image_name(i));
    for (int i = 0; i < VOX_SAMPLE_SLOTS; i++) {
        VoxSampleSite *site = &vox_sample_sites[i];
        if (!site->count) continue;
        vox_sample_print(fd, "%llu %llu 0", (unsigned long long)site->bytes, (unsigned long long)site->count);
        for (int frame = 0; frame < site->depth; frame++) vox_sample_print(fd, " %p", site->frames[frame]);
        vox_sample_print(fd, "\n");
    }
    close(fd);
}

static void vox_sample_terminated(int signal_number) {
    (void)signal_number;
    vox_sample_write_report();
    _exit(143);
}

static int vox_sample_ready(void) {
    if (vox_sample_state == 0) {
        pthread_mutex_lock(&vox_sample_lock);
        if (vox_sample_state == 0) {
            const char *value = getenv("VOX_PREALLOC_SAMPLE_INTERVAL");
            if (value && strtoull(value, 0, 10)) vox_sample_interval = strtoull(value, 0, 10);
            vox_sample_trigger = getenv("VOX_PREALLOC_SAMPLE_TRIGGER");
            if (getenv("VOX_PREALLOC_SAMPLE_OUT")) {
                vox_sample_sites = calloc(VOX_SAMPLE_SLOTS, sizeof(VoxSampleSite));
            }
            if (vox_sample_sites) {
                atexit(vox_sample_write_report);
                signal(SIGTERM, vox_sample_terminated);
            }
            vox_sample_state = vox_sample_sites ? 1 : 2;
        }
        pthread_mutex_unlock(&vox_sample_lock);
    }
    return vox_sample_state == 1;
}

void v_prealloc_base_alloc_hook(void *pointer, intptr_t size) {
    (void)pointer;
    if (vox_sample_busy || size <= 0 || !vox_sample_ready()) return;
    uint64_t previous = atomic_fetch_add(&vox_sample_since, (uint64_t)size);
    uint64_t crossings = (previous + (uint64_t)size) / vox_sample_interval - previous / vox_sample_interval;
    if (!crossings) return;
    if (vox_sample_trigger) {
        struct stat info;
        if (stat(vox_sample_trigger, &info) != 0) return;
    }
    vox_sample_busy = 1;
    // frames[0] is this hook. The allocator's fast path is inlined into its
    // callers, so frames[1] can already be the allocating function.
    void *frames[VOX_SAMPLE_DEPTH + 1];
    int depth = backtrace(frames, VOX_SAMPLE_DEPTH + 1) - 1;
    if (depth > 0) {
        uint64_t hash = 1469598103934665603ULL;
        for (int i = 0; i < depth; i++) hash = (hash ^ (uint64_t)frames[i + 1]) * 1099511628211ULL;
        pthread_mutex_lock(&vox_sample_lock);
        for (uint64_t probe = 0; probe < VOX_SAMPLE_SLOTS; probe++) {
            VoxSampleSite *site = &vox_sample_sites[(hash + probe) % VOX_SAMPLE_SLOTS];
            if (!site->count) {
                site->hash = hash;
                site->depth = depth;
                memcpy(site->frames, frames + 1, sizeof(void *) * (size_t)depth);
            }
            if (site->hash == hash) {
                site->bytes += vox_sample_interval * crossings;
                site->count++;
                break;
            }
        }
        pthread_mutex_unlock(&vox_sample_lock);
    }
    vox_sample_busy = 0;
}
