#ifndef VOX_PLATFORM_CLOSURE_RELEASE_TEST_H
#define VOX_PLATFORM_CLOSURE_RELEASE_TEST_H
#if defined(_VGCBOEHM) || defined(V_GCBOEHM_NATIVE)
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>

static void **vox_closure_release_weak_owner;
static void vox_closure_release_watch(void *owner) {
    assert(GC_base(owner) == owner);
    if (!vox_closure_release_weak_owner)
        vox_closure_release_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_closure_release_weak_owner);
    GC_unregister_disappearing_link(&vox_closure_release_weak_owner[0]);
    vox_closure_release_weak_owner[0] = owner;
    assert(GC_general_register_disappearing_link(&vox_closure_release_weak_owner[0], owner) == GC_SUCCESS);
}
static void *vox_closure_release_worker(void *opaque) {
    ((void (*)(void))opaque)();
    return NULL;
}
// Run work on an exited thread, so no stale stack slot keeps its objects.
static void vox_closure_release_run_worker(void (*work)(void)) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_closure_release_worker, (void *)work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static __attribute__((noinline)) void vox_closure_release_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_closure_release_collect(depth - 1); else GC_gcollect();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
static unsigned vox_closure_release_alive;
static void vox_closure_release_observe(void) {
    vox_closure_release_alive = vox_closure_release_weak_owner[0] != NULL;
}
static unsigned vox_closure_release_owner_alive(void) {
    vox_closure_release_collect(8);
    vox_closure_release_collect(8);
    vox_closure_release_run_worker(vox_closure_release_observe);
    return vox_closure_release_alive;
}
#endif
#endif
