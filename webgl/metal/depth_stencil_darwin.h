#ifndef VOX_METAL_DEPTH_STENCIL_H
#define VOX_METAL_DEPTH_STENCIL_H
#include "drawing_buffer_darwin.h"
#include "texture_darwin.h"
typedef struct {
    CFTypeRef device,queue,texture;int width,height;
    CFTypeRef stencil;
    unsigned depth_level,depth_slice,depth_plane,stencil_level,stencil_slice,stencil_plane;
    unsigned has_depth,has_stencil;
} VoxMetalDepthStencil;

static void vox_metal_depth_stencil_pass(MTLRenderPassDescriptor* pass,VoxMetalDepthStencil* storage,int clear,double depth,uint32_t stencil)
{
    if(storage->has_depth) {
        pass.depthAttachment.texture=(__bridge id<MTLTexture>)storage->texture;
        pass.depthAttachment.level=storage->depth_level;pass.depthAttachment.slice=storage->depth_slice;pass.depthAttachment.depthPlane=storage->depth_plane;
        pass.depthAttachment.loadAction=clear?MTLLoadActionClear:MTLLoadActionLoad;pass.depthAttachment.storeAction=MTLStoreActionStore;pass.depthAttachment.clearDepth=depth;
    }
    if(storage->has_stencil) {
        pass.stencilAttachment.texture=(__bridge id<MTLTexture>)storage->stencil;
        pass.stencilAttachment.level=storage->stencil_level;pass.stencilAttachment.slice=storage->stencil_slice;pass.stencilAttachment.depthPlane=storage->stencil_plane;
        pass.stencilAttachment.loadAction=clear?MTLLoadActionClear:MTLLoadActionLoad;pass.stencilAttachment.storeAction=MTLStoreActionStore;pass.stencilAttachment.clearStencil=stencil;
    }
}

static int vox_metal_depth_stencil_clear(void* handle, double depth, uint32_t stencil)
{
    VoxMetalDepthStencil* storage = handle;
    if (!storage) return 0;
    @autoreleasepool {
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        vox_metal_depth_stencil_pass(pass,storage,1,depth,stencil);
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
    if (storage->stencil) CFRelease(storage->stencil);
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
            storage->stencil = CFRetain((__bridge CFTypeRef)texture);
            storage->has_depth=storage->has_stencil=1;
            storage->width = width; storage->height = height;
        }
        vox_metal_drop_owned(texture);
        if (storage && !vox_metal_depth_stencil_clear(storage, 1, 0)) { vox_metal_depth_stencil_destroy(storage); storage = NULL; }
        return storage;
    }
}
static void* vox_metal_depth_stencil_from_textures(void* depth_handle,void* stencil_handle)
{
    VoxMetalTexture* depth=depth_handle;VoxMetalTexture* stencil=stencil_handle;
    VoxMetalTexture* source=depth?:stencil;
    if(!source || !source->storage.texture || (depth && stencil && (depth->storage.device!=stencil->storage.device || depth->storage.width!=stencil->storage.width || depth->storage.height!=stencil->storage.height))) return NULL;
    VoxMetalDepthStencil* result=calloc(1,sizeof(*result));
    if(!result) return NULL;
    result->device=CFRetain(source->storage.device);result->queue=CFRetain(source->storage.queue);
    result->width=source->storage.width;result->height=source->storage.height;
    if(depth) {
        result->texture=CFRetain(depth->storage.texture);result->has_depth=1;
        result->depth_level=depth->storage.level;result->depth_slice=depth->storage.slice;result->depth_plane=depth->storage.plane;
    }
    if(stencil) {
        result->stencil=CFRetain(stencil->storage.texture);result->has_stencil=1;
        result->stencil_level=stencil->storage.level;result->stencil_slice=stencil->storage.slice;result->stencil_plane=stencil->storage.plane;
    }
    return result;
}
static void* vox_metal_depth_stencil_view(void* handle,int stencil,uint32_t* format)
{
    VoxMetalDepthStencil* source=handle;
    if(!source || (stencil?!source->has_stencil:!source->has_depth)) return NULL;
    CFTypeRef texture=stencil?source->stencil:source->texture;
    MTLPixelFormat pixel_format=[(__bridge id<MTLTexture>)texture pixelFormat];
    *format=pixel_format==MTLPixelFormatDepth16Unorm?35:pixel_format==MTLPixelFormatDepth32Float?36:pixel_format==MTLPixelFormatStencil8?38:37;
    VoxMetalTexture* result=calloc(1,sizeof(*result));
    if(!result) return NULL;
    result->storage.device=CFRetain(source->device);result->storage.queue=CFRetain(source->queue);result->storage.texture=CFRetain(texture);
    result->storage.width=source->width;result->storage.height=source->height;
    result->storage.level=stencil?source->stencil_level:source->depth_level;
    result->storage.slice=stencil?source->stencil_slice:source->depth_slice;
    result->storage.plane=stencil?source->stencil_plane:source->depth_plane;
    return result;
}
#endif
