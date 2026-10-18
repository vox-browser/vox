#ifndef VOX_CSS_COMPACT_SELECTOR_STORAGE_TEST_H
#define VOX_CSS_COMPACT_SELECTOR_STORAGE_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>

// Atomic weak slots observe ownership without rooting either graph.
static void **vox_compact_selector_weak_owners;
static void vox_compact_selector_watch_owner(unsigned index, void *owner) {
    assert(index < 2 && GC_base(owner) == owner);
    if (!vox_compact_selector_weak_owners)
        vox_compact_selector_weak_owners = GC_MALLOC_ATOMIC(2 * sizeof(void *));
    assert(vox_compact_selector_weak_owners);
    GC_unregister_disappearing_link(&vox_compact_selector_weak_owners[index]);
    vox_compact_selector_weak_owners[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_compact_selector_weak_owners[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_compact_selector_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_compact_selector_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
struct VoxCompactSelectorWorker { void (*run)(void); };
static void *vox_compact_selector_worker(void *opaque) {
    ((struct VoxCompactSelectorWorker *)opaque)->run();
    return NULL;
}
static void vox_compact_selector_run_worker(void (*run)(void)) {
    // Joined threads leave no obsolete V stack/register roots in the collector.
    struct VoxCompactSelectorWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_compact_selector_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_compact_selector_observed_mask;
static void vox_compact_selector_observe_owners(void) {
    assert(vox_compact_selector_weak_owners);
    vox_compact_selector_observed_mask = (vox_compact_selector_weak_owners[0] != NULL)
        | ((vox_compact_selector_weak_owners[1] != NULL) << 1);
}
static unsigned vox_compact_selector_alive_mask(void) {
    // Read weak addresses on an exited thread too: even a boolean weak query
    // can otherwise leave an owner in the caller thread's machine registers.
    vox_compact_selector_run_worker(vox_compact_selector_observe_owners);
    return vox_compact_selector_observed_mask;
}
static int vox_compact_selector_array_kind(void *data) {
    void *base = GC_base(data);
    assert(base);
    size_t bytes;
    return GC_get_kind_and_size(base, &bytes);
}
static size_t vox_compact_selector_array_size(void *data) {
    void *base = GC_base(data);
    assert(base);
    return GC_size(base);
}
#endif
#endif
