#ifndef VOX_NATIVE_OPACITY_GROUP_DARWIN_H
#define VOX_NATIVE_OPACITY_GROUP_DARWIN_H

#include <math.h>
#include <stddef.h>
#include <stdint.h>

// Chromium paints an opacity group into an 8-bit premultiplied layer, then
// draws that layer over the backdrop with the group alpha in float32 GPU
// arithmetic: result = backdrop * (1 - layer alpha * alpha) + layer * alpha,
// with the blend as one fused multiply-add, rounded to the nearest level.
// The float32 rounding decides values that lie halfway between levels. Core
// Graphics transparency layers round this composite differently, which
// shifts antialiased edges inside the group by one level.
static void native_composite_opacity_pixels(const uint8_t *layer, const uint8_t *backdrop,
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

// The rows and columns of a premultiplied raster region that contain any
// painted pixel. Returns 0 when the region is empty.
static int native_opacity_layer_ink_bounds(const uint8_t *pixels, size_t pitch, int left,
    int top, int right, int bottom, int *ink_left, int *ink_top, int *ink_right,
    int *ink_bottom)
{
    int found = 0, min_x = right, min_y = bottom, max_x = left, max_y = top;
    for (int y = top; y < bottom; ++y) {
        const uint32_t *row = (const uint32_t *)(pixels + (size_t)y * pitch);
        int first = -1, last = -1;
        for (int x = left; x < right; ++x) {
            if (row[x] == 0) continue;
            if (first < 0) first = x;
            last = x;
        }
        if (first < 0) continue;
        found = 1;
        if (first < min_x) min_x = first;
        if (last + 1 > max_x) max_x = last + 1;
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
