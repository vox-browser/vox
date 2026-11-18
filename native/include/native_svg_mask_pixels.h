#ifndef VOX_NATIVE_SVG_MASK_PIXELS_H
#define VOX_NATIVE_SVG_MASK_PIXELS_H

#include <stddef.h>
#include <stdint.h>
#if defined(__aarch64__)
#include <arm_neon.h>
#endif
#include "../../cpuraster/scan_workers.h"

#if defined(__aarch64__)
static inline int native_svg_mask_can_vectorize_row(const uint8_t *source,
    const uint8_t *output, size_t width)
{
    uintptr_t input_address = (uintptr_t)source, output_address = (uintptr_t)output;
    // A forward overlap can change a later source pixel during the scalar loop.
    return output_address <= input_address || (output_address - input_address) / 4 >= width;
}
#endif

// Each mode reads a whole RGBA pixel before writing any channel. This also
// supports converting the same bitmap in place with matching strides.
static inline void native_convert_rgba_svg_mask_rows(const uint8_t *source,
    size_t source_stride, uint8_t *mask, size_t mask_stride,
    size_t width, size_t height, int is_luminance)
{
    if (width == 0 || height == 0) {
        return;
    }
    if (is_luminance) {
        for (size_t y = 0; y < height; ++y) {
            const uint8_t *row = source + y * source_stride;
            uint8_t *output = mask + y * mask_stride;
            size_t x = 0;
#if defined(__aarch64__) && defined(__ARM_FEATURE_DOTPROD) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
            if (native_svg_mask_can_vectorize_row(row, output, width)) {
                const uint8x16_t weights = vreinterpretq_u8_u32(vdupq_n_u32(54u | (183u << 8) | (19u << 16)));
                // Byte one of each sum is the truncating right shift by eight.
                const uint8x16_t select = {1, 1, 1, 1, 5, 5, 5, 5, 9, 9, 9, 9, 13, 13, 13, 13};
                for (; width - x >= 4; x += 4) {
                    uint32x4_t sums = vdotq_u32(vdupq_n_u32(0), vld1q_u8(row + x * 4), weights);
                    uint8x16_t coverage = vqtbl1q_u8(vreinterpretq_u8_u32(sums), select);
                    vst1q_u8(output + x * 4, coverage);
                }
            }
#endif
            for (; x < width; ++x) {
                uint8_t alpha = (uint8_t)((54u * row[x * 4]
                    + 183u * row[x * 4 + 1] + 19u * row[x * 4 + 2]) >> 8);
                output[x * 4] = alpha;
                output[x * 4 + 1] = alpha;
                output[x * 4 + 2] = alpha;
                output[x * 4 + 3] = alpha;
            }
        }
    } else {
        for (size_t y = 0; y < height; ++y) {
            const uint8_t *row = source + y * source_stride;
            uint8_t *output = mask + y * mask_stride;
            size_t x = 0;
#if defined(__aarch64__)
            if (native_svg_mask_can_vectorize_row(row, output, width)) {
                const uint8x16_t select = {3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15};
                for (; width - x >= 16; x += 16) {
                    uint8x16x4_t coverage = vld1q_u8_x4(row + x * 4);
                    for (size_t block = 0; block < 4; ++block) {
                        coverage.val[block] = vqtbl1q_u8(coverage.val[block], select);
                    }
                    vst1q_u8_x4(output + x * 4, coverage);
                }
            }
#endif
            for (; x < width; ++x) {
                uint8_t alpha = row[x * 4 + 3];
                output[x * 4] = alpha;
                output[x * 4 + 1] = alpha;
                output[x * 4 + 2] = alpha;
                output[x * 4 + 3] = alpha;
            }
        }
    }
}

