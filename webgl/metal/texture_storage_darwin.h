#ifndef VOX_METAL_TEXTURE_STORAGE_H
#define VOX_METAL_TEXTURE_STORAGE_H
/* Included after VoxMetalTexture. Format numbers mirror TextureFormat in V. */
static MTLPixelFormat vox_metal_texture_format(unsigned format)
{
    switch (format) {
    case 0: return MTLPixelFormatRGBA8Unorm;
    case 1: return MTLPixelFormatR8Unorm;
    case 2: return MTLPixelFormatRG8Unorm;
    case 3: return MTLPixelFormatRGBA8Unorm_sRGB;
    case 4: return MTLPixelFormatR8Snorm;
    case 5: return MTLPixelFormatRG8Snorm;
    case 6: return MTLPixelFormatRGBA8Snorm;
    case 7: return MTLPixelFormatR16Float;
    case 8: return MTLPixelFormatRG16Float;
    case 9: return MTLPixelFormatRGBA16Float;
    case 10: return MTLPixelFormatR32Float;
    case 11: return MTLPixelFormatRG32Float;
    case 12: return MTLPixelFormatRGBA32Float;
    case 13: return MTLPixelFormatR8Sint;
    case 14: return MTLPixelFormatRG8Sint;
    case 15: return MTLPixelFormatRGBA8Sint;
    case 16: return MTLPixelFormatR8Uint;
    case 17: return MTLPixelFormatRG8Uint;
    case 18: return MTLPixelFormatRGBA8Uint;
    case 19: return MTLPixelFormatR16Sint;
    case 20: return MTLPixelFormatRG16Sint;
    case 21: return MTLPixelFormatRGBA16Sint;
    case 22: return MTLPixelFormatR16Uint;
    case 23: return MTLPixelFormatRG16Uint;
    case 24: return MTLPixelFormatRGBA16Uint;
    case 25: return MTLPixelFormatR32Sint;
    case 26: return MTLPixelFormatRG32Sint;
    case 27: return MTLPixelFormatRGBA32Sint;
    case 28: return MTLPixelFormatR32Uint;
    case 29: return MTLPixelFormatRG32Uint;
    case 30: return MTLPixelFormatRGBA32Uint;
    case 31: return MTLPixelFormatRGB10A2Unorm;
    case 32: return MTLPixelFormatRGB10A2Uint;
    case 33: return MTLPixelFormatRG11B10Float;
    case 34: return MTLPixelFormatRGB9E5Float;
    case 35: return MTLPixelFormatDepth16Unorm;
    case 36: return MTLPixelFormatDepth32Float;
    case 37: return MTLPixelFormatDepth32Float_Stencil8;
    case 38: return MTLPixelFormatStencil8;
    default: return MTLPixelFormatInvalid;
    }
}

