#ifndef VOX_NATIVE_OPACITY_GROUP_DARWIN_H
#define VOX_NATIVE_OPACITY_GROUP_DARWIN_H

#include <math.h>
#include <fenv.h>
#include <stddef.h>
#include <stdint.h>

#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
#include <arm_neon.h>
#endif

// Chromium paints an opacity group into an 8-bit premultiplied layer, then
// draws that layer over the backdrop with the group alpha in float32 GPU
// arithmetic: result = backdrop * (1 - layer alpha * alpha) + layer * alpha,
// with the blend as one fused multiply-add, rounded to the nearest level.
// The float32 rounding decides values that lie halfway between levels. Core
// Graphics transparency layers round this composite differently, which
// shifts antialiased edges inside the group by one level.
static void native_composite_opacity_pixels_scalar(const uint8_t *layer, const uint8_t *backdrop,
    uint8_t *result, size_t count, float opacity)
{
#pragma clang fp contract(off)
    for (size_t index = 0; index < count; ++index) {
        const uint8_t *source = layer + index * 4;
        const uint8_t *destination = backdrop + index * 4;
        uint8_t *output = result + index * 4;
        float source_alpha = (float)source[3] / 255.0f;
        source_alpha *= opacity;
        float remaining = 1.0f - source_alpha;
        for (int channel = 0; channel < 4; ++channel) {
            float source_value = (float)source[channel] / 255.0f;
            source_value *= opacity;
            float destination_value = (float)destination[channel] / 255.0f;
            float value = fmaf(destination_value, remaining, source_value);
            double scaled = nearbyint((double)value * 255.0);
            output[channel] = scaled <= 0.0 ? 0 : scaled >= 255.0 ? 255 : (uint8_t)scaled;
        }
    }
}

#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
static float32x4_t native_opacity_normalize(uint16x4_t bytes)
{
    return vdivq_f32(vcvtq_f32_u32(vmovl_u16(bytes)), vdupq_n_f32(255.0f));
}

static uint32x4_t native_opacity_quantize(float32x4_t values)
{
    // Preserve the scalar compositor's double-precision scaling before its
    // ties-to-even rounding. Scaling in float32 changes halfway cases.
    uint64x2_t low = vcvtnq_u64_f64(vmulq_n_f64(vcvt_f64_f32(vget_low_f32(values)), 255.0));
    uint64x2_t high = vcvtnq_u64_f64(vmulq_n_f64(vcvt_f64_f32(vget_high_f32(values)), 255.0));
    return vminq_u32(vcombine_u32(vmovn_u64(low), vmovn_u64(high)), vdupq_n_u32(255));
}
#endif

