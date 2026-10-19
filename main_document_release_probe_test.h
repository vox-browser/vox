// Temporary diagnostic: why is a watched GC object still reachable?
#ifndef VOX_MAIN_DOCUMENT_RELEASE_PROBE_TEST_H
#define VOX_MAIN_DOCUMENT_RELEASE_PROBE_TEST_H
#if defined(__APPLE__) && defined(VOX_DOCUMENT_RETENTION_DIAGNOSTICS) && (defined(_VGCBOEHM) || defined(V_GCBOEHM_NATIVE))
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>

static void **vox_probe_weak;
static void *vox_probe_extra_seed;
static void vox_probe_set_seed(void *seed) { vox_probe_extra_seed = seed; }
static int vox_probe_count;
static void vox_probe_watch(void *owner) {
    if (!owner || GC_base(owner) != owner) return;
    if (!vox_probe_weak) vox_probe_weak = GC_MALLOC_ATOMIC(64 * sizeof(void *));
    if (vox_probe_count == 64) return;
    vox_probe_weak[vox_probe_count] = owner;
    GC_general_register_disappearing_link(&vox_probe_weak[vox_probe_count], owner);
    vox_probe_count++;
}
typedef struct { uintptr_t key; int parent; uintptr_t root_slot; } vox_probe_node;
typedef struct { vox_probe_node *nodes; size_t len, cap; size_t *table; size_t mask; } vox_probe_graph;
static size_t vox_probe_hash(uintptr_t k) { k ^= k >> 33; k *= 0xff51afd7ed558ccdULL; k ^= k >> 33; return (size_t)k; }
static long vox_probe_find(vox_probe_graph *g, uintptr_t key) {
    size_t i = vox_probe_hash(key) & g->mask;
    while (g->table[i]) { if (g->nodes[g->table[i] - 1].key == key) return (long)(g->table[i] - 1); i = (i + 1) & g->mask; }
    return -1;
}
static void vox_probe_grow(vox_probe_graph *g) {
    size_t size = (g->mask + 1) * 2;
    free(g->table); g->table = calloc(size, sizeof(size_t)); g->mask = size - 1;
    for (size_t n = 0; n < g->len; ++n) {
        size_t i = vox_probe_hash(g->nodes[n].key) & g->mask;
        while (g->table[i]) i = (i + 1) & g->mask;
        g->table[i] = n + 1;
    }
}
static long vox_probe_add(vox_probe_graph *g, uintptr_t key, int parent, uintptr_t slot) {
    if (vox_probe_find(g, key) >= 0) return -1;
    if (g->len == g->cap) { g->cap = g->cap ? g->cap * 2 : 1 << 20; g->nodes = realloc(g->nodes, g->cap * sizeof(vox_probe_node)); }
    if ((g->len + 1) * 2 > g->mask + 1) vox_probe_grow(g);
    g->nodes[g->len] = (vox_probe_node){key, parent, slot};
    size_t i = vox_probe_hash(key) & g->mask;
    while (g->table[i]) i = (i + 1) & g->mask;
    g->table[i] = g->len + 1;
    return (long)g->len++;
}
static void vox_probe_symbol(const char *label, uintptr_t address) {
    Dl_info info;
    if (address && dladdr((void *)address, &info) && info.dli_sname)
        fprintf(stderr, "%s%s+%ld\n", label, info.dli_sname, (long)(address - (uintptr_t)info.dli_saddr));
    else
        fprintf(stderr, "%s%lx\n", label, (unsigned long)address);
}
static void vox_probe_print_object(uintptr_t base) {
    size_t size = GC_size((void *)base);
    uintptr_t *w = (uintptr_t *)base;
    fprintf(stderr, "    obj %lx size %zu kind %d\n", (unsigned long)base, size, GC_get_kind_and_size((void *)base, NULL));
    for (size_t k = 0; k < size / sizeof(uintptr_t) && k < 40; ++k) {
        if (!w[k]) continue;
        Dl_info info;
        if (dladdr((void *)w[k], &info) && info.dli_sname)
            fprintf(stderr, "      [%zu] %lx %s+%ld\n", k, (unsigned long)w[k], info.dli_sname, (long)(w[k] - (uintptr_t)info.dli_saddr));
        else if (GC_base((void *)w[k]))
            fprintf(stderr, "      [%zu] %lx -> heap size %zu\n", k, (unsigned long)w[k], GC_size(GC_base((void *)w[k])));
    }
}
static int vox_probe_is_collector_slot(const void *slot) {
    Dl_info info;
    return dladdr(slot, &info) && info.dli_sname && strncmp(info.dli_sname, "GC_", 3) == 0;
}
typedef struct { vox_probe_graph g; } vox_probe_state;
static void vox_probe_seed_uncollectable(void *obj, size_t bytes, void *data) {
    (void)bytes;
    vox_probe_graph *g = data;
    int kind = GC_get_kind_and_size(obj, NULL);
    if (kind == 2 /* UNCOLLECTABLE */) vox_probe_add(g, (uintptr_t)obj, -1, 1);
}
static void *vox_probe_run(void *data) {
    void *target = data;
    vox_probe_graph g = {0};
    g.mask = (1 << 20) - 1; g.table = calloc(g.mask + 1, sizeof(size_t));
    // Seeds: data segments of every loaded image.
    for (uint32_t image = 0; image < _dyld_image_count(); ++image) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(image);
        const char *segments[] = {"__DATA", "__DATA_DIRTY"};
        for (int s = 0; s < 2; ++s) {
            unsigned long size = 0;
            uint8_t *seg = getsegmentdata(header, segments[s], &size);
            if (!seg) continue;
            for (unsigned long off = 0; off + 8 <= size; off += 8) {
                uintptr_t w = *(uintptr_t *)(seg + off);
                void *base = w ? GC_base((void *)w) : NULL;
                if (base && base != (void *)vox_probe_weak && !vox_probe_is_collector_slot(seg + off)) vox_probe_add(&g, (uintptr_t)base, -1, (uintptr_t)(seg + off));
            }
        }
    }
    GC_enumerate_reachable_objects_inner(vox_probe_seed_uncollectable, &g);
    if (vox_probe_extra_seed) vox_probe_add(&g, (uintptr_t)GC_base(vox_probe_extra_seed), -1, 2);
    long found = -1;
    for (size_t head = 0; head < g.len && found < 0; ++head) {
        uintptr_t base = g.nodes[head].key;
        if (base == (uintptr_t)target) { found = (long)head; break; }
        if (GC_get_kind_and_size((void *)base, NULL) == 0) continue;
        size_t size = GC_size((void *)base);
        uintptr_t *w = (uintptr_t *)base;
        for (size_t k = 0; k < size / 8; ++k) {
            void *child = w[k] ? GC_base((void *)w[k]) : NULL;
            if (child && child != (void *)vox_probe_weak) vox_probe_add(&g, (uintptr_t)child, (int)head, 0);
        }
    }
    fprintf(stderr, "probe: %zu objects reachable before target\n", g.len);
    if (found < 0) { fprintf(stderr, "probe: target not reachable from data/uncollectable roots\n"); }
    else {
        long c = found; int depth = 0;
        while (c >= 0 && depth < 60) {
            vox_probe_print_object(g.nodes[c].key);
            if (g.nodes[c].parent < 0) {
                if (g.nodes[c].root_slot == 1) fprintf(stderr, "    root: uncollectable object\n");
                else if (g.nodes[c].root_slot == 2) fprintf(stderr, "    root: BrowserApp\n");
                else vox_probe_symbol("    root: static ", g.nodes[c].root_slot);
            }
            c = g.nodes[c].parent; depth++;
        }
    }
    free(g.nodes); free(g.table);
    return NULL;
}

