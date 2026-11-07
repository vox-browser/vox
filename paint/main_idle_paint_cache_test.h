#ifndef VOX_MAIN_IDLE_PAINT_CACHE_TEST_H
#define VOX_MAIN_IDLE_PAINT_CACHE_TEST_H
#include "../native/main_native_memory_test.h"
#define vox_main_idle_paint_phase_capacity(list) \
    (((layout__DocumentLayoutResult *)((dom__DisplayList *)(list))->concrete_handle)->paint_phase_commands.cap)
#define vox_main_idle_paint_deliver(owner) native_memory_test_deliver(owner)
#endif