// Quartz clip paths expand an alpha-only source into a separate bitmap.
static inline void native_expand_svg_alpha_rows(const uint8_t *source,
    size_t source_stride, uint8_t *restrict mask, size_t mask_stride,
    size_t width, size_t height)
{
    if (width == 0 || height == 0) {
        return;
    }
    for (size_t y = 0; y < height; ++y) {
        const uint8_t *row = source + y * source_stride;
        uint8_t *output = mask + y * mask_stride;
        for (size_t x = 0; x < width; ++x) {
            uint8_t alpha = row[x];
            output[x * 4] = alpha;
            output[x * 4 + 1] = alpha;
            output[x * 4 + 2] = alpha;
            output[x * 4 + 3] = alpha;
        }
    }
}

static inline void native_convert_svg_mask_rows(const uint8_t *source,
    size_t source_stride, uint8_t *mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    if (is_color) {
        native_convert_rgba_svg_mask_rows(source, source_stride, mask, mask_stride,
            width, height, is_luminance);
    } else {
        native_expand_svg_alpha_rows(source, source_stride, mask, mask_stride, width, height);
    }
}

typedef struct {
    const uint8_t *source;
    uint8_t *mask;
    size_t source_stride, mask_stride, width;
    int is_color, is_luminance;
} VoxSvgMaskConversion;

static void native_convert_svg_mask_range(void *context, int32_t first, int32_t end)
{
    const VoxSvgMaskConversion *job = (const VoxSvgMaskConversion *)context;
    native_convert_svg_mask_rows(job->source + (size_t)first * job->source_stride,
        job->source_stride, job->mask + (size_t)first * job->mask_stride, job->mask_stride,
        job->width, (size_t)(end - first), job->is_color, job->is_luminance);
}

static inline size_t native_svg_mask_conversion_lanes(const uint8_t *source, size_t source_stride,
    uint8_t *mask, size_t mask_stride, size_t width, size_t height, int is_color)
{
    if (height < 2 || height > INT32_MAX || width > SIZE_MAX / 4
        || mask_stride < width * 4 || mask_stride > SIZE_MAX / height
        || source_stride < width * (is_color ? 4 : 1) || source_stride > SIZE_MAX / height)
        return 1;
    size_t lanes = width * height / (512u * 1024u);
    if (lanes < 2 || vox_scan_workers_disabled()) return 1;

    // A matching RGBA bitmap is safe to update in place because rows are
    // disjoint. For any other overlap, the original serial order matters.
    if (!(is_color && source == mask && source_stride == mask_stride)) {
        uintptr_t input = (uintptr_t)source, output = (uintptr_t)mask;
        if (input <= output ? output - input < source_stride * height
                            : input - output < mask_stride * height)
            return 1;
    }
    if (lanes > VOX_SCAN_WORKERS_MAX) lanes = VOX_SCAN_WORKERS_MAX;
    return lanes < height ? lanes : height;
}

static inline void native_convert_svg_mask_pixels_scheduled(const uint8_t *source,
    size_t source_stride, uint8_t *mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    if (!width || !height) return;
    size_t lanes = native_svg_mask_conversion_lanes(source, source_stride, mask, mask_stride,
        width, height, is_color);
    if (lanes > 1) {
        // The caller owns the flushed bitmaps. Join before publishing a mask.
        VoxSvgMaskConversion job = {source, mask, source_stride, mask_stride,
            width, is_color, is_luminance};
        vox_scan_workers_run(&job, (int32_t)height, (int32_t)lanes, native_convert_svg_mask_range);
    } else {
        native_convert_svg_mask_rows(source, source_stride, mask, mask_stride,
            width, height, is_color, is_luminance);
    }
}

static inline void native_convert_rgba_svg_mask_pixels(const uint8_t *source,
    size_t source_stride, uint8_t *mask, size_t mask_stride,
    size_t width, size_t height, int is_luminance)
{
    native_convert_svg_mask_pixels_scheduled(source, source_stride, mask, mask_stride,
        width, height, 1, is_luminance);
}

static void native_convert_svg_mask_pixels(const uint8_t *restrict source,
    size_t source_stride, uint8_t *restrict mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    native_convert_svg_mask_pixels_scheduled(source, source_stride, mask, mask_stride,
        width, height, is_color, is_luminance);
}

#endif
