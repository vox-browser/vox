#ifndef VOX_CSS_INVALIDATION_LIFETIME_TEST_H
#define VOX_CSS_INVALIDATION_LIFETIME_TEST_H
#if defined(_VGCBOEHM) || defined(CUSTOM_DEFINE_gcboehm)
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_invalidation_weak_owner;
static void vox_invalidation_watch_owner(void *owner) {
    assert(GC_base(owner) == owner);
    if (vox_invalidation_weak_owner)
        GC_unregister_disappearing_link(vox_invalidation_weak_owner);
    vox_invalidation_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_invalidation_weak_owner);
    *vox_invalidation_weak_owner = owner;
    assert(GC_general_register_disappearing_link(vox_invalidation_weak_owner, owner) == GC_SUCCESS);
}
struct VoxInvalidationWorker { void (*run)(void); };
static void *vox_invalidation_worker(void *opaque) {
    ((struct VoxInvalidationWorker *)opaque)->run();
    return NULL;
}
static void vox_invalidation_run_worker(void (*run)(void)) {
    struct VoxInvalidationWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_invalidation_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static int vox_invalidation_alive;
static void vox_invalidation_observe_owner(void) {
    vox_invalidation_alive = *vox_invalidation_weak_owner != NULL;
}
static int vox_invalidation_owner_alive(void) {
    // Do not leave a weak owner address in the main thread's registers.
    vox_invalidation_run_worker(vox_invalidation_observe_owner);
    return vox_invalidation_alive;
}
static __attribute__((noinline)) void vox_invalidation_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_invalidation_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
#endif
#endif
