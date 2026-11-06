#ifndef VOX_CSS_RULE_CALLBACK_LIFETIME_TEST_H
#define VOX_CSS_RULE_CALLBACK_LIFETIME_TEST_H
#if defined(_VGCBOEHM) || defined(CUSTOM_DEFINE_gcboehm)
#include <assert.h>
#include <stdint.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>

// Atomic weak slots observe ownership without rooting either graph.
static void **vox_css_rule_lifetime_weak_owners;
static void vox_css_rule_lifetime_watch_owner(unsigned index, void *owner) {
    assert(index < 2 && GC_base(owner) == owner);
    if (!vox_css_rule_lifetime_weak_owners)
        vox_css_rule_lifetime_weak_owners = GC_MALLOC_ATOMIC(2 * sizeof(void *));
    assert(vox_css_rule_lifetime_weak_owners);
    vox_css_rule_lifetime_weak_owners[index] = owner;
    assert(GC_general_register_disappearing_link(&vox_css_rule_lifetime_weak_owners[index], owner) == GC_SUCCESS);
}
static __attribute__((noinline)) void vox_css_rule_lifetime_collect(unsigned depth) {
    volatile uintptr_t scrub[2048] = {0};
    if (depth) vox_css_rule_lifetime_collect(depth - 1); else GC_gcollect_and_unmap();
    for (unsigned index = 0; index != 2048; ++index) scrub[index] = 0;
}
struct VoxCSSRuleLifetimeWorker { void (*run)(void); };
static void *vox_css_rule_lifetime_worker(void *opaque) {
    ((struct VoxCSSRuleLifetimeWorker *)opaque)->run();
    return NULL;
}
static void vox_css_rule_lifetime_run_worker(void (*run)(void)) {
    // Joined threads leave no obsolete V stack/register roots in the collector.
    struct VoxCSSRuleLifetimeWorker work = {run};
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_css_rule_lifetime_worker, &work) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
}
static unsigned vox_css_rule_lifetime_alive_mask;
static void vox_css_rule_lifetime_observe_owners(void) {
    assert(vox_css_rule_lifetime_weak_owners);
    vox_css_rule_lifetime_alive_mask = (vox_css_rule_lifetime_weak_owners[0] != NULL)
        | ((vox_css_rule_lifetime_weak_owners[1] != NULL) << 1);
}
static unsigned vox_css_rule_lifetime_owners_alive(void) {
    // Read weak addresses on an exited thread too: even a boolean weak query
    // can otherwise leave an owner in the caller thread's machine registers.
    vox_css_rule_lifetime_run_worker(vox_css_rule_lifetime_observe_owners);
    return vox_css_rule_lifetime_alive_mask;
}
#endif
#endif
