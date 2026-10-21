#ifndef VOX_LENGTH_PERCENTAGE_STORAGE_TEST_H
#define VOX_LENGTH_PERCENTAGE_STORAGE_TEST_H
#if defined(_VGCBOEHM) || defined(CUSTOM_DEFINE_gcboehm) || defined(V_GCBOEHM_NATIVE)
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_length_percentage_weak_owner;
static void vox_length_percentage_watch(void *owner) {
    assert(GC_base(owner) == owner);
    if (!vox_length_percentage_weak_owner)
        vox_length_percentage_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    GC_unregister_disappearing_link(vox_length_percentage_weak_owner);
    *vox_length_percentage_weak_owner = owner;
    assert(GC_general_register_disappearing_link(vox_length_percentage_weak_owner, owner) == GC_SUCCESS);
}
static int vox_length_percentage_array_kind(void *data) {
    size_t bytes;
    return GC_get_kind_and_size(GC_base(data), &bytes);
}
static __attribute__((noinline)) void vox_length_percentage_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_length_percentage_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned i = 0; i != 2048; ++i) scrub[i] = 0;
}
struct VoxLengthPercentageWorker { void (*run)(void); };
static void *vox_length_percentage_worker(void *opaque) {
    ((struct VoxLengthPercentageWorker *)opaque)->run();
    return NULL;
}
static void vox_length_percentage_run_worker(void (*run)(void)) {
    struct VoxLengthPercentageWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_length_percentage_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static int vox_length_percentage_observed;
static void vox_length_percentage_observe(void) {
    vox_length_percentage_observed = *vox_length_percentage_weak_owner != NULL;
}
static int vox_length_percentage_alive(void) {
    vox_length_percentage_run_worker(vox_length_percentage_observe);
    return vox_length_percentage_observed;
}
#endif
#endif
