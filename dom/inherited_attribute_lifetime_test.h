#ifndef VOX_INHERITED_ATTRIBUTE_LIFETIME_TEST_H
#define VOX_INHERITED_ATTRIBUTE_LIFETIME_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_inherited_attribute_weak_owner;
static void vox_inherited_attribute_watch_owner(void *owner) {
    assert(GC_base(owner) == owner);
    if (vox_inherited_attribute_weak_owner)
        GC_unregister_disappearing_link(vox_inherited_attribute_weak_owner);
    vox_inherited_attribute_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_inherited_attribute_weak_owner);
    *vox_inherited_attribute_weak_owner = owner;
    assert(GC_general_register_disappearing_link(vox_inherited_attribute_weak_owner, owner) == GC_SUCCESS);
}
struct VoxInheritedAttributeWorker { void (*run)(void); };
static void *vox_inherited_attribute_worker(void *opaque) {
    ((struct VoxInheritedAttributeWorker *)opaque)->run();
    return NULL;
}
static void vox_inherited_attribute_run_worker(void (*run)(void)) {
    struct VoxInheritedAttributeWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_inherited_attribute_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static int vox_inherited_attribute_alive;
static void vox_inherited_attribute_observe_owner(void) {
    vox_inherited_attribute_alive = *vox_inherited_attribute_weak_owner != NULL;
}
static int vox_inherited_attribute_owner_alive(void) {
    // Do not leave a weak owner address in the main thread's registers.
    vox_inherited_attribute_run_worker(vox_inherited_attribute_observe_owner);
    return vox_inherited_attribute_alive;
}
static __attribute__((noinline)) void vox_inherited_attribute_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_inherited_attribute_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
#endif
#endif
