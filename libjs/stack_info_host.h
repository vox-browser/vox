/* AK/StackInfo.h::__builtin_frame_address(0), at the actual V method frame. */
#ifndef VOX2_AK_STACK_INFO_HOST_H
#define VOX2_AK_STACK_INFO_HOST_H
#include <stdint.h>
static inline __attribute__((always_inline)) uintptr_t vox_ak_current_frame_address(void)
{
    return (uintptr_t)__builtin_frame_address(0);
}
#endif
