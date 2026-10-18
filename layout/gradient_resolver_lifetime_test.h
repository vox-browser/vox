#ifndef VOX_GRADIENT_RESOLVER_LIFETIME_TEST_H
#define VOX_GRADIENT_RESOLVER_LIFETIME_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_gradient_owner_weak;
static void vox_gradient_owner_watch(unsigned index, void *owner) {
    assert(index < 2 && GC_base(owner) == owner);
    if (!vox_gradient_owner_weak) vox_gradient_owner_weak = GC_MALLOC_ATOMIC(2 * sizeof(void *));
    assert(vox_gradient_owner_weak);
    GC_unregister_disappearing_link(&vox_gradient_owner_weak[index]);
    vox_gradient_owner_weak[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_gradient_owner_weak[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_gradient_owner_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_gradient_owner_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned i = 0; i != 2048; ++i) scrub[i] = 0;
}
static void *vox_gradient_owner_worker_entry(void *opaque) {
    (*(void (**)(void))opaque)();
    return NULL;
}
static void vox_gradient_owner_worker(void (*run)(void)) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_gradient_owner_worker_entry, &run) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_gradient_owner_mask;
static void vox_gradient_owner_observe(void) {
    assert(vox_gradient_owner_weak);
    vox_gradient_owner_mask = 0;
    for (unsigned i = 0; i != 2; ++i) if (vox_gradient_owner_weak[i]) vox_gradient_owner_mask |= 1u << i;
}
static unsigned vox_gradient_owner_alive(void) {
    vox_gradient_owner_worker(vox_gradient_owner_observe);
    return vox_gradient_owner_mask;
}
#endif
#endif
