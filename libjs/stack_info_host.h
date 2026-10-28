/* AK/StackInfo.h::__builtin_frame_address(0), at the actual V method frame. */
#ifndef VOX2_AK_STACK_INFO_HOST_H
#define VOX2_AK_STACK_INFO_HOST_H
#include <stdint.h>
#if defined(__linux__)
#include <pthread.h>
static inline int vox_ak_current_thread_attributes(pthread_attr_t* attributes)
{
    return pthread_getattr_np(pthread_self(), attributes);
}
#endif
static inline __attribute__((always_inline)) uintptr_t vox_ak_current_frame_address(void)
{
    return (uintptr_t)__builtin_frame_address(0);
}
#endif
