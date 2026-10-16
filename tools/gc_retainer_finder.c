// DYLD interposer for the Boehm collector used by the browser: remembers large
// allocations made under a named function and, once a trigger file appears,
// reports which reachable heap objects still point at the oldest one.
//
//   clang -dynamiclib -O2 tools/gc_retainer_finder.c -o Build/gc_retainer_finder.dylib \
//     -L"$LIBGC_DIR" -lgc -Wl,-rpath,"$LIBGC_DIR"
//
// Environment:
//   GC_RETAINERS_TRIGGER  search once, on the first allocation after this file exists
//   GC_RETAINERS_OUT      report path (default /tmp/gc-retainers.txt)
//   GC_RETAINERS_SITE     substring of a function on the allocating stack
//   GC_RETAINERS_MIN      minimum remembered size in bytes (default 900000)
//
// After a full collection, the search walks marked objects for words pointing
// into the target, then climbs through the first referrer. A level with no
// heap referrer means a root: static data such as a global map, a stack, or an
// uncollectable block.
#include <dlfcn.h>
#include <execinfo.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

void *GC_malloc(size_t);
void *GC_realloc(void *, size_t);
void GC_gcollect(void);
void *GC_base(void *);
size_t GC_size(const void *);
typedef void (*GC_reachable_object_proc)(void *, size_t, void *);
void GC_enumerate_reachable_objects_inner(GC_reachable_object_proc, void *);
typedef void *(*GC_fn_type)(void *);
void *GC_call_with_alloc_lock(GC_fn_type, void *);

#define RING 256
#define DEPTH 24
#define MAX_REFERRERS 64

typedef struct { void *object; size_t size; unsigned long sequence; int depth; void *frames[DEPTH]; } Remembered;
typedef struct {
    uintptr_t low, high;
    int count;
    void *objects[MAX_REFERRERS];
    size_t sizes[MAX_REFERRERS], offsets[MAX_REFERRERS];
} Search;

static Remembered ring[RING];
static unsigned long sequence;
static pthread_mutex_t ring_lock = PTHREAD_MUTEX_INITIALIZER;
static const char *trigger, *site;
static size_t minimum_size = 900000;
static int searched;
static unsigned long allocations;
static __thread int in_hook;
static Search search;

static void remember(void *object, size_t size) {
    if (!object || size < minimum_size || in_hook) return;
    in_hook = 1;
    void *frames[DEPTH];
    int depth = backtrace(frames, DEPTH);
    int matches = site == NULL;
    for (int i = 0; i < depth && !matches; i++) {
        Dl_info info;
        if (dladdr(frames[i], &info) && info.dli_sname && strstr(info.dli_sname, site)) matches = 1;
    }
    if (matches) {
        pthread_mutex_lock(&ring_lock);
        Remembered *entry = &ring[sequence % RING];
        entry->object = object;
        entry->size = size;
        entry->sequence = sequence++;
        entry->depth = depth;
        memcpy(entry->frames, frames, sizeof(void *) * (size_t)depth);
        pthread_mutex_unlock(&ring_lock);
    }
    in_hook = 0;
}

static void visit(void *object, size_t size, void *data) {
    Search *current = data;
    uintptr_t base = (uintptr_t)object;
    if (base >= current->low && base < current->high) return;
    uintptr_t const *words = object;
    for (size_t i = 0; i < size / sizeof(uintptr_t); i++) {
        if (words[i] < current->low || words[i] >= current->high) continue;
        if (current->count < MAX_REFERRERS) {
            current->objects[current->count] = object;
            current->sizes[current->count] = size;
            current->offsets[current->count] = i * sizeof(uintptr_t);
        }
        current->count++;
        return;
    }
}

static void *enumerate(void *unused) {
    (void)unused;
    GC_enumerate_reachable_objects_inner(visit, &search);
    return NULL;
}

static void report(FILE *file) {
    unsigned long first = sequence > RING ? sequence - RING : 0;
    for (unsigned long index = first; index < sequence; index++) {
        Remembered *entry = &ring[index % RING];
        void *base = GC_base(entry->object);
        if (!base) continue;
        fprintf(file, "TARGET sequence=%lu/%lu object=%p size=%zu\n", entry->sequence, sequence,
            entry->object, entry->size);
        char **names = backtrace_symbols(entry->frames, entry->depth);
        for (int i = 1; i < entry->depth && i < 14; i++) fprintf(file, "      %s\n", names[i]);
        free(names);
        uintptr_t low = (uintptr_t)base, high = low + GC_size(base);
        for (int level = 0; level < 12; level++) {
            memset(&search, 0, sizeof search);
            search.low = low;
            search.high = high;
            GC_call_with_alloc_lock(enumerate, NULL);
            fprintf(file, "  level %d: [%p,+%lu) has %d heap referrers\n", level, (void *)low,
                (unsigned long)(high - low), search.count);
            for (int i = 0; i < search.count && i < 8; i++) {
                uintptr_t const *words = search.objects[i];
                fprintf(file, "    object %p size %zu offset %zu words:", search.objects[i],
                    search.sizes[i], search.offsets[i]);
                for (size_t word = 0; word < 8 && word * sizeof(uintptr_t) < search.sizes[i]; word++)
                    fprintf(file, " %lx", (unsigned long)words[word]);
                fprintf(file, "\n");
            }
            if (!search.count) {
                fprintf(file, "  -> no heap referrer: root\n");
                break;
            }
            low = (uintptr_t)search.objects[0];
            high = low + search.sizes[0];
        }
        return;
    }
    fprintf(file, "no remembered allocation is still reachable\n");
}

static void maybe_search(void) {
    if (searched || !trigger || in_hook) return;
    struct stat info;
    if (stat(trigger, &info) != 0) return;
    searched = 1;
    in_hook = 1;
    const char *path = getenv("GC_RETAINERS_OUT");
    FILE *file = fopen(path ? path : "/tmp/gc-retainers.txt", "w");
    if (file) {
        GC_gcollect();
        report(file);
        fclose(file);
    }
    in_hook = 0;
}

__attribute__((constructor)) static void initialize(void) {
    trigger = getenv("GC_RETAINERS_TRIGGER");
    site = getenv("GC_RETAINERS_SITE");
    const char *value = getenv("GC_RETAINERS_MIN");
    if (value) minimum_size = strtoul(value, 0, 10);
}

static void *remembered_malloc(size_t size) {
    void *object = GC_malloc(size);
    remember(object, size);
    if ((++allocations & 1023) == 0) maybe_search();
    return object;
}

static void *remembered_realloc(void *old, size_t size) {
    void *object = GC_realloc(old, size);
    remember(object, size);
    return object;
}

#define INTERPOSE(replacement, original) \
    __attribute__((used)) static struct { const void *replacement, *original; } \
    interpose_##original __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)replacement, (const void *)original }
INTERPOSE(remembered_malloc, GC_malloc);
INTERPOSE(remembered_realloc, GC_realloc);