typedef struct { const char *name; int total; int reaching; } vox_probe_kind;
static int vox_probe_reaches(uintptr_t object, uintptr_t target, int depth) {
    if (object == target) return 1;
    if (depth == 0) return 0;
    if (GC_get_kind_and_size((void *)object, NULL) == 0) return 0;
    size_t size = GC_size((void *)object);
    if (size > 4096) size = 4096;
    uintptr_t *w = (uintptr_t *)object;
    for (size_t k = 0; k < size / 8; ++k) {
        void *child = w[k] ? GC_base((void *)w[k]) : NULL;
        if (child && vox_probe_reaches((uintptr_t)child, target, depth - 1)) return 1;
    }
    return 0;
}
static int vox_probe_kind_cmp(const void *a, const void *b) {
    const vox_probe_kind *x = a, *y = b;
    if (getenv("VOX_TRACE_BY_TOTAL")) return y->total - x->total;
    if (y->reaching != x->reaching) return y->reaching - x->reaching;
    return y->total - x->total;
}
static void *vox_probe_closures(void *data) {
    uintptr_t target = (uintptr_t)data;
    uint8_t *closure = getenv("VOX_LEGACY_CLOSURE_LAYOUT") ? dlsym(RTLD_DEFAULT, "g_closure") : NULL;
    if (!closure) { fprintf(stderr, "probe: g_closure not exported\n"); return NULL; }
    int len = *(int *)(closure + 204);
    uint8_t *all_deleted = *(uint8_t **)(closure + 216);
    uintptr_t *keys = *(uintptr_t **)(closure + 224);
    uint8_t *values = *(uint8_t **)(closure + 232);
    vox_probe_kind *kinds = calloc(4096, sizeof(vox_probe_kind));
    int nkinds = 0, live = 0, reaching = 0;
    for (int i = 0; i < len; ++i) {
        if (all_deleted && all_deleted[i]) continue;
        uintptr_t exec = keys[i];
        uintptr_t ctx = *(uintptr_t *)(values + (size_t)i * 24);
        if (!exec || !ctx) continue;
        live++;
        uintptr_t func = *(uintptr_t *)(exec - 0x4000 + 8);
        Dl_info info;
        const char *name = (func && dladdr((void *)func, &info) && info.dli_sname) ? info.dli_sname : "?";
        int k = 0;
        for (; k < nkinds; ++k) if (kinds[k].name == name || strcmp(kinds[k].name, name) == 0) break;
        if (k == nkinds && nkinds < 4096) { kinds[nkinds].name = name; nkinds++; }
        kinds[k].total++;
        void *base = GC_base((void *)ctx);
        if (base && vox_probe_reaches((uintptr_t)base, target, 3)) { kinds[k].reaching++; reaching++; }
    }
    qsort(kinds, nkinds, sizeof(vox_probe_kind), vox_probe_kind_cmp);
    fprintf(stderr, "probe: %d live closures, %d reach the watched document within 3 hops, %d kinds\n", live, reaching, nkinds);
    for (int k = 0; k < nkinds && k < 60; ++k)
        fprintf(stderr, "probe-closure %6d %6d %s\n", kinds[k].reaching, kinds[k].total, kinds[k].name);
    free(kinds);
    return NULL;
}

