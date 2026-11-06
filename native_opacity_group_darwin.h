#ifndef VOX_NATIVE_OPACITY_GROUP_DARWIN_H
#define VOX_NATIVE_OPACITY_GROUP_DARWIN_H

#include <math.h>
#include <fenv.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "platform/native_state.h"

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
VOX_NATIVE_STATE int vox_unit_opacity_reported;
VOX_NATIVE_STATE int vox_byte_opacity_reported;
VOX_NATIVE_STATE int vox_byte_opacity_policy;

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

// Work in byte units when rounding is provably unambiguous. Both expressions
// use the same float32 remaining coverage. Replacing normalized RGB arithmetic
// and double scaling changes an unsaturated result by less than 2^-14 levels:
// normalization, source multiplication and the original FMA contribute at
// most 255*5*2^-25; byte-unit multiplication/FMA add at most 3*2^-17. Their
// sum is below 2^-14 (bytes, alpha in [0,1], output in [0,510]). Keep a 2^-10
// exclusion around every half level. Ambiguous blocks use the original path.
static int native_opacity_unambiguous_byte_block(uint8x8x4_t source,
    uint8x8x4_t destination, float32x4_t alpha, float32x4_t remaining_low,
    float32x4_t remaining_high, uint8x8x4_t *output)
{
#pragma clang fp contract(off)
    float32x4_t distance = vdupq_n_f32(0);
    for (int channel = 0; channel < 4; ++channel) {
        uint16x8_t s = vmovl_u8(source.val[channel]);
        uint16x8_t d = vmovl_u8(destination.val[channel]);
        float32x4_t low = vfmaq_f32(
            vmulq_f32(vcvtq_f32_u32(vmovl_u16(vget_low_u16(s))), alpha),
            vcvtq_f32_u32(vmovl_u16(vget_low_u16(d))), remaining_low);
        float32x4_t high = vfmaq_f32(
            vmulq_f32(vcvtq_f32_u32(vmovl_u16(vget_high_u16(s))), alpha),
            vcvtq_f32_u32(vmovl_u16(vget_high_u16(d))), remaining_high);
        float32x4_t rounded_low = vrndnq_f32(low), rounded_high = vrndnq_f32(high);
        distance = vmaxq_f32(distance, vmaxq_f32(vabsq_f32(vsubq_f32(low, rounded_low)),
            vabsq_f32(vsubq_f32(high, rounded_high))));
        output->val[channel] = vqmovn_u16(vcombine_u16(
            vqmovn_u32(vcvtq_u32_f32(rounded_low)),
            vqmovn_u32(vcvtq_u32_f32(rounded_high))));
    }
    return vmaxvq_f32(distance) < 0.5f - 0x1p-10f;
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
        const char *disabled = opacity == 1.0f ? getenv("VOX_DISABLE_UNIT_OPACITY_INTEGER") : NULL;
        int unit_opacity = opacity == 1.0f && (!disabled || !*disabled), used_unit = 0;
        // Half opacity produces frequent exact half-levels, especially for
        // opaque layers. Avoid unsuccessful byte-unit probes for this case.
        int byte_opacity = count >= 32 && opacity > 0 && opacity < 1 && opacity != 0.5f, used_byte = 0;
        if (byte_opacity) {
            // The diagnostic policy is process-start configuration. Cache it
            // so short raster rows do not repeatedly scan the environment.
            int policy = __atomic_load_n(&vox_byte_opacity_policy, __ATOMIC_RELAXED);
            if (!policy) {
                const char *retain_normalized = getenv("VOX_RETAIN_NORMALIZED_OPACITY_FLOAT");
                policy = retain_normalized && *retain_normalized ? -1 : 1;
                __atomic_store_n(&vox_byte_opacity_policy, policy, __ATOMIC_RELAXED);
            }
            byte_opacity = policy > 0;
        }
        size_t byte_attempts = 0, ambiguous_blocks = 0;
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
            if (unit_opacity) {
                // At unit opacity every byte is round(s + d*(255-a)/255).
                // Division by odd 255 has no half-level ties. Exhaustive byte
                // comparisons preserve the float32/FMA oracle's rounding,
                // including invalid premultiplication and saturated output.
                uint16x8_t remaining = vsubq_u16(vdupq_n_u16(255), vmovl_u8(source.val[3]));
                uint8x8x4_t output;
                for (int channel = 0; channel < 4; ++channel) {
                    uint16x8_t product = vmulq_u16(vmovl_u8(destination.val[channel]), remaining);
                    uint16x8_t biased = vaddq_u16(product, vdupq_n_u16(128));
                    uint8x8_t rounded = vshrn_n_u16(vaddq_u16(biased, vshrq_n_u16(biased, 8)), 8);
                    output.val[channel] = vqadd_u8(source.val[channel], rounded);
                }
                vst4_u8(result + index * 4, output);
                used_unit = 1;
                continue;
            }
            uint16x8_t coverage = vmovl_u8(source.val[3]);
            float32x4_t remaining_low = vsubq_f32(vdupq_n_f32(1.0f),
                vmulq_f32(native_opacity_normalize(vget_low_u16(coverage)), alpha));
            float32x4_t remaining_high = vsubq_f32(vdupq_n_f32(1.0f),
                vmulq_f32(native_opacity_normalize(vget_high_u16(coverage)), alpha));
            uint8x8x4_t output;
            if (byte_opacity) {
                ++byte_attempts;
                if (native_opacity_unambiguous_byte_block(source, destination, alpha,
                    remaining_low, remaining_high, &output)) {
                    vst4_u8(result + index * 4, output);
                    used_byte = 1;
                    continue;
                }
                // Repeated halfway results (for example opaque half-alpha
                // spans) should pay for at most a short unsuccessful probe.
                if (++ambiguous_blocks >= 2 && ambiguous_blocks * 3 > byte_attempts)
                    byte_opacity = 0;
            }
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
        if (used_unit) {
            if (!__atomic_exchange_n(&vox_unit_opacity_reported, 1, __ATOMIC_RELAXED)) {
                const char *diagnostics = getenv("VOX_UNIT_OPACITY_INTEGER_DIAGNOSTICS");
                if (diagnostics && *diagnostics)
                    fprintf(stderr, "Vox unit opacity integer: mixed-alpha span executed pixels=%zu\n", count);
            }
        }
        if (used_byte) {
            if (!__atomic_exchange_n(&vox_byte_opacity_reported, 1, __ATOMIC_RELAXED)) {
                const char *diagnostics = getenv("VOX_BYTE_OPACITY_DIAGNOSTICS");
                if (diagnostics && *diagnostics)
                    fprintf(stderr, "Vox byte opacity: unambiguous float span executed pixels=%zu\n", count);
            }
        }
    }
