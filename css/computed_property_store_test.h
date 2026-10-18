#ifndef VOX_COMPUTED_PROPERTY_STORE_TEST_H
#define VOX_COMPUTED_PROPERTY_STORE_TEST_H
#define vox_property_store_bytes() ((unsigned)sizeof(css__ComputedPropertyStore))
#define vox_property_page_bytes() ((unsigned)sizeof(css__ComputedPropertyPage))
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_property_store_weak;
static void vox_property_store_watch(unsigned index, void *owner) {
    assert(index < 3 && GC_base(owner) == owner);
    if (!vox_property_store_weak) vox_property_store_weak = GC_MALLOC_ATOMIC(3 * sizeof(void *));
    assert(vox_property_store_weak);
    GC_unregister_disappearing_link(&vox_property_store_weak[index]);
    vox_property_store_weak[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_property_store_weak[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_property_store_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_property_store_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned i = 0; i != sizeof scrub / sizeof scrub[0]; ++i) scrub[i] = 0;
}
static void *vox_property_store_worker_entry(void *opaque) {
    (*(void (**)(void))opaque)();
    return NULL;
}
static void vox_property_store_worker(void (*run)(void)) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_property_store_worker_entry, &run) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_property_store_mask;
static void vox_property_store_observe(void) {
    assert(vox_property_store_weak);
    vox_property_store_mask = 0;
    for (unsigned i = 0; i != 3; ++i) if (vox_property_store_weak[i]) vox_property_store_mask |= 1u << i;
}
static unsigned vox_property_store_alive(void) {
    vox_property_store_worker(vox_property_store_observe);
    return vox_property_store_mask;
}
#endif
#endif
