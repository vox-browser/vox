/* Direct Metal resources for the WebGL backend migration. No EGL/GLES calls. */
#ifndef VOX_WEBGL_METAL_DRAWING_BUFFER_H
#define VOX_WEBGL_METAL_DRAWING_BUFFER_H
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    CFTypeRef device, queue, texture;
    int width, height;
    unsigned level, slice, plane;
} VoxMetalDrawingBuffer;

static void vox_metal_drop_owned(id value)
{
#if !__has_feature(objc_arc)
    [value release];
#else
    (void)value;
#endif
}

static void* vox_metal_buffer_create(void)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        id<MTLCommandQueue> queue = [device newCommandQueue];
        VoxMetalDrawingBuffer* result = device && queue ? calloc(1, sizeof(*result)) : NULL;
        if (result) {
            result->device = CFRetain((__bridge CFTypeRef)device);
            result->queue = CFRetain((__bridge CFTypeRef)queue);
        }
        vox_metal_drop_owned(queue);
        vox_metal_drop_owned(device);
        return result;
    }
}

static void vox_metal_buffer_destroy(void* handle)
{
    VoxMetalDrawingBuffer* context = handle;
    if (!context) return;
    if (context->texture) CFRelease(context->texture);
    CFRelease(context->queue);
    CFRelease(context->device);
    free(context);
}

static int vox_metal_clear_texture(VoxMetalDrawingBuffer* context, id<MTLTexture> texture,
                                  double r, double g, double b, double a)
{
    id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)context->queue;
    id<MTLCommandBuffer> command = [queue commandBuffer];
    MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = texture;
    pass.colorAttachments[0].level = context->level;
    pass.colorAttachments[0].slice = context->slice;
    pass.colorAttachments[0].depthPlane = context->plane;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, a);
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    if (!command || !encoder) return 0;
    [encoder endEncoding];
    [command commit];
    [command waitUntilCompleted];
    return command.status == MTLCommandBufferStatusCompleted;
}

static int vox_metal_buffer_resize(void* handle, int width, int height)
{
    VoxMetalDrawingBuffer* context = handle;
    if (!context || width <= 0 || height <= 0 || width > 16384 || height > 16384) return 0;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)context->device;
        MTLTextureDescriptor* descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
            width:(NSUInteger)width height:(NSUInteger)height mipmapped:NO];
        descriptor.storageMode = MTLStorageModePrivate;
        descriptor.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
        id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
        int success = texture && vox_metal_clear_texture(context, texture, 0, 0, 0, 0);
        if (success) {
            CFTypeRef previous = context->texture;
            context->texture = CFRetain((__bridge CFTypeRef)texture);
            context->width = width;
            context->height = height;
            if (previous) CFRelease(previous);
        }
        vox_metal_drop_owned(texture);
        return success;
    }
}

static int vox_metal_buffer_clear(void* handle, double r, double g, double b, double a)
{
    VoxMetalDrawingBuffer* context = handle;
    if (!context || !context->texture) return 0;
    @autoreleasepool {
        return vox_metal_clear_texture(context, (__bridge id<MTLTexture>)context->texture, r, g, b, a);
    }
}

/* Shared staging buffers keep CPU access off the private render target. Every
 * copy waits for its command to complete before the CPU or caller can use it.
 * Rows use Metal's top-left origin and tightly packed RGBA at the V boundary. */
static int vox_metal_buffer_transfer(void* handle, void* pixels, uint64_t capacity, int upload)
{
    VoxMetalDrawingBuffer* context = handle;
    if (!context || !context->texture || !pixels) return 0;
    size_t row = (size_t)context->width * 4;
    size_t pitch = (row + 255) & ~(size_t)255;
    size_t height = (size_t)context->height;
    if (capacity < row * height || height > SIZE_MAX / pitch) return 0;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)context->device;
        if (pitch * height > device.maxBufferLength) return 0;
        id<MTLBuffer> staging = [device newBufferWithLength:pitch * height options:MTLResourceStorageModeShared];
        if (!staging) return 0;
        if (upload) {
            memset(staging.contents, 0, pitch * height);
            for (size_t y = 0; y < height; ++y)
                memcpy((uint8_t*)staging.contents + y * pitch, (uint8_t*)pixels + y * row, row);
        }
        id<MTLCommandQueue> queue = (__bridge id<MTLCommandQueue>)context->queue;
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
        int success = command && encoder;
        if (success) {
            id<MTLTexture> texture = (__bridge id<MTLTexture>)context->texture;
            MTLSize size = MTLSizeMake(context->width, context->height, 1);
            MTLOrigin origin = MTLOriginMake(0, 0, context->plane);
            if (upload)
                [encoder copyFromBuffer:staging sourceOffset:0 sourceBytesPerRow:pitch
                    sourceBytesPerImage:pitch * height sourceSize:size toTexture:texture
                    destinationSlice:context->slice destinationLevel:context->level destinationOrigin:origin];
            else
                [encoder copyFromTexture:texture sourceSlice:context->slice sourceLevel:context->level sourceOrigin:origin
                    sourceSize:size toBuffer:staging destinationOffset:0 destinationBytesPerRow:pitch
                    destinationBytesPerImage:pitch * height];
            [encoder endEncoding];
            [command commit];
            [command waitUntilCompleted];
            success = command.status == MTLCommandBufferStatusCompleted;
        }
        if (success && !upload)
            for (size_t y = 0; y < height; ++y)
                memcpy((uint8_t*)pixels + y * row, (uint8_t*)staging.contents + y * pitch, row);
        vox_metal_drop_owned(staging);
        return success;
    }
}
#endif
