#ifndef VOX_METAL_CAPABILITIES_H
#define VOX_METAL_CAPABILITIES_H
#include "drawing_buffer_darwin.h"
static uint32_t vox_metal_device_sample_mask(void* owner)
{
    VoxMetalDrawingBuffer* target = owner;
    if (!target || !target->device) return 0;
    id<MTLDevice> device = (__bridge id<MTLDevice>)target->device;
    uint32_t mask = 1u << 1;
    for (unsigned count = 2; count <= 8; count *= 2)
        if ([device supportsTextureSampleCount:count]) mask |= 1u << count;
    return mask;
}
#endif
