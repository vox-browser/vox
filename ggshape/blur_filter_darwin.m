// Metal pixel transfers and filtering; geometry, kernels and filter bounds are
// owned by V.
#include "../platform/native_state.h"
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdint.h>
// Cocoa imports type-generic macros before V's C math declarations.
#undef remainder
#undef fma
#if __has_feature(objc_arc)
#define VOX_SHADOW_RELEASE(value) ((void)0)
#else
#define VOX_SHADOW_RELEASE(value) [(value) release]
#endif
VOX_NATIVE_STATE id<MTLDevice> vox_shadow_device;
VOX_NATIVE_STATE id<MTLCommandQueue> vox_shadow_queue;
VOX_NATIVE_STATE id<MTLComputePipelineState> vox_shadow_pipeline;
static int vox_shadow_filter_pass(uint8_t *src, int sw, int sh, uint8_t *dst,
                                  int dw, int dh, float *mapping, float *pairs,
                                  int count, int direction) {
  if (!src || !dst || sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0 || sw > 16384 ||
      sh > 16384 || dw > 16384 || dh > 16384 || count < 0 || count > 28)
    return 0;
  @autoreleasepool {
    if (!vox_shadow_pipeline) {
      if (!vox_shadow_device) {
        vox_shadow_device = MTLCreateSystemDefaultDevice();
        vox_shadow_queue = [vox_shadow_device newCommandQueue];
      }
      if (!vox_shadow_device || !vox_shadow_queue)
        return 0;
      NSString *source =
          @"#include <metal_stdlib>\nusing namespace metal;\nkernel void "
          @"filter(texture2d<float,access::sample> src "
          @"[[texture(0)]],texture2d<float,access::write> dst "
          @"[[texture(1)]],constant float4& m [[buffer(0)]],constant float2* "
          @"weights [[buffer(1)]],constant int2& info [[buffer(2)]],uint2 p "
          @"[[thread_position_in_grid]]) "
          @"{if(p.x>=dst.get_width()||p.y>=dst.get_height()) return; constexpr "
          @"sampler s(coord::pixel,address::clamp_to_zero,filter::linear); "
          @"float2 coord=(float2(p)+.5)*m.xy+m.zw; float4 sum=float4(0); "
          @"if(info.x==0) sum=src.sample(s,coord); else {for(int "
          @"i=0;i<info.x;i++) {float2 tap=float2(weights[i]); float2 "
          @"dir=info.y==0?float2(1,0):float2(0,1); "
          @"sum+=tap.y*src.sample(s,coord+float2(tap.x*dir));}} "
          @"dst.write(sum,p);}";
      NSError *error = nil;
      id<MTLLibrary> lib = [vox_shadow_device newLibraryWithSource:source
                                                           options:nil
                                                             error:&error];
      if (!lib) {
        fprintf(stderr, "%s\n", error.description.UTF8String);
        return 0;
      }
      id<MTLFunction> function = [lib newFunctionWithName:@"filter"];
      vox_shadow_pipeline =
          [vox_shadow_device newComputePipelineStateWithFunction:function
                                                           error:&error];
      VOX_SHADOW_RELEASE(function);
      VOX_SHADOW_RELEASE(lib);
      if (!vox_shadow_pipeline)
        return 0;
    }
    MTLTextureDescriptor *sd = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                     width:sw
                                    height:sh
                                 mipmapped:NO];
    sd.usage = MTLTextureUsageShaderRead;
    sd.storageMode = MTLStorageModeShared;
    id<MTLTexture> input = [vox_shadow_device newTextureWithDescriptor:sd];
    [input replaceRegion:MTLRegionMake2D(0, 0, sw, sh)
             mipmapLevel:0
               withBytes:src
             bytesPerRow:sw];
    MTLTextureDescriptor *dd = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                     width:dw
                                    height:dh
                                 mipmapped:NO];
    dd.usage = MTLTextureUsageShaderWrite;
    dd.storageMode = MTLStorageModeShared;
    id<MTLTexture> output = [vox_shadow_device newTextureWithDescriptor:dd];
    id<MTLCommandBuffer> command = [vox_shadow_queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [command computeCommandEncoder];
    [enc setComputePipelineState:vox_shadow_pipeline];
    [enc setTexture:input atIndex:0];
    [enc setTexture:output atIndex:1];
    [enc setBytes:mapping length:16 atIndex:0];
    [enc setBytes:pairs length:28 * 8 atIndex:1];
    int info[2] = {count, direction};
    [enc setBytes:info length:8 atIndex:2];
    [enc dispatchThreads:MTLSizeMake(dw, dh, 1)
        threadsPerThreadgroup:MTLSizeMake(16, 16, 1)];
    [enc endEncoding];
    [command commit];
    [command waitUntilCompleted];
    if (command.status != MTLCommandBufferStatusCompleted) {
      VOX_SHADOW_RELEASE(input);
      VOX_SHADOW_RELEASE(output);
      return 0;
    }
    [output getBytes:dst
         bytesPerRow:dw
          fromRegion:MTLRegionMake2D(0, 0, dw, dh)
         mipmapLevel:0];
    VOX_SHADOW_RELEASE(input);
    VOX_SHADOW_RELEASE(output);
    return 1;
  }
}
