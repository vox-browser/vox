// DYLD interposer for the Boehm collector used by the browser: size-weighted
// sampling of GC_malloc/GC_malloc_atomic/GC_realloc with call stacks.
//
//   clang -dynamiclib -O2 tools/gc_allocation_sampler.c -o Build/gc_allocation_sampler.dylib \
//     -L"$LIBGC_DIR" -lgc -Wl,-rpath,"$LIBGC_DIR"
//
// Environment:
//   GC_ALLOC_SAMPLE_OUT       report path, written at exit (required)
//   GC_ALLOC_SAMPLE_INTERVAL  bytes between samples (default 32768)
//   GC_ALLOC_SAMPLE_TRIGGER   only sample while this file exists
//   GC_ALLOC_SAMPLE_TRACK_FREES=1  register a finalizer on each sampled block,
//                             so the report also says how much was reclaimed
//
// Each report line is `bytes samples freed_bytes frame...`, preceded by
// `# image BASE PATH` lines; tools/gc_allocation_report.py symbolizes it.
#include <execinfo.h>
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

void *GC_malloc(size_t);
void *GC_malloc_atomic(size_t);
void *GC_realloc(void *, size_t);
void GC_free(void *);
typedef void (*GC_finalization_proc)(void *, void *);
void GC_register_finalizer_no_order(void *, GC_finalization_proc, void *,
    GC_finalization_proc *, void **);

#define DEPTH 28
#define SLOTS 65536
#define COOKIES (1u << 22)

typedef struct {
    uint64_t hash, bytes, count;
    _Atomic uint64_t freed;
    int depth;
    void *frames[DEPTH];
} Site;

typedef struct { Site *site; uint64_t weight; } FreeCookie;

static Site *sites;
static FreeCookie *cookies;
static _Atomic uint64_t next_cookie, since_sample;
static pthread_mutex_t sites_lock = PTHREAD_MUTEX_INITIALIZER;
static uint64_t interval = 32768;
static const char *trigger_path;
static int track_frees, ready;
static __thread int in_hook;

static void on_free(void *object, void *data) {
    (void)object;
    FreeCookie *cookie = data;
    if (cookie && cookie->site) atomic_fetch_add(&cookie->site->freed, cookie->weight);
}

static void write_report(void) {
    const char *path = getenv("GC_ALLOC_SAMPLE_OUT");
    if (!path || !sites) return;
    FILE *file = fopen(path, "w");
    if (!file) return;
    for (uint32_t i = 0; i < _dyld_image_count(); i++)
        fprintf(file, "# image %p %s\n", (void *)_dyld_get_image_header(i), _dyld_get_image_name(i));
    for (int i = 0; i < SLOTS; i++) {
        Site *site = &sites[i];
        if (!site->count) continue;
        fprintf(file, "%llu %llu %llu", (unsigned long long)site->bytes,
            (unsigned long long)site->count, (unsigned long long)atomic_load(&site->freed));
        for (int frame = 0; frame < site->depth; frame++) fprintf(file, " %p", site->frames[frame]);
        fprintf(file, "\n");
    }
    fclose(file);
}

__attribute__((constructor)) static void initialize(void) {
    const char *value = getenv("GC_ALLOC_SAMPLE_INTERVAL");
    if (value) interval = strtoull(value, 0, 10);
    if (!interval) interval = 32768;
    trigger_path = getenv("GC_ALLOC_SAMPLE_TRIGGER");
    sites = calloc(SLOTS, sizeof(Site));
    if (getenv("GC_ALLOC_SAMPLE_TRACK_FREES")) {
        cookies = calloc(COOKIES, sizeof(FreeCookie));
        track_frees = cookies != NULL;
    }
    atexit(write_report);
    ready = sites != NULL;
}

// Returns the sampled site and its byte weight when this allocation crosses a
// sampling boundary.
static Site *sample(size_t size, uint64_t *weight) {
    if (!ready || in_hook) return NULL;
    uint64_t previous = atomic_fetch_add(&since_sample, size);
    uint64_t crossings = (previous + size) / interval - previous / interval;
    if (!crossings) return NULL;
    if (trigger_path) {
        struct stat info;
        if (stat(trigger_path, &info) != 0) return NULL;
    }
    in_hook = 1;
    void *frames[DEPTH + 2];
    int depth = backtrace(frames, DEPTH + 2) - 2;
    Site *found = NULL;
    if (depth > 0) {
        uint64_t hash = 1469598103934665603ULL;
        for (int i = 0; i < depth; i++) hash = (hash ^ (uint64_t)frames[i + 2]) * 1099511628211ULL;
        pthread_mutex_lock(&sites_lock);
        for (uint64_t probe = 0; probe < SLOTS; probe++) {
            Site *site = &sites[(hash + probe) % SLOTS];
            if (!site->count) {
                site->hash = hash;
                site->depth = depth;
                memcpy(site->frames, frames + 2, sizeof(void *) * (size_t)depth);
            }
            if (site->hash == hash) {
                site->bytes += interval * crossings;
                site->count++;
                found = site;
                break;
            }
        }
        pthread_mutex_unlock(&sites_lock);
    }
    in_hook = 0;
    *weight = interval * crossings;
    return found;
}

static void *track(void *object, Site *site, uint64_t weight) {
    if (!object || !site || !track_frees) return object;
    uint64_t index = atomic_fetch_add(&next_cookie, 1);
    if (index >= COOKIES) return object;
    cookies[index] = (FreeCookie){ site, weight };
    in_hook = 1;
    GC_register_finalizer_no_order(object, on_free, &cookies[index], NULL, NULL);
    in_hook = 0;
    return object;
}

// GC_realloc and GC_free release the old block explicitly; drop our finalizer
// first (crediting it as freed) so the collector never finalizes a freed block.
static void untrack(void *object) {
    if (!object || !track_frees) return;
    GC_finalization_proc previous = NULL;
    void *previous_data = NULL;
    in_hook = 1;
    GC_register_finalizer_no_order(object, NULL, NULL, &previous, &previous_data);
    if (previous && previous != on_free)
        GC_register_finalizer_no_order(object, previous, previous_data, NULL, NULL);
    in_hook = 0;
    if (previous == on_free) on_free(object, previous_data);
}

static void *sampled_malloc(size_t size) {
    uint64_t weight = 0;
    Site *site = sample(size, &weight);
    return track(GC_malloc(size), site, weight);
}

static void *sampled_malloc_atomic(size_t size) {
    uint64_t weight = 0;
    Site *site = sample(size, &weight);
    return track(GC_malloc_atomic(size), site, weight);
}

static void *sampled_realloc(void *object, size_t size) {
    uint64_t weight = 0;
    Site *site = sample(size, &weight);
    untrack(object);
    return track(GC_realloc(object, size), site, weight);
}

static void tracked_free(void *object) {
    untrack(object);
    GC_free(object);
}

#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *replacement, *original; } \
    interpose_##original __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)replacement, (const void *)original }
INTERPOSE(sampled_malloc, GC_malloc);
INTERPOSE(sampled_malloc_atomic, GC_malloc_atomic);
INTERPOSE(sampled_realloc, GC_realloc);
INTERPOSE(tracked_free, GC_free);