typedef struct { uintptr_t *sinks; int nsinks; size_t bytes; size_t objects; } vox_probe_retained_args;
static int vox_probe_is_sink(vox_probe_retained_args *a, uintptr_t base) {
    for (int i = 0; i < a->nsinks; ++i) if (a->sinks[i] == base) return 1;
    return 0;
}
static void *vox_probe_retained_run(void *data) {
    vox_probe_retained_args *a = data;
    vox_probe_graph g = {0};
    g.mask = (1 << 22) - 1; g.table = calloc(g.mask + 1, sizeof(size_t));
    for (uint32_t image = 0; image < _dyld_image_count(); ++image) {
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(image);
        const char *segments[] = {"__DATA", "__DATA_DIRTY"};
        for (int s = 0; s < 2; ++s) {
            unsigned long size = 0;
            uint8_t *seg = getsegmentdata(header, segments[s], &size);
            if (!seg) continue;
            for (unsigned long off = 0; off + 8 <= size; off += 8) {
                uintptr_t w = *(uintptr_t *)(seg + off);
                void *base = w ? GC_base((void *)w) : NULL;
                if (base && base != (void *)vox_probe_weak && !vox_probe_is_sink(a, (uintptr_t)base)) vox_probe_add(&g, (uintptr_t)base, -1, 0);
            }
        }
    }
    GC_enumerate_reachable_objects_inner(vox_probe_seed_uncollectable, &g);
    for (size_t head = 0; head < g.len; ++head) {
        uintptr_t base = g.nodes[head].key;
        size_t size = GC_size((void *)base);
        a->bytes += size; a->objects++;
        if (GC_get_kind_and_size((void *)base, NULL) == 0) continue;
        uintptr_t *w = (uintptr_t *)base;
        for (size_t k = 0; k < size / 8; ++k) {
            void *child = w[k] ? GC_base((void *)w[k]) : NULL;
            if (child && child != (void *)vox_probe_weak && !vox_probe_is_sink(a, (uintptr_t)child)) vox_probe_add(&g, (uintptr_t)child, (int)head, 0);
        }
    }
    free(g.nodes); free(g.table);
    return NULL;
}
static size_t vox_probe_retained_bytes(uintptr_t *sinks, int nsinks) {
    vox_probe_retained_args a = {sinks, nsinks, 0, 0};
    GC_call_with_alloc_lock(vox_probe_retained_run, &a);
    return a.bytes;
}
static void vox_probe_retained_report(void *document) {
    uint8_t *closure = getenv("VOX_LEGACY_CLOSURE_LAYOUT") ? dlsym(RTLD_DEFAULT, "g_closure") : NULL;
    uintptr_t values = closure ? (uintptr_t)GC_base(*(void **)(closure + 232)) : 0;
    size_t total = vox_probe_retained_bytes(NULL, 0);
    uintptr_t doc = (uintptr_t)document;
    size_t without_doc = document ? vox_probe_retained_bytes(&doc, 1) : total;
    size_t without_closures = values ? vox_probe_retained_bytes(&values, 1) : total;
    uintptr_t both[2] = {doc, values};
    size_t without_both = (document && values) ? vox_probe_retained_bytes(both, 2) : total;
    fprintf(stderr, "probe-retained: reachable %zuM; only via old document %zuM; only via closure registry %zuM; via either %zuM\n",
        total >> 20, (total - without_doc) >> 20, (total - without_closures) >> 20, (total - without_both) >> 20);
}

