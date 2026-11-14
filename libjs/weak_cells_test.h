/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_LIBJS_WEAK_CELLS_TEST_H
#define VOX_LIBJS_WEAK_CELLS_TEST_H
#include "weak_cells.h"
typedef struct { void *slot; uint64_t encoded; } VoxWeakTestKey;

/* Keep raw key addresses out of the V test's conservative stack roots. */
static __attribute__((noinline)) void *vox_libjs_weak_test_key(size_t bytes) {
    VoxWeakTestKey *state = GC_MALLOC(sizeof(*state));
    void *key = GC_MALLOC(bytes);
    state->slot = vox_libjs_weak_cell_new(key);
    state->encoded = ~(uint64_t)(uintptr_t)key;
    return state;
}
static void *vox_libjs_weak_test_slot(void *state) { return ((VoxWeakTestKey *)state)->slot; }
static uint64_t vox_libjs_weak_test_encoded(void *state) { return ((VoxWeakTestKey *)state)->encoded; }
static __attribute__((noinline)) void vox_libjs_weak_test_collect(void) {
    volatile uintptr_t scrub[16384];
    for (size_t i = 0; i < 16384; ++i) scrub[i] = 0;
    GC_gcollect();
    GC_invoke_finalizers();
    GC_reachable_here(scrub);
}
#endif
