// Test-only Metal endpoint for the portable V source generator.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <string.h>
static int vox_direct_metal_render_probe(char const* vertex, char const* fragment, void const* vertex_bytes, uint64_t vertex_length, void const* fragment_bytes, uint64_t fragment_length, int texture_kind, uint32_t rgba, uint32_t attribute_location, uint32_t attribute_rows, uint32_t attribute_columns, void const* attribute_bytes, uint64_t attribute_length) {
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
        if (attribute_columns) {
            if(attribute_rows < 1 || attribute_rows > 4 || attribute_columns > 4 || attribute_location + attribute_columns > 16 || !attribute_bytes || attribute_length < 16 * attribute_columns) return 0;
            MTLVertexDescriptor* layout = [MTLVertexDescriptor vertexDescriptor];
            MTLVertexFormat formats[4] = {MTLVertexFormatFloat,MTLVertexFormatFloat2,MTLVertexFormatFloat3,MTLVertexFormatFloat4};
            for(unsigned column=0; column<attribute_columns; ++column) {
                layout.attributes[attribute_location+column].format = formats[attribute_rows-1];
                layout.attributes[attribute_location+column].offset = column * 16;
                layout.attributes[attribute_location+column].bufferIndex = 1;
            }
            layout.layouts[1].stride = attribute_columns * 16;
            layout.layouts[1].stepFunction = MTLVertexStepFunctionConstant;
            layout.layouts[1].stepRate = 0;
            desc.vertexDescriptor = layout;
        }
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
        if (attribute_columns) [encoder setVertexBytes:attribute_bytes length:attribute_length atIndex:1];
        if (vertex_length) [encoder setVertexBytes:vertex_bytes length:vertex_length atIndex:0];
        if (fragment_length) [encoder setFragmentBytes:fragment_bytes length:fragment_length atIndex:0];
        if (texture_kind) {
            MTLTextureDescriptor* source_desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:YES];
            source_desc.storageMode = MTLStorageModeShared;
            source_desc.usage = MTLTextureUsageShaderRead;
            if (texture_kind == 2) source_desc.textureType = MTLTextureTypeCube;
            id<MTLTexture> source = [device newTextureWithDescriptor:source_desc];
            if (!source) return 0;
            for (unsigned face=0; face<(texture_kind==2?6u:1u); ++face) {
                unsigned char pixels[16];
                for(unsigned i=0;i<16;++i) pixels[i] = (rgba >> ((i%4)*8)) & 255;
                // A 2D sample must reach the first texel. The other texels
                // are green so projection/coordinate mistakes fail pixels.
                if(texture_kind==1) for(unsigned i=4;i<16;i+=4) { pixels[i]=0; pixels[i+1]=255; pixels[i+2]=0; pixels[i+3]=255; }
                // The +X cube face is supplied by the test; other faces are green.
                if(face) for(unsigned i=0;i<16;i+=4) { pixels[i]=0; pixels[i+1]=255; pixels[i+2]=0; pixels[i+3]=255; }
                if(texture_kind==2) [source replaceRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0 slice:face withBytes:pixels bytesPerRow:8 bytesPerImage:16];
                else [source replaceRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0 withBytes:pixels bytesPerRow:8];
                unsigned char mip[4]={0,255,0,255};
                if(texture_kind==2) [source replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:1 slice:face withBytes:mip bytesPerRow:4 bytesPerImage:4];
                else [source replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:1 withBytes:mip bytesPerRow:4];
            }
            MTLSamplerDescriptor* sampling = [MTLSamplerDescriptor new];
            sampling.minFilter = sampling.magFilter = MTLSamplerMinMagFilterNearest;
            sampling.mipFilter = MTLSamplerMipFilterNearest;
            sampling.sAddressMode = sampling.tAddressMode = sampling.rAddressMode = MTLSamplerAddressModeClampToEdge;
            id<MTLSamplerState> sampler_state = [device newSamplerStateWithDescriptor:sampling];
            [encoder setVertexTexture:source atIndex:0];
            [encoder setFragmentTexture:source atIndex:0];
            [encoder setVertexSamplerState:sampler_state atIndex:0];
            [encoder setFragmentSamplerState:sampler_state atIndex:0];
        }
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

