#ifndef VOX_MAIN_NATIVE_MEMORY_TEST_H
#define VOX_MAIN_NATIVE_MEMORY_TEST_H
#include <stdint.h>
#include <stdlib.h>

// The focused fixture redirects only the two native scheduling entry points
// here. Encoded owners deliberately do not become conservative C GC roots.
typedef void (*VoxNativeMemoryTestCallback)(void *);
static uintptr_t native_memory_test_owners[32];
static VoxNativeMemoryTestCallback native_memory_test_callbacks[32];
static int native_memory_test_pending, native_memory_test_dispatches;
static int native_memory_test_graphics_schedules;
static const uintptr_t native_memory_test_mask = UINT64_C(0xa581d4e37cb2906f);

static void native_memory_test_reset(void) {
    if (native_memory_test_pending) abort();
    native_memory_test_dispatches = 0;
    native_memory_test_graphics_schedules = 0;
}
static void native_memory_test_dispatch(void *owner, VoxNativeMemoryTestCallback callback) {
    if (native_memory_test_pending == 32 || !owner || !callback) abort();
    int index = native_memory_test_pending++;
    native_memory_test_owners[index] = (uintptr_t)owner ^ native_memory_test_mask;
    native_memory_test_callbacks[index] = callback;
    native_memory_test_dispatches++;
}
static int native_memory_test_deliver(void *owner) {
    for (int i = 0; i < native_memory_test_pending; i++) {
        if ((native_memory_test_owners[i] ^ native_memory_test_mask) != (uintptr_t)owner) continue;
        VoxNativeMemoryTestCallback callback = native_memory_test_callbacks[i];
        --native_memory_test_pending;
        for (int j = i; j < native_memory_test_pending; j++) {
            native_memory_test_owners[j] = native_memory_test_owners[j + 1];
            native_memory_test_callbacks[j] = native_memory_test_callbacks[j + 1];
        }
        native_memory_test_owners[native_memory_test_pending] = 0;
        native_memory_test_callbacks[native_memory_test_pending] = NULL;
        callback(owner);
        return 1;
    }
    return 0;
}
static void native_memory_test_schedule_graphics(void) { native_memory_test_graphics_schedules++; }
static int native_memory_test_pending_count(void) { return native_memory_test_pending; }
static int native_memory_test_dispatch_count(void) { return native_memory_test_dispatches; }
static int native_memory_test_graphics_count(void) { return native_memory_test_graphics_schedules; }
static int native_memory_test_unused_slot_is_clear(void *data, int length, int capacity) {
    return capacity <= length || ((void **)data)[length] == NULL;
}
#endif
