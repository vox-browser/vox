#ifndef VOX_DOM_CURSOR_TIMER_LIFETIME_TEST_H
#define VOX_DOM_CURSOR_TIMER_LIFETIME_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>
static void **vox_cursor_weak_owner;
static void vox_cursor_watch_owner(void *owner) {
    assert(GC_base(owner) == owner);
    if (vox_cursor_weak_owner)
        GC_unregister_disappearing_link(vox_cursor_weak_owner);
    vox_cursor_weak_owner = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_cursor_weak_owner);
    *vox_cursor_weak_owner = owner;
    assert(GC_general_register_disappearing_link(vox_cursor_weak_owner, owner) == GC_SUCCESS);
}
struct VoxCursorWorker { void (*run)(void); };
static void *vox_cursor_worker(void *opaque) {
    ((struct VoxCursorWorker *)opaque)->run();
    return NULL;
}
static void vox_cursor_run_worker(void (*run)(void)) {
    struct VoxCursorWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_cursor_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static int vox_cursor_alive;
static void vox_cursor_observe_owner(void) {
    vox_cursor_alive = *vox_cursor_weak_owner != NULL;
}
static int vox_cursor_owner_alive(void) {
    // Do not leave a weak owner address in the main thread's registers.
    vox_cursor_run_worker(vox_cursor_observe_owner);
    return vox_cursor_alive;
}
static int vox_cursor_timer_is_scanned(void *timer) {
    size_t allocated;
    return GC_base(timer) == timer && GC_get_kind_and_size(timer, &allocated) == 1;
}
static __attribute__((noinline)) void vox_cursor_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_cursor_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
#endif
#endif
