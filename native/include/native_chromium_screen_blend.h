#ifndef VOX_NATIVE_CHROMIUM_SCREEN_BLEND_H
#define VOX_NATIVE_CHROMIUM_SCREEN_BLEND_H

#include <math.h>
#include <stddef.h>
#include <stdint.h>

// Skia's screen coefficients are One and InverseSourceColor, including alpha.
// Apply group opacity before the fixed-function blend. Quartz transparency
// layers quantize that opacity and shift otherwise exact colors by one level.
static void native_composite_screen_pixels(const uint8_t *source,
    const uint8_t *backdrop, uint8_t *result, size_t count, float opacity)
{
#pragma clang fp contract(off)
    for (size_t index = 0; index < count; ++index) {
        for (int channel = 0; channel < 4; ++channel) {
            size_t offset = index * 4 + channel;
            float s = (float)source[offset] / 255.0f;
            s *= opacity;
            float d = (float)backdrop[offset] / 255.0f;
            double value = nearbyint((double)fmaf(d, 1.0f - s, s) * 255.0);
            result[offset] = value <= 0 ? 0 : value >= 255 ? 255 : (uint8_t)value;
        }
    }
}

#endif