typedef struct { size_t size; size_t count; size_t bytes; uintptr_t sample; } vox_probe_bucket;
static int vox_probe_bucket_cmp(const void *a, const void *b) {
    const vox_probe_bucket *x = a, *y = b;
    return x->bytes < y->bytes ? 1 : x->bytes > y->bytes ? -1 : 0;
}
typedef struct { uintptr_t doc; uintptr_t values; } vox_probe_diff_args;
static vox_probe_graph vox_probe_full_graph;
static void *vox_probe_diff_run(void *data) {
    vox_probe_diff_args *d = data;
    // Full reachability.
    vox_probe_graph full = {0};
    full.mask = (1 << 22) - 1; full.table = calloc(full.mask + 1, sizeof(size_t));
    vox_probe_graph cut = {0};
    cut.mask = (1 << 22) - 1; cut.table = calloc(cut.mask + 1, sizeof(size_t));
    for (int pass = 0; pass < 2; ++pass) {
        vox_probe_graph *g = pass == 0 ? &full : &cut;
        for (uint32_t image = 0; image < _dyld_image_count(); ++image) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(image);
            const char *segments[] = {"__DATA", "__DATA_DIRTY"};
            for (int s = 0; s < 2; ++s) {
                unsigned long size = 0;
                uint8_t *seg = getsegmentdata(header, segments[s], &size);
                if (!seg) continue;
                for (unsigned long off = 0; off + 8 <= size; off += 8) {
                    uintptr_t w = *(uintptr_t *)(seg + off);
                    void *base = w ? GC_base((void *)w) : NULL;
                    if (!base || base == (void *)vox_probe_weak) continue;
                    if (pass == 1 && ((uintptr_t)base == d->doc || (uintptr_t)base == d->values)) continue;
                    vox_probe_add(g, (uintptr_t)base, -1, 0);
                }
            }
        }
        GC_enumerate_reachable_objects_inner(vox_probe_seed_uncollectable, g);
        if (vox_probe_extra_seed) vox_probe_add(g, (uintptr_t)GC_base(vox_probe_extra_seed), -1, 0);
        for (size_t head = 0; head < g->len; ++head) {
            uintptr_t base = g->nodes[head].key;
            if (GC_get_kind_and_size((void *)base, NULL) == 0) continue;
            size_t size = GC_size((void *)base);
            uintptr_t *w = (uintptr_t *)base;
            for (size_t k = 0; k < size / 8; ++k) {
                void *child = w[k] ? GC_base((void *)w[k]) : NULL;
                if (!child || child == (void *)vox_probe_weak) continue;
                if (pass == 1 && ((uintptr_t)child == d->doc || (uintptr_t)child == d->values)) continue;
                vox_probe_add(g, (uintptr_t)child, (int)head, 0);
            }
        }
    }
    vox_probe_bucket *buckets = calloc(65536, sizeof(vox_probe_bucket));
    size_t diff_bytes = 0, diff_objects = 0;
    for (size_t i = 0; i < full.len; ++i) {
        uintptr_t base = full.nodes[i].key;
        if (vox_probe_find(&cut, base) >= 0) continue;
        size_t size = GC_size((void *)base);
        diff_bytes += size; diff_objects++;
        size_t slot = (size / 16) & 65535;
        if (size > 1048575) slot = 65535;
        buckets[slot].size = size; buckets[slot].count++; buckets[slot].bytes += size;
        if (!buckets[slot].sample || (GC_get_kind_and_size((void *)base, NULL) != 0 && GC_get_kind_and_size((void *)buckets[slot].sample, NULL) == 0)) buckets[slot].sample = base;
    }
    qsort(buckets, 65536, sizeof(vox_probe_bucket), vox_probe_bucket_cmp);
    fprintf(stderr, "probe-diff: %zu objects / %zuM only via old document or closures\n", diff_objects, diff_bytes >> 20);
    for (int b = 0; b < 25 && buckets[b].bytes; ++b) {
        fprintf(stderr, "probe-diff size %zu count %zu bytes %zuK kind %d\n", buckets[b].size, buckets[b].count, buckets[b].bytes >> 10, GC_get_kind_and_size((void *)buckets[b].sample, NULL));
        if (b < 14 && GC_get_kind_and_size((void *)buckets[b].sample, NULL) != 0) vox_probe_print_object(buckets[b].sample);
    }
    free(buckets);
    free(full.nodes); free(full.table); free(cut.nodes); free(cut.table);
    return NULL;
}
#include <gc/gc_pthread_redirects.h>
static void *vox_document_release_worker(void *opaque) {
    void (*run)(void *) = ((void (**)(void *))opaque)[0];
    run(((void **)opaque)[1]);
    return NULL;
}
static void vox_document_release_run_worker(void (*run)(void *), void *context) {
    pthread_t thread;
    void *pair[2] = {(void *)run, context};
    GC_pthread_create(&thread, NULL, vox_document_release_worker, pair);
    GC_pthread_join(thread, NULL);
}

