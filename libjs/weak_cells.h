/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_LIBJS_WEAK_CELLS_H
#define VOX_LIBJS_WEAK_CELLS_H
#include <stdint.h>
#include "../platform/boehm_gc.h"

/* The slot is atomic so its target is not a conservative strong root. libgc
 * clears it before reclaiming the target; the V owner keeps the slot alive. */
static void *vox_libjs_weak_cell_new(void *target) {
    void **slot = GC_MALLOC_ATOMIC(sizeof(void *));
    if (!slot) return NULL;
    *slot = target;
    void *base = GC_base(target);
    if (base) {
        int result = GC_GENERAL_REGISTER_DISAPPEARING_LINK(slot, base);
        if (result != GC_SUCCESS && result != GC_DUPLICATE) {
            GC_FREE(slot);
            return NULL;
        }
    }
    return slot;
}

static void *vox_libjs_weak_cell_read_locked(void *slot) {
    return *(void **)slot;
}

static void *vox_libjs_weak_cell_read(void *slot) {
    return slot ? GC_call_with_alloc_lock(vox_libjs_weak_cell_read_locked, slot) : NULL;
}

static uint64_t vox_libjs_weak_cell_epoch(void) {
    return (uint64_t)GC_get_gc_no();
}
#endif
