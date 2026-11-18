#ifndef VOX_NATIVE_SVG_MASK_PIXELS_H
#define VOX_NATIVE_SVG_MASK_PIXELS_H

#include <stddef.h>
#include <stdint.h>
#include "../../cpuraster/scan_workers.h"

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
            for (size_t x = 0; x < width; ++x) {
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
            for (size_t x = 0; x < width; ++x) {
                uint8_t alpha = row[x * 4 + 3];
                output[x * 4] = alpha;
                output[x * 4 + 1] = alpha;
                output[x * 4 + 2] = alpha;
                output[x * 4 + 3] = alpha;
            }
        }
    }
}

// Quartz clip paths can produce an alpha-only source in a separate bitmap.
static inline void native_convert_svg_mask_rows(const uint8_t *source,
    size_t source_stride, uint8_t *restrict mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    if (is_color) {
        native_convert_rgba_svg_mask_rows(source, source_stride, mask, mask_stride,
            width, height, is_luminance);
        return;
    }
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
