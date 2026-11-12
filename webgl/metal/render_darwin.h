#ifndef VOX_METAL_RENDER_H
#define VOX_METAL_RENDER_H
#include "gpu_buffer_darwin.h"
#include "shader_program_darwin.h"

typedef struct {
    void* buffer;
    uint64_t offset, stride;
    uint32_t location, components, divisor;
} VoxMetalVertexStream;
typedef struct { void* buffer; uint32_t stage, binding; uint64_t offset; } VoxMetalUniformBinding;

/* All GL validation/state is owned by V. This boundary only encodes a checked
 * draw description and reports Metal compilation/submission errors. */
static int vox_metal_draw(void* target_handle, void* program_handle,
    VoxMetalVertexStream const* streams, uint32_t stream_count,
    VoxMetalUniformBinding const* uniforms, uint32_t uniform_count,
    uint32_t primitive, uint32_t first, uint32_t count, uint32_t instances,
    char* log, uint64_t capacity)
{
    VoxMetalDrawingBuffer* target = target_handle;
    VoxMetalShaderProgram* program = program_handle;
    if (capacity) log[0] = 0;
    if (!target || !target->texture || !program || target->device != program->device || stream_count > 16 || primitive > 4) return 0;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)target->device;
        MTLVertexDescriptor* vertices = [MTLVertexDescriptor vertexDescriptor];
        for (uint32_t i = 0; i < stream_count; ++i) {
            VoxMetalVertexStream const* stream = streams + i;
            VoxMetalGPUBuffer* buffer = stream->buffer;
            if (!buffer || buffer->device != target->device || stream->location >= 16 || stream->components < 1 || stream->components > 4
                || stream->offset > buffer->size || stream->stride < stream->components * 4 || stream->stride > 2048) return 0;
            uint32_t slot = 15 + stream->location;
            vertices.attributes[stream->location].format = (MTLVertexFormat)(MTLVertexFormatFloat + stream->components - 1);
            vertices.attributes[stream->location].offset = 0;
            vertices.attributes[stream->location].bufferIndex = slot;
            vertices.layouts[slot].stride = stream->stride;
            vertices.layouts[slot].stepFunction = stream->divisor ? MTLVertexStepFunctionPerInstance : MTLVertexStepFunctionPerVertex;
            vertices.layouts[slot].stepRate = stream->divisor ?: 1;
        }
        for (uint32_t i = 0; i < uniform_count; ++i) {
            VoxMetalGPUBuffer* buffer = uniforms[i].buffer;
            if (!buffer || buffer->device != target->device || uniforms[i].binding >= 15 || uniforms[i].stage > 1 || uniforms[i].offset > buffer->size) return 0;
        }
        MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
        descriptor.vertexFunction = (__bridge id<MTLFunction>)program->vertex;
        descriptor.fragmentFunction = (__bridge id<MTLFunction>)program->fragment;
        descriptor.vertexDescriptor = vertices;
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
        NSError* error = nil;
        id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        vox_metal_drop_owned(descriptor);
        if (!pipeline) { if (capacity) snprintf(log, capacity, "%s", error.localizedDescription.UTF8String ?: "Metal pipeline compilation failed"); return 0; }
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = (__bridge id<MTLTexture>)target->texture;
        pass.colorAttachments[0].loadAction = MTLLoadActionLoad;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        id<MTLCommandBuffer> command = [(__bridge id<MTLCommandQueue>)target->queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        if (!command || !encoder) { vox_metal_drop_owned(pipeline); return 0; }
        [encoder setRenderPipelineState:pipeline];
        [encoder setViewport:(MTLViewport){0, 0, target->width, target->height, 0, 1}];
        for (uint32_t i = 0; i < stream_count; ++i) {
            VoxMetalGPUBuffer* buffer = streams[i].buffer;
            [encoder setVertexBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:streams[i].offset atIndex:15 + streams[i].location];
        }
        for (uint32_t i = 0; i < uniform_count; ++i) {
            VoxMetalGPUBuffer* buffer = uniforms[i].buffer;
            if (uniforms[i].stage)
                [encoder setFragmentBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:uniforms[i].offset atIndex:uniforms[i].binding];
            else [encoder setVertexBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:uniforms[i].offset atIndex:uniforms[i].binding];
        }
        [encoder drawPrimitives:(MTLPrimitiveType)primitive vertexStart:first vertexCount:count instanceCount:instances];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        int success = command.status == MTLCommandBufferStatusCompleted;
        if (!success && capacity) snprintf(log, capacity, "%s", command.error.localizedDescription.UTF8String ?: "Metal draw submission failed");
        vox_metal_drop_owned(pipeline);
        return success;
    }
}
#endif