int vox_direct_metal_uniform_probe(char const* vertex, char const* fragment, void const* vertex_bytes, uint64_t vertex_length, void const* fragment_bytes, uint64_t fragment_length) {
    return vox_direct_metal_render_probe(vertex, fragment, vertex_bytes, vertex_length, fragment_bytes, fragment_length, 0, 0, 0, 0, 0, NULL, 0);
}
int vox_direct_metal_texture_probe(char const* vertex, char const* fragment, int kind, uint32_t rgba) {
    return vox_direct_metal_render_probe(vertex, fragment, NULL, 0, NULL, 0, kind, rgba, 0, 0, 0, NULL, 0);
}

int vox_direct_metal_probe(char const* vertex, char const* fragment) {
    return vox_direct_metal_uniform_probe(vertex, fragment, NULL, 0, NULL, 0);
}

int vox_direct_metal_attribute_probe(char const* vertex, char const* fragment, uint32_t location, uint32_t rows, uint32_t columns, void const* bytes, uint64_t length) {
    return vox_direct_metal_render_probe(vertex, fragment, NULL, 0, NULL, 0, 0, 0, location, rows, columns, bytes, length);
}

int vox_direct_metal_feedback_probe(char const* source, uint32_t first, uint32_t count, uint32_t first_instance, uint32_t instances, uint32_t capacity, uint32_t* output, uint64_t output_words) {
    @autoreleasepool {
        if (!output || !count || !instances || count>16 || instances>16 || output_words==0 || output_words>16384) return 0;
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return 0;
        NSError* error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:[NSString stringWithUTF8String:source] options:nil error:&error];
        if(!library) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 0; }
        MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
        descriptor.vertexFunction = [library newFunctionWithName:@"vox_capture"];
        descriptor.rasterizationEnabled = NO;
        id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        if(!pipeline) { fprintf(stderr,"%s\n",error.localizedDescription.UTF8String); return 0; }
        id<MTLBuffer> buffer = [device newBufferWithBytes:output length:output_words*4 options:MTLResourceStorageModeShared];
        if(!buffer) return 0;
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.renderTargetWidth=1; pass.renderTargetHeight=1; pass.defaultRasterSampleCount=1;
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        [encoder setRenderPipelineState:pipeline];
        [encoder setVertexBuffer:buffer offset:0 atIndex:13];
        // Clamp the advertised capacity to the actual allocation. Tests can
        // provide a smaller capacity while retaining canary words after it.
        uint32_t parameters[5]={first,count,first_instance,instances,capacity<output_words?capacity:(uint32_t)output_words};
        [encoder setVertexBytes:parameters length:sizeof(parameters) atIndex:14];
        [encoder drawPrimitives:MTLPrimitiveTypePoint vertexStart:first vertexCount:count instanceCount:instances baseInstance:first_instance];
        [encoder endEncoding]; [command commit]; [command waitUntilCompleted];
        if(command.status!=MTLCommandBufferStatusCompleted) return 0;
        memcpy(output,buffer.contents,output_words*4);
        for(uint32_t i=0;i<_dyld_image_count();++i) { char const* name=_dyld_get_image_name(i); if(strstr(name,"glslang") || strstr(name,"spirv-cross")) return 0; }
        return 1;
    }
}

int vox_direct_metal_compile_probe(char const* source) {
    @autoreleasepool {
        id<MTLDevice> device=MTLCreateSystemDefaultDevice();
        if(!device) return 0;
        NSError* error=nil;
        id<MTLLibrary> library=[device newLibraryWithSource:[NSString stringWithUTF8String:source] options:nil error:&error];
        return library!=nil;
    }
}
