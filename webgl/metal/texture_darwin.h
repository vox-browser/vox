#ifndef VOX_METAL_TEXTURE_H
#define VOX_METAL_TEXTURE_H
#include "drawing_buffer_darwin.h"
#include "sampler_darwin.h"
typedef struct { VoxMetalDrawingBuffer storage; CFTypeRef sampler; } VoxMetalTexture;

static int vox_metal_texture_sampler(void* handle, int min_filter, int mag_filter, int wrap_s, int wrap_t)
{
    VoxMetalTexture* texture = handle;
    if (!texture || min_filter < 0 || min_filter > 1 || mag_filter < 0 || mag_filter > 1 || wrap_s < 0 || wrap_s > 2 || wrap_t < 0 || wrap_t > 2) return 0;
    @autoreleasepool {
        MTLSamplerDescriptor* descriptor = [[MTLSamplerDescriptor alloc] init];
        descriptor.minFilter = min_filter ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
        descriptor.magFilter = mag_filter ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
        MTLSamplerAddressMode modes[] = {MTLSamplerAddressModeClampToEdge, MTLSamplerAddressModeRepeat, MTLSamplerAddressModeMirrorRepeat};
        descriptor.sAddressMode = modes[wrap_s]; descriptor.tAddressMode = modes[wrap_t];
        id<MTLSamplerState> sampler = [(__bridge id<MTLDevice>)texture->storage.device newSamplerStateWithDescriptor:descriptor];
        vox_metal_drop_owned(descriptor);
        if (!sampler) return 0;
        CFTypeRef previous = texture->sampler;
        texture->sampler = CFRetain((__bridge CFTypeRef)sampler);
        vox_metal_drop_owned(sampler);
        if (previous) CFRelease(previous);
        return 1;
    }
}

static int vox_metal_texture_set_sampler(void* texture_handle,void* sampler_handle)
{
    VoxMetalTexture* texture=texture_handle;
    VoxMetalSampler* sampler=sampler_handle;
    if (!texture || !sampler || texture->storage.device!=sampler->device) return 0;
    CFTypeRef previous=texture->sampler;
    texture->sampler=CFRetain(sampler->state);
    if (previous) CFRelease(previous);
    return 1;
}

static void vox_metal_texture_destroy(void* handle)
{
    VoxMetalTexture* texture = handle;
    if (!texture) return;
    if (texture->sampler) CFRelease(texture->sampler);
    vox_metal_buffer_destroy(&texture->storage);
}

static void* vox_metal_texture_create(void* owner, int width, int height)
{
    VoxMetalDrawingBuffer* context = owner;
    if (!context) return NULL;
    VoxMetalTexture* texture = calloc(1, sizeof(*texture));
    if (!texture) return NULL;
    texture->storage.device = CFRetain(context->device);
    texture->storage.queue = CFRetain(context->queue);
    if (!vox_metal_buffer_resize(&texture->storage, width, height) || !vox_metal_texture_sampler(texture, 0, 0, 0, 0)) {
        vox_metal_texture_destroy(texture); return NULL;
    }
    return texture;
}
#include "texture_storage_darwin.h"
#endif
