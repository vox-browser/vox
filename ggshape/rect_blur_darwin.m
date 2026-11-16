// GPU sampling and pixel transfer; profile construction and geometry live in V.
#include "../platform/native_state.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdint.h>
#undef remainder
#undef fma
#if __has_feature(objc_arc)
#define VOX_RECT_RELEASE(value) ((void)0)
#else
#define VOX_RECT_RELEASE(value) [(value) release]
#endif
VOX_NATIVE_STATE id<MTLDevice> vox_rect_blur_device;
VOX_NATIVE_STATE id<MTLCommandQueue> vox_rect_blur_queue;
VOX_NATIVE_STATE id<MTLComputePipelineState> vox_rect_blur_pipeline;
static int vox_rect_blur_coverage(const uint8_t *profile,int length,float *pixels,
                                 int width,int height,const float *rect,float inverse,int fast) {
    if(!profile || !pixels || !rect || length<32 || length>2048 || width<=0 || height<=0 ||
       width>4096 || height>4096 || (int64_t)width*height>4*1024*1024)return 0;
    @autoreleasepool {
        if(!vox_rect_blur_pipeline) {
            vox_rect_blur_device=MTLCreateSystemDefaultDevice();
            vox_rect_blur_queue=[vox_rect_blur_device newCommandQueue];
            if(!vox_rect_blur_queue)return 0;
            NSString *source=@"#include <metal_stdlib>\nusing namespace metal;\n"
             @"kernel void coverage(texture2d<float,access::sample> profile [[texture(0)]],"
             @"texture2d<float,access::write> output [[texture(1)]],constant float4& rect [[buffer(0)]],"
             @"constant float& inverse [[buffer(1)]],constant int& fast [[buffer(2)]],uint2 p [[thread_position_in_grid]]) {"
             @"if(p.x>=output.get_width()||p.y>=output.get_height())return;"
             @"constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);"
             @"float2 coord=float2(p)+.5;float2 xy;"
             @"if(fast) {float2 pos=max(rect.xy-coord,coord-rect.zw);"
             @"xy=float2(profile.sample(s,float2(inverse*pos.x,.5)).r,profile.sample(s,float2(inverse*pos.y,.5)).r);}"
             @"else {float4 distances=float4(rect.xy-coord,coord-rect.zw);"
             @"xy=float2(1-profile.sample(s,float2(inverse*distances.x,.5)).r-profile.sample(s,float2(inverse*distances.z,.5)).r,"
             @"1-profile.sample(s,float2(inverse*distances.y,.5)).r-profile.sample(s,float2(inverse*distances.w,.5)).r);}"
             @"output.write(float4(xy.x*xy.y),p);}";
            NSError *error=nil;
            id<MTLLibrary> lib=[vox_rect_blur_device newLibraryWithSource:source options:nil error:&error];
            if(!lib){fprintf(stderr,"%s\n",error.description.UTF8String);return 0;}
            id<MTLFunction> function=[lib newFunctionWithName:@"coverage"];
            vox_rect_blur_pipeline=[vox_rect_blur_device newComputePipelineStateWithFunction:function error:&error];
            VOX_RECT_RELEASE(function);VOX_RECT_RELEASE(lib);
            if(!vox_rect_blur_pipeline)return 0;
        }
        MTLTextureDescriptor *d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm width:length height:1 mipmapped:NO];
        d.storageMode=MTLStorageModeShared;d.usage=MTLTextureUsageShaderRead;
        id<MTLTexture> input=[vox_rect_blur_device newTextureWithDescriptor:d];
        d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float width:width height:height mipmapped:NO];
        d.storageMode=MTLStorageModeShared;d.usage=MTLTextureUsageShaderWrite;
        id<MTLTexture> output=[vox_rect_blur_device newTextureWithDescriptor:d];
        if(!input || !output){VOX_RECT_RELEASE(input);VOX_RECT_RELEASE(output);return 0;}
        [input replaceRegion:MTLRegionMake2D(0,0,length,1) mipmapLevel:0 withBytes:profile bytesPerRow:length];
        id<MTLCommandBuffer> command=[vox_rect_blur_queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder=[command computeCommandEncoder];
        [encoder setComputePipelineState:vox_rect_blur_pipeline];
        [encoder setTexture:input atIndex:0];[encoder setTexture:output atIndex:1];
        [encoder setBytes:rect length:16 atIndex:0];[encoder setBytes:&inverse length:4 atIndex:1];[encoder setBytes:&fast length:4 atIndex:2];
        [encoder dispatchThreads:MTLSizeMake(width,height,1) threadsPerThreadgroup:MTLSizeMake(16,16,1)];
        [encoder endEncoding];[command commit];[command waitUntilCompleted];
        int success=command.status==MTLCommandBufferStatusCompleted;
        if(success)[output getBytes:pixels bytesPerRow:width*sizeof(float) fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
        VOX_RECT_RELEASE(input);VOX_RECT_RELEASE(output);return success;
    }
}
