#ifndef VOX_METAL_RENDER_STATE_H
#define VOX_METAL_RENDER_STATE_H
#include "depth_stencil_darwin.h"
typedef struct {
    uint32_t compare, fail, depth_fail, pass, reference, read_mask, write_mask;
} VoxMetalStencilFace;
typedef struct {
    void* depth_stencil;
    double x, y, width, height, near_depth, far_depth;
    uint64_t scissor_x, scissor_y, scissor_width, scissor_height;
    uint32_t color_mask, blend, rgb_operation, alpha_operation;
    uint32_t source_rgb, destination_rgb, source_alpha, destination_alpha;
    float blend_red, blend_green, blend_blue, blend_alpha;
    uint32_t cull, front_ccw, depth_test, depth_write, depth_compare, stencil_test;
    float depth_bias, depth_slope;
    VoxMetalStencilFace front, back;
    void* color_targets[8];
    uint32_t colors_configured;
    void* visibility_buffer;
    uint32_t feedback;
    void* feedback_buffer;
} VoxMetalRenderState;

static VoxMetalRenderState vox_metal_default_render_state(VoxMetalDrawingBuffer* target)
{
    VoxMetalRenderState state = {0};
    state.width = target->width; state.height = target->height; state.far_depth = 1;
    state.scissor_width = target->width; state.scissor_height = target->height;
    state.color_mask = 15; state.source_rgb = state.source_alpha = 1;
    state.front_ccw = 1; state.depth_compare = MTLCompareFunctionLess; state.depth_write = 1;
    state.front.compare = state.back.compare = MTLCompareFunctionAlways;
    state.front.read_mask = state.back.read_mask = state.front.write_mask = state.back.write_mask = 255;
    return state;
}

static MTLBlendFactor vox_metal_blend_factor(uint32_t factor)
{
    MTLBlendFactor const factors[] = {MTLBlendFactorZero, MTLBlendFactorOne,
        MTLBlendFactorSourceColor, MTLBlendFactorOneMinusSourceColor,
        MTLBlendFactorSourceAlpha, MTLBlendFactorOneMinusSourceAlpha,
        MTLBlendFactorDestinationColor, MTLBlendFactorOneMinusDestinationColor,
        MTLBlendFactorDestinationAlpha, MTLBlendFactorOneMinusDestinationAlpha,
        MTLBlendFactorSourceAlphaSaturated, MTLBlendFactorBlendColor, MTLBlendFactorOneMinusBlendColor,
        MTLBlendFactorBlendAlpha, MTLBlendFactorOneMinusBlendAlpha};
    return factor < sizeof(factors)/sizeof(*factors) ? factors[factor] : MTLBlendFactorZero;
}

static MTLStencilDescriptor* vox_metal_stencil_descriptor(VoxMetalStencilFace const* face)
{
    MTLStencilDescriptor* descriptor = [[MTLStencilDescriptor alloc] init];
    descriptor.stencilCompareFunction = (MTLCompareFunction)face->compare;
    descriptor.stencilFailureOperation = (MTLStencilOperation)face->fail;
    descriptor.depthFailureOperation = (MTLStencilOperation)face->depth_fail;
    descriptor.depthStencilPassOperation = (MTLStencilOperation)face->pass;
    descriptor.readMask = face->read_mask; descriptor.writeMask = face->write_mask;
    return descriptor;
}
#endif
