#ifndef VOX_METAL_GPU_BUFFER_H
#define VOX_METAL_GPU_BUFFER_H
#include "drawing_buffer_darwin.h"

typedef struct { CFTypeRef device, buffer; uint64_t size; } VoxMetalGPUBuffer;

static void vox_metal_gpu_buffer_destroy(void* handle)
{
    VoxMetalGPUBuffer* buffer = handle;
    if (!buffer) return;
    CFRelease(buffer->device);
    CFRelease(buffer->buffer);
    free(buffer);
}

static void* vox_metal_gpu_buffer_create(void* target, uint64_t size)
{
    VoxMetalDrawingBuffer* context = target;
    if (!context) return NULL;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)context->device;
        if (size > device.maxBufferLength || size > SIZE_MAX) return NULL;
        id<MTLBuffer> storage = [device newBufferWithLength:MAX((NSUInteger)size, 1) options:MTLResourceStorageModeShared];
        VoxMetalGPUBuffer* result = storage ? calloc(1, sizeof(*result)) : NULL;
        if (result) {
            memset(storage.contents, 0, MAX((NSUInteger)size, 1));
            result->device = CFRetain(context->device);
            result->buffer = CFRetain((__bridge CFTypeRef)storage);
            result->size = size;
        }
        vox_metal_drop_owned(storage);
        return result;
    }
}

static int vox_metal_gpu_buffer_transfer(void* handle, uint64_t offset, uint64_t length, void* bytes, int upload)
{
    VoxMetalGPUBuffer* buffer = handle;
    if (!buffer || offset > buffer->size || length > buffer->size - offset || (length && !bytes)) return 0;
    if (length) {
        id<MTLBuffer> storage = (__bridge id<MTLBuffer>)buffer->buffer;
        if (upload) memcpy((uint8_t*)storage.contents + offset, bytes, length);
        else memcpy(bytes, (uint8_t*)storage.contents + offset, length);
    }
    return 1;
}
#endif
