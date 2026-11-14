#ifndef VOX_METAL_DEPTH_TRANSFER_H
#define VOX_METAL_DEPTH_TRANSFER_H
/* Canonical combined pixels: float32 depth followed by uint32 stencil. */
static int vox_metal_depth_region(VoxMetalTexture* resource,unsigned level,unsigned slice,unsigned x,unsigned y,unsigned width,unsigned height,void* bytes,int upload)
{
    NSUInteger depth_pitch=((NSUInteger)width*4+255)&~(NSUInteger)255;
    NSUInteger stencil_pitch=((NSUInteger)width+255)&~(NSUInteger)255;
    if(height>SIZE_MAX/(depth_pitch+stencil_pitch)) return 0;
    NSUInteger depth_size=depth_pitch*height,total=depth_size+stencil_pitch*height;
    @autoreleasepool {
        id<MTLDevice> device=(__bridge id<MTLDevice>)resource->storage.device;
        if(total>device.maxBufferLength) return 0;
        id<MTLBuffer> staging=[device newBufferWithLength:total options:MTLResourceStorageModeShared];
        if(!staging) return 0;
        memset(staging.contents,0,total);
        if(upload) for(unsigned row=0;row<height;++row) for(unsigned column=0;column<width;++column) {
            uint8_t* pixel=(uint8_t*)bytes+(row*width+column)*8;
            memcpy((uint8_t*)staging.contents+row*depth_pitch+column*4,pixel,4);
            ((uint8_t*)staging.contents)[depth_size+row*stencil_pitch+column]=pixel[4];
        }
        id<MTLTexture> texture=(__bridge id<MTLTexture>)resource->storage.texture;
        id<MTLCommandBuffer> command=[(__bridge id<MTLCommandQueue>)resource->storage.queue commandBuffer];
        id<MTLBlitCommandEncoder> encoder=[command blitCommandEncoder];
        int success=command && encoder;
        if(success) {
            MTLSize size=MTLSizeMake(width,height,1);MTLOrigin origin=MTLOriginMake(x,y,0);
            if(upload) {
                [encoder copyFromBuffer:staging sourceOffset:0 sourceBytesPerRow:depth_pitch sourceBytesPerImage:depth_size sourceSize:size toTexture:texture destinationSlice:slice destinationLevel:level destinationOrigin:origin options:MTLBlitOptionDepthFromDepthStencil];
                [encoder copyFromBuffer:staging sourceOffset:depth_size sourceBytesPerRow:stencil_pitch sourceBytesPerImage:stencil_pitch*height sourceSize:size toTexture:texture destinationSlice:slice destinationLevel:level destinationOrigin:origin options:MTLBlitOptionStencilFromDepthStencil];
            } else {
                [encoder copyFromTexture:texture sourceSlice:slice sourceLevel:level sourceOrigin:origin sourceSize:size toBuffer:staging destinationOffset:0 destinationBytesPerRow:depth_pitch destinationBytesPerImage:depth_size options:MTLBlitOptionDepthFromDepthStencil];
                [encoder copyFromTexture:texture sourceSlice:slice sourceLevel:level sourceOrigin:origin sourceSize:size toBuffer:staging destinationOffset:depth_size destinationBytesPerRow:stencil_pitch destinationBytesPerImage:stencil_pitch*height options:MTLBlitOptionStencilFromDepthStencil];
            }
            [encoder endEncoding];[command commit];[command waitUntilCompleted];success=command.status==MTLCommandBufferStatusCompleted;
        }
        if(success && !upload) for(unsigned row=0;row<height;++row) for(unsigned column=0;column<width;++column) {
            uint8_t* pixel=(uint8_t*)bytes+(row*width+column)*8;
            memcpy(pixel,(uint8_t*)staging.contents+row*depth_pitch+column*4,4);
            memset(pixel+4,0,4);pixel[4]=((uint8_t*)staging.contents)[depth_size+row*stencil_pitch+column];
        }
        vox_metal_drop_owned(staging);return success;
    }
}
#endif