#endif
    native_composite_opacity_pixels_scalar(layer + index * 4, backdrop + index * 4,
        result + index * 4, count - index, opacity);
}

// The rows and columns of a premultiplied raster region that contain any
// painted pixel. Returns 0 when the region is empty.
VOX_NATIVE_STATE int vox_opacity_ink_rows_policy;
VOX_NATIVE_STATE int vox_opacity_ink_rows_reported;

static int native_opacity_trim_ink_rows(void)
{
    int policy = __atomic_load_n(&vox_opacity_ink_rows_policy, __ATOMIC_RELAXED);
    if (!policy) {
        const char *retain = getenv("VOX_RETAIN_FULL_OPACITY_INK_ROWS");
        policy = retain && *retain ? 2 : 1;
        __atomic_store_n(&vox_opacity_ink_rows_policy, policy, __ATOMIC_RELAXED);
    }
    return policy == 1;
}

static int native_opacity_row_has_ink(const uint32_t *row, int left, int right)
{
    int x = left;
#if defined(__aarch64__) && !defined(VOX_OPACITY_DISABLE_NEON)
    // Ink often starts at the edge; avoid loading a wide block in that case.
    if (right - x >= 4) {
        if (vmaxvq_u32(vld1q_u32(row + x)) != 0) return 1;
        x += 4;
    }
    for (; right - x >= 16; x += 16) {
        uint32x4x4_t block = vld1q_u32_x4(row + x);
        uint32x4_t ink = vorrq_u32(vorrq_u32(block.val[0], block.val[1]),
            vorrq_u32(block.val[2], block.val[3]));
        if (vmaxvq_u32(ink) != 0) return 1;
    }
    for (; right - x >= 4; x += 4)
        if (vmaxvq_u32(vld1q_u32(row + x)) != 0) return 1;
#endif
    for (; x < right; ++x) if (row[x]) return 1;
    return 0;
}

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
        // Once both horizontal limits are reached, no interior row can widen
        // them. Only the final nonempty row remains unknown. Search backwards
        // for it, retaining the same any-channel ink definition and crop.
        if (min_x == left && max_x == right && bottom - y > 2
            && native_opacity_trim_ink_rows()) {
            int tail = bottom - 1;
            for (; tail > y; --tail) {
                const uint32_t *tail_row = (const uint32_t *)(pixels + (size_t)tail * pitch);
                if (native_opacity_row_has_ink(tail_row, left, right)) break;
            }
            max_y = tail + 1;
            if (tail > y + 1
                && !__atomic_exchange_n(&vox_opacity_ink_rows_reported, 1, __ATOMIC_RELAXED)) {
                const char *diagnostics = getenv("VOX_OPACITY_INK_ROWS_DIAGNOSTICS");
                if (diagnostics && *diagnostics)
                    fprintf(stderr, "Vox opacity ink bounds: skipped resolved interior rows=%d\n", tail - y - 1);
            }
            break;
        }
    }
    if (!found) return 0;
    *ink_left = min_x;
    *ink_top = min_y;
    *ink_right = max_x;
    *ink_bottom = max_y;
    return 1;
}

#endif