static int vox_metal_texture_region(void* handle, unsigned level, unsigned slice,
    unsigned x, unsigned y, unsigned z, unsigned width, unsigned height, unsigned depth,
    unsigned pixel_size, void* bytes, uint64_t capacity, int upload)
{
    VoxMetalTexture* resource = handle;
    if (!resource || !resource->storage.texture || !pixel_size || pixel_size > 16 || !bytes) return 0;
    id<MTLTexture> texture = (__bridge id<MTLTexture>)resource->storage.texture;
    if (level >= texture.mipmapLevelCount || texture.sampleCount != 1 || texture.pixelFormat == MTLPixelFormatDepth32Float_Stencil8) return 0;
    NSUInteger w = MAX((NSUInteger)1, texture.width >> level), h = MAX((NSUInteger)1, texture.height >> level);
    NSUInteger d = texture.textureType == MTLTextureType3D ? MAX((NSUInteger)1, texture.depth >> level) : 1;
    NSUInteger slices = texture.textureType == MTLTextureTypeCube ? 6 : texture.arrayLength;
    if (slice >= slices || x > w || y > h || z > d || width > w-x || height > h-y || depth > d-z) return 0;
    uint64_t row = (uint64_t)width * pixel_size;
    if (!width || !height || !depth) return 1;
    if (row > SIZE_MAX / height || row * height > SIZE_MAX / depth || capacity < row*height*depth) return 0;
    NSUInteger pitch = (row + 255) & ~(NSUInteger)255;
    if (height > SIZE_MAX/pitch || depth > SIZE_MAX/(pitch*height)) return 0;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)resource->storage.device;
        NSUInteger total = pitch*height*depth;
        if (total > device.maxBufferLength) return 0;
        id<MTLBuffer> staging = [device newBufferWithLength:total options:MTLResourceStorageModeShared];
        if (!staging) return 0;
        memset(staging.contents,0,total);
        if (upload) for (unsigned layer=0; layer<depth; ++layer) for (unsigned line=0; line<height; ++line)
            memcpy((uint8_t*)staging.contents + (layer*height+line)*pitch,(uint8_t*)bytes + (layer*height+line)*row,row);
        id<MTLCommandBuffer> command = [(__bridge id<MTLCommandQueue>)resource->storage.queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder = [command blitCommandEncoder];
        int success = command && encoder;
        if (success) {
            if (upload) [encoder copyFromBuffer:staging sourceOffset:0 sourceBytesPerRow:pitch sourceBytesPerImage:pitch*height
                sourceSize:MTLSizeMake(width,height,depth) toTexture:texture destinationSlice:slice destinationLevel:level destinationOrigin:MTLOriginMake(x,y,z)];
            else [encoder copyFromTexture:texture sourceSlice:slice sourceLevel:level sourceOrigin:MTLOriginMake(x,y,z) sourceSize:MTLSizeMake(width,height,depth)
                toBuffer:staging destinationOffset:0 destinationBytesPerRow:pitch destinationBytesPerImage:pitch*height];
            [encoder endEncoding];[command commit];[command waitUntilCompleted];success=command.status==MTLCommandBufferStatusCompleted;
        }
        if (success && !upload) for (unsigned layer=0; layer<depth; ++layer) for (unsigned line=0; line<height; ++line)
            memcpy((uint8_t*)bytes + (layer*height+line)*row,(uint8_t*)staging.contents + (layer*height+line)*pitch,row);
        vox_metal_drop_owned(staging);
        return success;
    }
}

static void* vox_metal_texture_storage(void* owner, unsigned width, unsigned height, unsigned depth,
    unsigned kind, unsigned levels, unsigned format, unsigned pixel_size, unsigned samples)
{
    VoxMetalDrawingBuffer* context=owner;
    MTLPixelFormat pixel_format=vox_metal_texture_format(format);
    if (!context || !width || !height || !depth || width>16384 || height>16384 || depth>2048 || kind>3 || !levels || levels>15
        || pixel_format==MTLPixelFormatInvalid || !pixel_size || pixel_size>16 || !samples || (samples>1 && (kind || levels!=1))) return NULL;
    @autoreleasepool {
        id<MTLDevice> device=(__bridge id<MTLDevice>)context->device;
        if (![device supportsTextureSampleCount:samples]) return NULL;
        MTLTextureDescriptor* descriptor=[[MTLTextureDescriptor alloc] init];
        descriptor.pixelFormat=pixel_format;descriptor.width=width;descriptor.height=height;
        descriptor.depth=kind==3?depth:1;descriptor.arrayLength=kind==2?depth:1;descriptor.mipmapLevelCount=levels;
        descriptor.sampleCount=samples;descriptor.storageMode=MTLStorageModePrivate;
        descriptor.textureType=samples>1?MTLTextureType2DMultisample:kind==1?MTLTextureTypeCube:kind==2?MTLTextureType2DArray:kind==3?MTLTextureType3D:MTLTextureType2D;
        descriptor.usage=MTLTextureUsageShaderRead|MTLTextureUsagePixelFormatView;
        if (format!=34) descriptor.usage|=MTLTextureUsageRenderTarget;
        id<MTLTexture> texture=[device newTextureWithDescriptor:descriptor];
        vox_metal_drop_owned(descriptor);
        VoxMetalTexture* resource=texture?calloc(1,sizeof(*resource)):NULL;
        if (resource) {
            resource->storage.device=CFRetain(context->device);resource->storage.queue=CFRetain(context->queue);
            resource->storage.texture=CFRetain((__bridge CFTypeRef)texture);resource->storage.width=width;resource->storage.height=height;
        }
        vox_metal_drop_owned(texture);
        if (!resource) return NULL;
        int success=vox_metal_texture_sampler(resource,0,0,0,0);
        if (success && format>=35) {
            id<MTLTexture> depth_texture=(__bridge id<MTLTexture>)resource->storage.texture;
            for(unsigned level=0;success && level<levels;++level) for(unsigned slice=0;success && slice<(kind==1?6:kind==2?depth:1);++slice) {
                MTLRenderPassDescriptor* pass=[MTLRenderPassDescriptor renderPassDescriptor];
                if (format!=38) {
                    pass.depthAttachment.texture=depth_texture;pass.depthAttachment.level=level;pass.depthAttachment.slice=slice;
                    pass.depthAttachment.loadAction=MTLLoadActionClear;pass.depthAttachment.storeAction=MTLStoreActionStore;pass.depthAttachment.clearDepth=0;
                }
                if (format>=37) {
                    pass.stencilAttachment.texture=depth_texture;pass.stencilAttachment.level=level;pass.stencilAttachment.slice=slice;
                    pass.stencilAttachment.loadAction=MTLLoadActionClear;pass.stencilAttachment.storeAction=MTLStoreActionStore;pass.stencilAttachment.clearStencil=0;
                }
                id<MTLCommandBuffer> command=[(__bridge id<MTLCommandQueue>)context->queue commandBuffer];
                id<MTLRenderCommandEncoder> encoder=[command renderCommandEncoderWithDescriptor:pass];
                success=command && encoder;
                if (success) { [encoder endEncoding];[command commit];[command waitUntilCompleted];success=command.status==MTLCommandBufferStatusCompleted; }
            }
        }
        if (success && samples>1 && format<35) success=vox_metal_buffer_clear(resource,0,0,0,0);
        for (unsigned level=0;success && format<35 && samples==1 && level<levels;++level) {
            unsigned w=MAX(1u,width>>level),h=MAX(1u,height>>level),d=kind==3?MAX(1u,depth>>level):1;
            uint64_t size=(uint64_t)w*h*d*pixel_size;
            if (size>SIZE_MAX) { success=0;break; }
            void* zero=calloc(1,(size_t)size);
            if (!zero) { success=0;break; }
            unsigned slices=kind==1?6:kind==2?depth:1;
            for(unsigned slice=0;success && slice<slices;++slice) success=vox_metal_texture_region(resource,level,slice,0,0,0,w,h,d,pixel_size,zero,size,1);
            free(zero);
        }
        if (!success) { vox_metal_texture_destroy(resource);return NULL; }
        return resource;
    }
}

