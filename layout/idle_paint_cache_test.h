#ifndef VOX_IDLE_PAINT_CACHE_TEST_H
#define VOX_IDLE_PAINT_CACHE_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_idle_paint_weak;
static void vox_idle_paint_watch(unsigned index, void *pointer) {
    assert(index < 8 && pointer);
    void *owner = GC_base(pointer);
    assert(owner);
    if (!vox_idle_paint_weak) vox_idle_paint_weak = GC_MALLOC_ATOMIC(8 * sizeof(void *));
    assert(vox_idle_paint_weak);
    GC_unregister_disappearing_link(&vox_idle_paint_weak[index]);
    vox_idle_paint_weak[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_idle_paint_weak[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_idle_paint_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_idle_paint_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
static void *vox_idle_paint_worker(void *opaque) {
    void (*run)(void) = *(void (**)(void))opaque;
    run(); return NULL;
}
static void vox_idle_paint_run_worker(void (*run)(void)) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_idle_paint_worker, &run) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_idle_paint_mask;
static void vox_idle_paint_observe(void) {
    assert(vox_idle_paint_weak);
    unsigned mask = 0;
    for (unsigned i = 0; i < 8; ++i) if (vox_idle_paint_weak[i]) mask |= 1u << i;
    vox_idle_paint_mask = mask;
}
static unsigned vox_idle_paint_alive(void) {
    vox_idle_paint_run_worker(vox_idle_paint_observe);
    return vox_idle_paint_mask;
}
#endif
#endif
