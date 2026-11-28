// GPU sampling; profile construction and geometry live in V.
#include "../platform/native_state.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdint.h>
#undef remainder
#undef fma
VOX_NATIVE_STATE id<MTLCommandQueue> vox_rect_blur_queue;
VOX_NATIVE_STATE id<MTLComputePipelineState> vox_rect_blur_pipeline;

static void *vox_rect_blur_texture(const void *device_handle, const uint8_t *profile,
                                   int length, int width, int height, const float *rect,
                                   float inverse, int fast, const float *origin) {
    if (!device_handle || !profile || !rect || length < 32 || length > 2048 || width <= 0 ||
        height <= 0 || width > 4096 || height > 4096 || (int64_t)width * height > 4 * 1024 * 1024) {
        return NULL;
    }
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)device_handle;
        if (vox_rect_blur_queue.device != device || !vox_rect_blur_pipeline) {
            vox_rect_blur_pipeline = nil;
            vox_rect_blur_queue = [device newCommandQueue];
            if (!vox_rect_blur_queue) return NULL;
            NSString *source=@"#include <metal_stdlib>\nusing namespace metal;\n"
             @"kernel void coverage(texture2d<float,access::sample> profile [[texture(0)]],"
             @"texture2d<float,access::write> output [[texture(1)]],constant float4& rect [[buffer(0)]],"
             @"constant float& inverse [[buffer(1)]],constant int& fast [[buffer(2)]],"
             @"constant float2& origin [[buffer(3)]],uint2 p [[thread_position_in_grid]]) {"
             @"if(p.x>=output.get_width()||p.y>=output.get_height())return;"
             @"constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);"
             @"float2 coord=(float2(p)+origin)+.5;float2 xy;"
             @"if(fast) {float2 pos=max(rect.xy-coord,coord-rect.zw);"
             @"xy=float2(profile.sample(s,float2(inverse*pos.x,.5)).r,profile.sample(s,float2(inverse*pos.y,.5)).r);}"
             @"else {float4 distances=float4(rect.xy-coord,coord-rect.zw);"
             @"xy=float2(1-profile.sample(s,float2(inverse*distances.x,.5)).r-profile.sample(s,float2(inverse*distances.z,.5)).r,"
             @"1-profile.sample(s,float2(inverse*distances.y,.5)).r-profile.sample(s,float2(inverse*distances.w,.5)).r);}"
             @"output.write(float4(xy.x*xy.y),p);}";
            NSError *error = nil;
            id<MTLLibrary> lib = [device newLibraryWithSource:source options:nil error:&error];
            if (!lib) {
                fprintf(stderr, "%s\n", error.description.UTF8String);
                return NULL;
            }
            id<MTLFunction> function = [lib newFunctionWithName:@"coverage"];
            vox_rect_blur_pipeline = [device newComputePipelineStateWithFunction:function error:&error];
            if (!vox_rect_blur_pipeline) return NULL;
        }
        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                                                    width:length height:1 mipmapped:NO];
        d.storageMode = MTLStorageModeShared;
        d.usage = MTLTextureUsageShaderRead;
        id<MTLTexture> input = [device newTextureWithDescriptor:d];
        d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                                              width:width height:height mipmapped:NO];
        d.storageMode = MTLStorageModePrivate;
        d.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatView;
        id<MTLTexture> output = [device newTextureWithDescriptor:d];
        if (!input || !output) return NULL;
        [input replaceRegion:MTLRegionMake2D(0, 0, length, 1) mipmapLevel:0 withBytes:profile bytesPerRow:length];
        id<MTLCommandBuffer> command = [vox_rect_blur_queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        if (!encoder) return NULL;
        [encoder setComputePipelineState:vox_rect_blur_pipeline];
        [encoder setTexture:input atIndex:0];
        [encoder setTexture:output atIndex:1];
        [encoder setBytes:rect length:4 * sizeof(float) atIndex:0];
        [encoder setBytes:&inverse length:sizeof(inverse) atIndex:1];
        [encoder setBytes:&fast length:sizeof(fast) atIndex:2];
        [encoder setBytes:origin length:2 * sizeof(float) atIndex:3];
        [encoder dispatchThreads:MTLSizeMake(width, height, 1) threadsPerThreadgroup:MTLSizeMake(16, 16, 1)];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        id<MTLTexture> coverage = nil;
        if (command.status == MTLCommandBufferStatusCompleted) {
            // The paint shader expects the coverage value in every channel.
            // A view replicates red on sampling and shares the compute output's storage.
            MTLTextureSwizzleChannels swizzle = MTLTextureSwizzleChannelsMake(
                MTLTextureSwizzleRed, MTLTextureSwizzleRed, MTLTextureSwizzleRed, MTLTextureSwizzleRed);
            coverage = [output newTextureViewWithPixelFormat:MTLPixelFormatR32Float textureType:MTLTextureType2D
                                                      levels:NSMakeRange(0, 1) slices:NSMakeRange(0, 1) swizzle:swizzle];
        }
        return (__bridge_retained void *)coverage;
    }
}

static void vox_rect_blur_release_texture(void *texture) {
    (void)CFBridgingRelease(texture);
}
