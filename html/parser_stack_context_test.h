#ifndef VOX_HTML_PARSER_STACK_CONTEXT_TEST_H
#define VOX_HTML_PARSER_STACK_CONTEXT_TEST_H
#ifdef _VGCBOEHM
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_mark.h>
#include <gc/gc_pthread_redirects.h>

static void **vox_parser_stack_weak_owners;
static void vox_parser_stack_watch(unsigned index, void *owner) {
    assert(index < 2 && GC_base(owner) == owner);
    size_t size;
    assert(GC_get_kind_and_size(owner, &size) == 1);
    if (!vox_parser_stack_weak_owners)
        vox_parser_stack_weak_owners = GC_MALLOC_ATOMIC(2 * sizeof(void *));
    assert(vox_parser_stack_weak_owners);
    GC_unregister_disappearing_link(&vox_parser_stack_weak_owners[index]);
    vox_parser_stack_weak_owners[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_parser_stack_weak_owners[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_parser_stack_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_parser_stack_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
struct VoxParserStackWorker { void (*run)(void); void (*with_parser)(void *); };
static void *vox_parser_stack_worker(void *opaque) {
    struct VoxParserStackWorker *work = opaque;
    if (work->run) work->run();
    else {
        assert(vox_parser_stack_weak_owners[1]);
        work->with_parser(vox_parser_stack_weak_owners[1]);
    }
    return NULL;
}
static void vox_parser_stack_run_work(struct VoxParserStackWorker *work) {
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_parser_stack_worker, work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static void vox_parser_stack_run_worker(void (*run)(void)) {
    struct VoxParserStackWorker work = {run, NULL};
    vox_parser_stack_run_work(&work);
}
static void vox_parser_stack_run_with_parser(void (*run)(void *)) {
    struct VoxParserStackWorker work = {NULL, run};
    vox_parser_stack_run_work(&work);
}
static unsigned vox_parser_stack_alive_mask;
static void vox_parser_stack_observe(void) {
    assert(vox_parser_stack_weak_owners);
    vox_parser_stack_alive_mask = (vox_parser_stack_weak_owners[0] != NULL)
        | ((vox_parser_stack_weak_owners[1] != NULL) << 1);
}
static unsigned vox_parser_stack_owners_alive(void) {
    // Even a boolean weak query can leave a raw owner in machine registers.
    // Observe on an exited thread, so only this integer reaches the test stack.
    vox_parser_stack_run_worker(vox_parser_stack_observe);
    return vox_parser_stack_alive_mask;
}
#endif
#endif
