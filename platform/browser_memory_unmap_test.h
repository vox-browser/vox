#ifndef VOX_BROWSER_MEMORY_UNMAP_TEST_H
#define VOX_BROWSER_MEMORY_UNMAP_TEST_H
#if defined(_VGCBOEHM) || defined(CUSTOM_DEFINE_gcboehm) || defined(V_GCBOEHM_NATIVE)
#include <assert.h>
#include <string.h>
#include <gc/gc.h>
#include <gc/gc_pthread_redirects.h>
#ifdef HBLKSIZE
#include <gc/gc_mark.h>
#endif
static void **vox_idle_unmap_weak;
static size_t vox_idle_unmap_baseline;
static void *vox_idle_unmap_allocate(void *unused) {
    (void)unused;
    void *temporary = GC_MALLOC_ATOMIC(32 * 1024 * 1024);
    assert(temporary);
    memset(temporary, 0x5a, 32 * 1024 * 1024);
    *vox_idle_unmap_weak = temporary;
    assert(GC_general_register_disappearing_link(vox_idle_unmap_weak, temporary) == GC_SUCCESS);
    return NULL;
}
static void vox_idle_unmap_prepare(void) {
#ifdef HBLKSIZE
    assert(GC_get_hblk_size() == HBLKSIZE);
#endif
    vox_idle_unmap_weak = GC_MALLOC_ATOMIC(sizeof(void *));
    assert(vox_idle_unmap_weak);
    vox_idle_unmap_baseline = GC_get_unmapped_bytes();
    GC_disable();
    pthread_t thread;
    assert(GC_pthread_create(&thread, NULL, vox_idle_unmap_allocate, NULL) == 0);
    assert(GC_pthread_join(thread, NULL) == 0);
    GC_enable();
}
static int vox_idle_unmap_released(void) {
    size_t unmapped = GC_get_unmapped_bytes();
    return !*vox_idle_unmap_weak && unmapped >= vox_idle_unmap_baseline
        && unmapped - vox_idle_unmap_baseline >= 16 * 1024 * 1024;
}
#endif
#endif
