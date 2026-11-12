#ifndef VOX_METAL_DEPTH_STENCIL_H
#define VOX_METAL_DEPTH_STENCIL_H
#include "drawing_buffer_darwin.h"
typedef struct { CFTypeRef device, queue, texture; int width, height; } VoxMetalDepthStencil;

static int vox_metal_depth_stencil_clear(void* handle, double depth, uint32_t stencil)
{
    VoxMetalDepthStencil* storage = handle;
    if (!storage) return 0;
    @autoreleasepool {
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.depthAttachment.texture = (__bridge id<MTLTexture>)storage->texture;
        pass.depthAttachment.loadAction = MTLLoadActionClear;
        pass.depthAttachment.storeAction = MTLStoreActionStore;
        pass.depthAttachment.clearDepth = depth;
        pass.stencilAttachment.texture = (__bridge id<MTLTexture>)storage->texture;
        pass.stencilAttachment.loadAction = MTLLoadActionClear;
        pass.stencilAttachment.storeAction = MTLStoreActionStore;
        pass.stencilAttachment.clearStencil = stencil;
        id<MTLCommandBuffer> command = [(__bridge id<MTLCommandQueue>)storage->queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        if (!command || !encoder) return 0;
        [encoder endEncoding]; [command commit]; [command waitUntilCompleted];
        return command.status == MTLCommandBufferStatusCompleted;
    }
}

static void vox_metal_depth_stencil_destroy(void* handle)
{
    VoxMetalDepthStencil* storage = handle;
    if (!storage) return;
    if (storage->texture) CFRelease(storage->texture);
    CFRelease(storage->queue); CFRelease(storage->device); free(storage);
}

static void* vox_metal_depth_stencil_create(void* owner, int width, int height)
{
    VoxMetalDrawingBuffer* target = owner;
    if (!target || width < 1 || height < 1 || width > 16384 || height > 16384) return NULL;
    @autoreleasepool {
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8 width:width height:height mipmapped:NO];
        descriptor.storageMode = MTLStorageModePrivate;
        descriptor.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> texture = [(__bridge id<MTLDevice>)target->device newTextureWithDescriptor:descriptor];
        VoxMetalDepthStencil* storage = texture ? calloc(1, sizeof(*storage)) : NULL;
        if (storage) {
            storage->device = CFRetain(target->device); storage->queue = CFRetain(target->queue);
            storage->texture = CFRetain((__bridge CFTypeRef)texture);
            storage->width = width; storage->height = height;
        }
        vox_metal_drop_owned(texture);
        if (storage && !vox_metal_depth_stencil_clear(storage, 1, 0)) { vox_metal_depth_stencil_destroy(storage); storage = NULL; }
        return storage;
    }
}
#endif
