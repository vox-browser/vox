#ifndef VOX_CSS_PARSED_VALUE_CACHE_LIFETIME_TEST_H
#define VOX_CSS_PARSED_VALUE_CACHE_LIFETIME_TEST_H
#include <assert.h>
#include <stdint.h>
#include <string.h>

// Compare cache storage without leaving its address as a conservative root.
struct VoxCSSCacheDense {
    int key_bytes, value_bytes, cap, len;
    uint32_t deletes;
    unsigned char *all_deleted, *keys, *values;
};
struct VoxCSSCacheMapPrefix {
    int key_bytes, value_bytes;
    uint32_t even_index;
    unsigned char cached_hashbits, shift;
    struct VoxCSSCacheDense key_values;
    uint32_t *metas;
    uint32_t extra_metas;
    _Bool has_string_keys;
    void (*hash_fn)(void), (*key_eq_fn)(void), (*clone_fn)(void), (*free_fn)(void);
    int len;
};
// Inferred globals are not visible to separate test files in the compatibility
// compiler. This alias observes the actual cache without a production test API.
#ifdef __APPLE__
extern unsigned char vox_css_cache_map_alias[] __asm__("_css_parsed_value_cache");
#else
extern unsigned char vox_css_cache_map_alias[] __asm__("css_parsed_value_cache");
#endif
static uint64_t vox_css_cache_storage_id(void) {
    struct VoxCSSCacheMapPrefix *map = (void *)vox_css_cache_map_alias;
    assert(map->key_bytes == sizeof(int) && map->value_bytes == sizeof(*map));
    return (uint64_t)(uintptr_t)map->key_values.values ^ UINT64_C(0xa581d4e37cb2906f);
}

static int vox_css_cache_length(void) {
    struct VoxCSSCacheMapPrefix *map = (void *)vox_css_cache_map_alias;
    assert(map->key_bytes == sizeof(int) && map->value_bytes == sizeof(*map));
    return map->len;
}
static uint64_t vox_css_cache_value_id(void *raw_value) {
    uintptr_t payload;
    memcpy(&payload, raw_value, sizeof(payload));
    return (uint64_t)payload ^ UINT64_C(0xa581d4e37cb2906f);
}

#ifdef _VGCBOEHM
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_css_cache_weak_owner;
static void vox_css_cache_watch_owner(void *owner) {
    assert(GC_base(owner) == owner);
    vox_css_cache_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_css_cache_weak_owner);
    *vox_css_cache_weak_owner = owner;
    assert(GC_general_register_disappearing_link(vox_css_cache_weak_owner, owner) == GC_SUCCESS);
}
struct VoxCSSCacheWorker { void (*run)(void); };
static void *vox_css_cache_worker(void *opaque) {
    ((struct VoxCSSCacheWorker *)opaque)->run();
    return NULL;
}
static void vox_css_cache_run_worker(void (*run)(void)) {
    // Discard returned V stack/register roots before checking reachability.
    struct VoxCSSCacheWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_css_cache_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static int vox_css_cache_alive;
static void vox_css_cache_observe_owner(void) {
    vox_css_cache_alive = *vox_css_cache_weak_owner != NULL;
}
static int vox_css_cache_owner_alive(void) {
    // Even a boolean weak query can leave an address in caller registers.
    vox_css_cache_run_worker(vox_css_cache_observe_owner);
    return vox_css_cache_alive;
}
static __attribute__((noinline)) void vox_css_cache_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_css_cache_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
#endif
#endif
