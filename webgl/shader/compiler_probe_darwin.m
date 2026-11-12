// Test-only Metal endpoint for the portable V source generator.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <string.h>
int vox_direct_metal_probe(char const* vertex, char const* fragment) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return 0;
        NSError* error = nil;
        id<MTLLibrary> vs = [device newLibraryWithSource:[NSString stringWithUTF8String:vertex] options:nil error:&error];
        if (!vs) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 0; }
        id<MTLLibrary> fs = [device newLibraryWithSource:[NSString stringWithUTF8String:fragment] options:nil error:&error];
        if (!fs) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 0; }
        MTLRenderPipelineDescriptor* desc = [MTLRenderPipelineDescriptor new];
        desc.vertexFunction = [vs newFunctionWithName:@"vox_main"];
        desc.fragmentFunction = [fs newFunctionWithName:@"vox_main"];
        desc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:desc error:&error];
        if (!pipeline) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 0; }
        MTLTextureDescriptor* tex = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:4 height:4 mipmapped:NO];
        tex.usage = MTLTextureUsageRenderTarget;
        tex.storageMode = MTLStorageModeShared;
        id<MTLTexture> target = [device newTextureWithDescriptor:tex];
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = target;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        [encoder setRenderPipelineState:pipeline];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [command commit]; [command waitUntilCompleted];
        if (command.status != MTLCommandBufferStatusCompleted) return 0;
        unsigned char pixels[64];
        [target getBytes:pixels bytesPerRow:16 fromRegion:MTLRegionMake2D(0,0,4,4) mipmapLevel:0];
        for (unsigned i=0;i<64;i+=4) if(pixels[i]!=255 || pixels[i+1]!=0 || pixels[i+2]!=0 || pixels[i+3]!=255) return 0;
        for (uint32_t i=0;i<_dyld_image_count();++i) {
            char const* name=_dyld_get_image_name(i);
            if(strstr(name,"glslang") || strstr(name,"spirv-cross")) return 0;
        }
        return 1;
    }
}
