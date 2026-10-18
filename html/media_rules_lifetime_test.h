#ifndef VOX_HTML_MEDIA_RULES_LIFETIME_TEST_H
#define VOX_HTML_MEDIA_RULES_LIFETIME_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>

static void **vox_media_rules_weak_owners;
static void vox_media_rules_watch(unsigned index, void *owner) {
    assert(index < 2 && GC_base(owner) == owner);
    size_t size;
    assert(GC_get_kind_and_size(owner, &size) == 1);
    if (!vox_media_rules_weak_owners)
        vox_media_rules_weak_owners = GC_MALLOC_ATOMIC(2 * sizeof(void *));
    assert(vox_media_rules_weak_owners);
    GC_unregister_disappearing_link(&vox_media_rules_weak_owners[index]);
    vox_media_rules_weak_owners[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_media_rules_weak_owners[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_media_rules_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_media_rules_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
static void *vox_media_rules_worker(void *opaque) {
    void (*run)(void) = *(void (**)(void))opaque;
    run();
    return NULL;
}
static void vox_media_rules_run_worker(void (*run)(void)) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_media_rules_worker, &run) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_media_rules_alive_mask;
static void vox_media_rules_observe(void) {
    assert(vox_media_rules_weak_owners);
    vox_media_rules_alive_mask = (vox_media_rules_weak_owners[0] != NULL)
        | ((vox_media_rules_weak_owners[1] != NULL) << 1);
}
static unsigned vox_media_rules_owners_alive(void) {
    // Even a boolean weak query can leave a raw owner in machine registers.
    // Observe on an exited thread, so only this integer reaches the test stack.
    vox_media_rules_run_worker(vox_media_rules_observe);
    return vox_media_rules_alive_mask;
}
#endif
#endif
