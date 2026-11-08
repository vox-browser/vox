#ifndef VOX_NATIVE_SVG_MASK_PIXELS_H
#define VOX_NATIVE_SVG_MASK_PIXELS_H

#include <stddef.h>
#include <stdint.h>

// The source and destination belong to separate bitmap contexts. Keep the
// format decision outside the pixel loops so Clang can vectorize each mode.
// Preserve the existing integer luminance and premultiplied-white RGBA bytes.
static void native_convert_svg_mask_pixels(const uint8_t *restrict source,
    size_t source_stride, uint8_t *restrict mask, size_t mask_stride,
    size_t width, size_t height, int is_color, int is_luminance)
{
    if (width == 0 || height == 0) {
        return;
    }
    if (is_color && is_luminance) {
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
    } else if (is_color) {
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
    } else {
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
}

#endif