/* Views retain the parent texture. Level/slice selection belongs to the render
 * attachment; 3D depth planes cannot be represented by an ordinary 2D view. */
static void* vox_metal_texture_attachment(void* handle,unsigned level,unsigned slice)
{
    VoxMetalTexture* parent=handle;
    if (!parent || !parent->storage.texture) return NULL;
    id<MTLTexture> texture=(__bridge id<MTLTexture>)parent->storage.texture;
    unsigned depth=texture.textureType==MTLTextureType3D?MAX((NSUInteger)1,texture.depth>>level):texture.textureType==MTLTextureTypeCube?6:texture.arrayLength;
    if (level>=texture.mipmapLevelCount || slice>=depth) return NULL;
    VoxMetalTexture* view=calloc(1,sizeof(*view));
    if (!view) return NULL;
    view->storage=parent->storage;
    view->storage.device=CFRetain(parent->storage.device);view->storage.queue=CFRetain(parent->storage.queue);view->storage.texture=CFRetain(parent->storage.texture);
    view->storage.width=MAX(1,parent->storage.width>>level);view->storage.height=MAX(1,parent->storage.height>>level);
    view->storage.level=level;
    view->storage.slice=texture.textureType==MTLTextureType3D?0:slice;
    view->storage.plane=texture.textureType==MTLTextureType3D?slice:0;
    view->sampler=parent->sampler?CFRetain(parent->sampler):NULL;
    return view;
}

static int vox_metal_texture_mipmaps(void* handle)
{
    VoxMetalTexture* resource=handle;
    if (!resource || !resource->storage.texture) return 0;
    @autoreleasepool {
        id<MTLCommandBuffer> command=[(__bridge id<MTLCommandQueue>)resource->storage.queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder=[command blitCommandEncoder];
        if (!command || !encoder) return 0;
        [encoder generateMipmapsForTexture:(__bridge id<MTLTexture>)resource->storage.texture];
        [encoder endEncoding];[command commit];[command waitUntilCompleted];
        return command.status==MTLCommandBufferStatusCompleted;
    }
}
#endif
