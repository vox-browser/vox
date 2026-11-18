#ifndef VOX_NATIVE_SVG_MASK_PIXELS_H
#define VOX_NATIVE_SVG_MASK_PIXELS_H

#include <stddef.h>
#include <stdint.h>

// Each mode reads a whole RGBA pixel before writing any channel. This also
// supports converting the same bitmap in place with matching strides.
static inline void native_convert_rgba_svg_mask_pixels(const uint8_t *source,
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

// Quartz clip paths produce an alpha-only source in a separate bitmap.
static void native_convert_svg_mask_pixels(const uint8_t *restrict source,
    size_t source_stride, uint8_t *restrict mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    if (is_color) {
        native_convert_rgba_svg_mask_pixels(source, source_stride, mask, mask_stride,
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

#endif