static void native_composite_opacity_pixels(const uint8_t *layer, const uint8_t *backdrop,
    uint8_t *result, size_t count, float opacity)
{
#pragma clang fp contract(off)
    size_t index = 0;
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
    // The explicit vector conversion rounds to nearest. Other rounding modes
    // and out-of-range opacities retain the established scalar arithmetic.
    if (count >= 8 && opacity >= 0.0f && opacity <= 1.0f && fegetround() == FE_TONEAREST) {
        float32x4_t alpha = vdupq_n_f32(opacity);
        for (; count - index >= 8; index += 8) {
            uint8x8x4_t source = vld4_u8(layer + index * 4);
            uint8x8x4_t destination = vld4_u8(backdrop + index * 4);
            // Empty spans are common between glyphs inside an opacity layer.
            // Check all channels, including otherwise invalid RGB at alpha 0.
            uint8x8_t ink = vorr_u8(vorr_u8(source.val[0], source.val[1]),
                vorr_u8(source.val[2], source.val[3]));
            if (opacity == 0.0f || vmaxv_u8(ink) == 0) {
                vst4_u8(result + index * 4, destination);
                continue;
            }
            if (opacity == 1.0f && vminv_u8(source.val[3]) == 255) {
                vst4_u8(result + index * 4, source);
                continue;
            }
            uint16x8_t coverage = vmovl_u8(source.val[3]);
            float32x4_t remaining_low = vsubq_f32(vdupq_n_f32(1.0f),
                vmulq_f32(native_opacity_normalize(vget_low_u16(coverage)), alpha));
            float32x4_t remaining_high = vsubq_f32(vdupq_n_f32(1.0f),
                vmulq_f32(native_opacity_normalize(vget_high_u16(coverage)), alpha));
            uint8x8x4_t output;
            for (int channel = 0; channel < 4; ++channel) {
                uint16x8_t s = vmovl_u8(source.val[channel]);
                uint16x8_t d = vmovl_u8(destination.val[channel]);
                float32x4_t low = vfmaq_f32(
                    vmulq_f32(native_opacity_normalize(vget_low_u16(s)), alpha),
                    native_opacity_normalize(vget_low_u16(d)), remaining_low);
                float32x4_t high = vfmaq_f32(
                    vmulq_f32(native_opacity_normalize(vget_high_u16(s)), alpha),
                    native_opacity_normalize(vget_high_u16(d)), remaining_high);
                output.val[channel] = vmovn_u16(vcombine_u16(
                    vmovn_u32(native_opacity_quantize(low)), vmovn_u32(native_opacity_quantize(high))));
            }
            vst4_u8(result + index * 4, output);
        }
    }
#endif
    native_composite_opacity_pixels_scalar(layer + index * 4, backdrop + index * 4,
        result + index * 4, count - index, opacity);
}

// The rows and columns of a premultiplied raster region that contain any
// painted pixel. Returns 0 when the region is empty.
static int native_opacity_layer_ink_bounds(const uint8_t *pixels, size_t pitch, int left,
    int top, int right, int bottom, int *ink_left, int *ink_top, int *ink_right,
    int *ink_bottom)
{
    int found = 0, min_x = right, min_y = bottom, max_x = left, max_y = top;
    for (int y = top; y < bottom; ++y) {
        const uint32_t *row = (const uint32_t *)(pixels + (size_t)y * pitch);
        // Only the first and last painted pixels affect the bounds. Skip
        // empty blocks at either end without walking the painted interior.
        int first = left, last = right;
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
        // Keep the single-vector path for ink at the edge. Only an empty
        // first vector qualifies the margin for wider, single-reduction scans.
        if (right - first >= 4 && vmaxvq_u32(vld1q_u32(row + first)) == 0) {
            first += 4;
            while (right - first >= 16) {
                uint32x4x4_t block = vld1q_u32_x4(row + first);
                uint32x4_t ink = vorrq_u32(vorrq_u32(block.val[0], block.val[1]),
                    vorrq_u32(block.val[2], block.val[3]));
                if (vmaxvq_u32(ink) != 0) break;
                first += 16;
            }
            while (right - first >= 4 && vmaxvq_u32(vld1q_u32(row + first)) == 0) first += 4;
        }
#endif
        while (first < right && row[first] == 0) ++first;
        if (first == right) continue;
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
        if (last - first >= 4 && vmaxvq_u32(vld1q_u32(row + last - 4)) == 0) {
            last -= 4;
            while (last - first >= 16) {
                uint32x4x4_t block = vld1q_u32_x4(row + last - 16);
                uint32x4_t ink = vorrq_u32(vorrq_u32(block.val[0], block.val[1]),
                    vorrq_u32(block.val[2], block.val[3]));
                if (vmaxvq_u32(ink) != 0) break;
                last -= 16;
            }
            while (last - first >= 4 && vmaxvq_u32(vld1q_u32(row + last - 4)) == 0) last -= 4;
        }
#endif
        while (row[last - 1] == 0) --last;
        found = 1;
        if (first < min_x) min_x = first;
        if (last > max_x) max_x = last;
        if (y < min_y) min_y = y;
        max_y = y + 1;
    }
    if (!found) return 0;
    *ink_left = min_x;
    *ink_top = min_y;
    *ink_right = max_x;
    *ink_bottom = max_y;
    return 1;
}

#endif
