#ifndef VOX_METAL_RENDER_H
#define VOX_METAL_RENDER_H
#include "gpu_buffer_darwin.h"
#include "shader_program_darwin.h"
#include "texture_darwin.h"
#include "sampler_darwin.h"
#include "render_state_darwin.h"
#include "vertex_formats_darwin.h"

typedef struct {
    void* buffer;
    uint64_t offset, stride;
    uint32_t location, components, divisor;
    uint32_t format, normalized, constant;
} VoxMetalVertexStream;
typedef struct { void* buffer; uint32_t stage, binding; uint64_t offset; } VoxMetalUniformBinding;
typedef struct { void* texture; uint32_t stage, binding, sampler_binding, sampled; void* sampler; } VoxMetalTextureBinding;

/* All GL validation/state is owned by V. This boundary only encodes a checked
 * draw description and reports Metal compilation/submission errors. */
static int vox_metal_draw_configured(void* target_handle, void* program_handle,
    VoxMetalVertexStream const* streams, uint32_t stream_count,
    VoxMetalUniformBinding const* uniforms, uint32_t uniform_count,
    VoxMetalTextureBinding const* textures, uint32_t texture_count,
    VoxMetalRenderState const* configured_state, void* index_handle, uint64_t index_offset, uint32_t index_width,
    uint32_t primitive, uint32_t first, uint32_t count, uint32_t instances,
    char* log, uint64_t capacity)
{
    VoxMetalDrawingBuffer* target = target_handle;
    VoxMetalShaderProgram* program = program_handle;
    if (capacity) log[0] = 0;
    if (!target || !target->texture || !program || target->device != program->device || stream_count > 16 || primitive > 4) return 0;
    VoxMetalRenderState defaults = vox_metal_default_render_state(target);
    VoxMetalRenderState const* state = configured_state ?: &defaults;
    VoxMetalDepthStencil* depth = state->depth_stencil;
    VoxMetalGPUBuffer* indices = index_handle;
    VoxMetalDrawingBuffer* colors[8]={0};
    if (state->colors_configured) for(unsigned i=0;i<8;++i) colors[i]=state->color_targets[i];
    else colors[0]=target;
    for(unsigned i=0;i<8;++i) if(colors[i] && (colors[i]->device!=target->device || !colors[i]->texture || colors[i]->width!=target->width || colors[i]->height!=target->height)) return 0;
    VoxMetalGPUBuffer* visibility=state->visibility_buffer;
    if(visibility && (visibility->device!=target->device || visibility->size<8)) return 0;
    if (depth && (depth->device != target->device || depth->width != target->width || depth->height != target->height)) return 0;
    if (indices && (indices->device != target->device || (index_width != 2 && index_width != 4)
        || index_offset % index_width || index_offset > indices->size || (uint64_t)count * index_width > indices->size - index_offset)) return 0;
    if (!state->feedback && (!state->scissor_width || !state->scissor_height || !state->width || !state->height)) return 1;
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)target->device;
        MTLVertexDescriptor* vertices = [MTLVertexDescriptor vertexDescriptor];
        for (uint32_t i = 0; i < stream_count; ++i) {
            VoxMetalVertexStream const* stream = streams + i;
            VoxMetalGPUBuffer* buffer = stream->buffer;
            unsigned scalar_size = vox_metal_vertex_scalar_size(stream->format);
            MTLVertexFormat format = vox_metal_vertex_format(stream->format, stream->components, stream->normalized);
            if (!buffer || buffer->device != target->device || stream->location >= 16 || stream->components < 1 || stream->components > 4
                || !scalar_size || format == MTLVertexFormatInvalid || stream->offset > buffer->size || stream->stride < stream->components * scalar_size || stream->stride > 2048) return 0;
            uint32_t slot = 15 + stream->location;
            vertices.attributes[stream->location].format = format;
            vertices.attributes[stream->location].offset = stream->offset % 4;
            vertices.attributes[stream->location].bufferIndex = slot;
            vertices.layouts[slot].stride = stream->stride;
            vertices.layouts[slot].stepFunction = stream->constant ? MTLVertexStepFunctionConstant : stream->divisor ? MTLVertexStepFunctionPerInstance : MTLVertexStepFunctionPerVertex;
            vertices.layouts[slot].stepRate = stream->constant ? 0 : stream->divisor ?: 1;
        }
        for (uint32_t i = 0; i < uniform_count; ++i) {
            VoxMetalGPUBuffer* buffer = uniforms[i].buffer;
            if (!buffer || buffer->device != target->device || uniforms[i].binding >= 15 || uniforms[i].stage > 1 || uniforms[i].offset > buffer->size) return 0;
        }
        for (uint32_t i = 0; i < texture_count; ++i) {
            VoxMetalTexture* texture = textures[i].texture;
            if (!texture || texture->storage.device != target->device || !texture->storage.texture || (!texture->sampler && !textures[i].sampler)
                || textures[i].stage > 1 || textures[i].binding >= 128 || (textures[i].sampled && textures[i].sampler_binding >= 16)
                ) return 0;
            for(unsigned c=0;c<8;++c) if(colors[c] && texture->storage.texture==colors[c]->texture) return 0;
        }
        MTLRenderPipelineDescriptor* descriptor = [[MTLRenderPipelineDescriptor alloc] init];
        descriptor.vertexFunction = (__bridge id<MTLFunction>)(state->feedback?program->feedback:program->vertex);
        descriptor.rasterizationEnabled=!state->feedback;
        descriptor.fragmentFunction = state->feedback?nil:(__bridge id<MTLFunction>)program->fragment;
        descriptor.vertexDescriptor = vertices;
        descriptor.rasterSampleCount=[(__bridge id<MTLTexture>)target->texture sampleCount];
        for(unsigned c=0;c<8;++c) {
            if(!colors[c]) continue;
            descriptor.colorAttachments[c].pixelFormat=[(__bridge id<MTLTexture>)colors[c]->texture pixelFormat];
        MTLRenderPipelineColorAttachmentDescriptor* color = descriptor.colorAttachments[c];
        color.writeMask = ((state->color_mask & 1) ? MTLColorWriteMaskRed : 0)
            | ((state->color_mask & 2) ? MTLColorWriteMaskGreen : 0)
            | ((state->color_mask & 4) ? MTLColorWriteMaskBlue : 0)
            | ((state->color_mask & 8) && !(state->rgb_only_mask & (1u<<c)) ? MTLColorWriteMaskAlpha : 0);
        color.blendingEnabled = state->blend;
        color.rgbBlendOperation = (MTLBlendOperation)state->rgb_operation;
        color.alphaBlendOperation = (MTLBlendOperation)state->alpha_operation;
        color.sourceRGBBlendFactor = vox_metal_blend_factor(state->source_rgb);
        color.destinationRGBBlendFactor = vox_metal_blend_factor(state->destination_rgb);
        color.sourceAlphaBlendFactor = vox_metal_blend_factor(state->source_alpha);
        color.destinationAlphaBlendFactor = vox_metal_blend_factor(state->destination_alpha);
        }
        if (depth && depth->has_depth) descriptor.depthAttachmentPixelFormat=[(__bridge id<MTLTexture>)depth->texture pixelFormat];
        if (depth && depth->has_stencil) descriptor.stencilAttachmentPixelFormat=[(__bridge id<MTLTexture>)depth->stencil pixelFormat];
        NSError* error = nil;
        id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
        vox_metal_drop_owned(descriptor);
        if (!pipeline) { if (capacity) snprintf(log, capacity, "%s", error.localizedDescription.UTF8String ?: "Metal pipeline compilation failed"); return 0; }
        if(state->feedback) {
            VoxMetalGPUBuffer* output=state->feedback_buffer;
            if(!output) { vox_metal_drop_owned(pipeline);return 1; }
            if(output->device!=target->device || (uint64_t)count*instances>output->size/program->feedback_stride) { vox_metal_drop_owned(pipeline);return 0; }
        }
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.renderTargetWidth=target->width;pass.renderTargetHeight=target->height;
        pass.defaultRasterSampleCount=[(__bridge id<MTLTexture>)target->texture sampleCount];
        for(unsigned c=0;c<8;++c) if(colors[c]) {
            pass.colorAttachments[c].texture=(__bridge id<MTLTexture>)colors[c]->texture;
            pass.colorAttachments[c].level=colors[c]->level;pass.colorAttachments[c].slice=colors[c]->slice;pass.colorAttachments[c].depthPlane=colors[c]->plane;
            pass.colorAttachments[c].loadAction=MTLLoadActionLoad;pass.colorAttachments[c].storeAction=MTLStoreActionStore;
        }
        if(visibility) pass.visibilityResultBuffer=(__bridge id<MTLBuffer>)visibility->buffer;
        if(depth) vox_metal_depth_stencil_pass(pass,depth,0,1,0);
        id<MTLCommandBuffer> command = [(__bridge id<MTLCommandQueue>)target->queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        if (!command || !encoder) { vox_metal_drop_owned(pipeline); return 0; }
        [encoder setRenderPipelineState:pipeline];
        if(visibility) [encoder setVisibilityResultMode:MTLVisibilityResultModeBoolean offset:0];
        [encoder setViewport:(MTLViewport){state->x, state->y, state->width, state->height, state->near_depth, state->far_depth}];
        [encoder setScissorRect:(MTLScissorRect){state->scissor_x, state->scissor_y, state->scissor_width, state->scissor_height}];
        [encoder setCullMode:(MTLCullMode)state->cull];
        /* The V shader compiler flips clip Y to preserve raw GL readback rows; reverse
         * Metal winding with it so culling, gl_FrontFacing and stencil agree. */
        [encoder setFrontFacingWinding:state->front_ccw ? MTLWindingClockwise : MTLWindingCounterClockwise];
        [encoder setBlendColorRed:state->blend_red green:state->blend_green blue:state->blend_blue alpha:state->blend_alpha];
        [encoder setDepthBias:state->depth_bias slopeScale:state->depth_slope clamp:0];
        if (depth) {
            MTLDepthStencilDescriptor* descriptor = [[MTLDepthStencilDescriptor alloc] init];
            descriptor.depthCompareFunction = depth->has_depth && state->depth_test ? (MTLCompareFunction)state->depth_compare : MTLCompareFunctionAlways;
            descriptor.depthWriteEnabled = depth->has_depth && state->depth_test && state->depth_write;
            if (depth->has_stencil && state->stencil_test) {
                MTLStencilDescriptor* front = vox_metal_stencil_descriptor(&state->front);
                MTLStencilDescriptor* back = vox_metal_stencil_descriptor(&state->back);
                descriptor.frontFaceStencil = front; descriptor.backFaceStencil = back;
                vox_metal_drop_owned(front); vox_metal_drop_owned(back);
            }
            id<MTLDepthStencilState> depth_state = [device newDepthStencilStateWithDescriptor:descriptor];
            vox_metal_drop_owned(descriptor);
            if (!depth_state) { [encoder endEncoding]; vox_metal_drop_owned(pipeline); return 0; }
            [encoder setDepthStencilState:depth_state];
            [encoder setStencilFrontReferenceValue:state->front.reference backReferenceValue:state->back.reference];
            vox_metal_drop_owned(depth_state);
        }
        for (uint32_t i = 0; i < stream_count; ++i) {
            VoxMetalGPUBuffer* buffer = streams[i].buffer;
            [encoder setVertexBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:streams[i].offset & ~(uint64_t)3 atIndex:15 + streams[i].location];
        }
        for (uint32_t i = 0; i < uniform_count; ++i) {
            VoxMetalGPUBuffer* buffer = uniforms[i].buffer;
            if (uniforms[i].stage)
                [encoder setFragmentBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:uniforms[i].offset atIndex:uniforms[i].binding];
            else [encoder setVertexBuffer:(__bridge id<MTLBuffer>)buffer->buffer offset:uniforms[i].offset atIndex:uniforms[i].binding];
        }
        for (uint32_t i = 0; i < texture_count; ++i) {
            VoxMetalTexture* texture = textures[i].texture;
            VoxMetalSampler* selected=textures[i].sampler;
            if (selected && selected->device!=target->device) { vox_metal_drop_owned(pipeline);return 0; }
            CFTypeRef sampler=selected?selected->state:texture->sampler;
            if (textures[i].stage) {
                [encoder setFragmentTexture:(__bridge id<MTLTexture>)texture->storage.texture atIndex:textures[i].binding];
                if (textures[i].sampled) [encoder setFragmentSamplerState:(__bridge id<MTLSamplerState>)sampler atIndex:textures[i].sampler_binding];
            } else {
                [encoder setVertexTexture:(__bridge id<MTLTexture>)texture->storage.texture atIndex:textures[i].binding];
                if (textures[i].sampled) [encoder setVertexSamplerState:(__bridge id<MTLSamplerState>)sampler atIndex:textures[i].sampler_binding];
            }
        }
        if(state->feedback) {
            VoxMetalGPUBuffer* output=state->feedback_buffer;
            uint32_t parameters[5]={count,instances,0,0,0};
            if(program->translated->direct_feedback_stride) {
                parameters[0]=first;parameters[1]=count;parameters[2]=0;parameters[3]=instances;
                uint64_t words=output->size/4;parameters[4]=words>UINT32_MAX?UINT32_MAX:(uint32_t)words;
            }
            [encoder setVertexBuffer:(__bridge id<MTLBuffer>)output->buffer offset:0 atIndex:13];
            [encoder setVertexBytes:parameters length:program->translated->direct_feedback_stride?sizeof(parameters):sizeof(uint32_t)*4 atIndex:14];
        }
        if (indices)
            [encoder drawIndexedPrimitives:(MTLPrimitiveType)primitive indexCount:count indexType:index_width == 2 ? MTLIndexTypeUInt16 : MTLIndexTypeUInt32
                indexBuffer:(__bridge id<MTLBuffer>)indices->buffer indexBufferOffset:index_offset instanceCount:instances];
        else [encoder drawPrimitives:(MTLPrimitiveType)primitive vertexStart:first vertexCount:count instanceCount:instances];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];
        int success = command.status == MTLCommandBufferStatusCompleted;
        if (!success && capacity) snprintf(log, capacity, "%s", command.error.localizedDescription.UTF8String ?: "Metal draw submission failed");
        vox_metal_drop_owned(pipeline);
        return success;
    }
}

static int vox_metal_draw_textured(void* target, void* program,
    VoxMetalVertexStream const* streams, uint32_t stream_count,
    VoxMetalUniformBinding const* uniforms, uint32_t uniform_count,
    VoxMetalTextureBinding const* textures, uint32_t texture_count,
    uint32_t primitive, uint32_t first, uint32_t count, uint32_t instances,
    char* log, uint64_t capacity)
{
    return vox_metal_draw_configured(target, program, streams, stream_count, uniforms, uniform_count,
        textures, texture_count, NULL, NULL, 0, 0, primitive, first, count, instances, log, capacity);
}

static int vox_metal_draw(void* target, void* program,
    VoxMetalVertexStream const* streams, uint32_t stream_count,
    VoxMetalUniformBinding const* uniforms, uint32_t uniform_count,
    uint32_t primitive, uint32_t first, uint32_t count, uint32_t instances,
    char* log, uint64_t capacity)
{
    return vox_metal_draw_textured(target, program, streams, stream_count, uniforms, uniform_count,
        NULL, 0, primitive, first, count, instances, log, capacity);
}
#endif