static void vox_probe_histogram_collect(void *obj, size_t bytes, void *data) {
    size_t *h = data;
    size_t slot = bytes / 16; if (slot > 65535) slot = 65535;
    int kind = GC_get_kind_and_size(obj, NULL);
    h[slot * 2 + (kind == 0 ? 1 : 0)] += 1;
}
static void *vox_probe_histogram_run(void *data) { GC_enumerate_reachable_objects_inner(vox_probe_histogram_collect, data); return NULL; }
static void vox_probe_histogram(const char *path) {
    size_t *h = calloc(65536 * 2, sizeof(size_t));
    GC_gcollect();
    GC_call_with_alloc_lock(vox_probe_histogram_run, h);
    FILE *f = fopen(path, "w");
    for (size_t i = 0; i < 65536; ++i) {
        if (h[i * 2]) fprintf(f, "%zu scan %zu\n", i * 16, h[i * 2]);
        if (h[i * 2 + 1]) fprintf(f, "%zu atomic %zu\n", i * 16, h[i * 2 + 1]);
    }
    fclose(f);
    free(h);
}
static void vox_probe_explain(void) {
    if (!getenv("VOX_TRACE_RETENTION") || !vox_probe_weak) return;
    GC_gcollect();
    for (int i = 0; i < vox_probe_count; ++i) {
        void *target = vox_probe_weak[i];
        fprintf(stderr, "probe: watched document %d %s\n", i, target ? "ALIVE" : "released");
        if (target) {
            if (getenv("VOX_TRACE_RETAINED")) { vox_probe_retained_report(target); break; }
            if (getenv("VOX_TRACE_DIFF")) {
                uint8_t *closure = getenv("VOX_LEGACY_CLOSURE_LAYOUT") ? dlsym(RTLD_DEFAULT, "g_closure") : NULL;
                vox_probe_diff_args args = {(uintptr_t)target, closure ? (uintptr_t)GC_base(*(void **)(closure + 232)) : 0};
                GC_call_with_alloc_lock(vox_probe_diff_run, &args);
                break;
            }
            GC_call_with_alloc_lock(vox_probe_run, target); GC_call_with_alloc_lock(vox_probe_closures, target); break;
        }
    }
}
#else
static void vox_probe_watch(void *owner) { (void)owner; }
static void vox_probe_explain(void) {}
#endif
#endif
