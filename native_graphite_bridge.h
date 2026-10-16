#ifndef VOX_NATIVE_GRAPHITE_BRIDGE_H
#define VOX_NATIVE_GRAPHITE_BRIDGE_H

#include <stdint.h>

// Only pixels and plain values cross this boundary. The compatibility GPU
// backend owns its Skia objects independently of the translated engine's Skia.
typedef struct {
    float matrix[9];
    float shadow[12];
    float content[12];
    float blur;
    uint8_t red, green, blue, alpha;
} VoxGraphiteShadow;

#ifdef __cplusplus
extern "C" {
#endif
int vox_graphite_draw_shadow_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShadow *shadow);
#ifdef __cplusplus
}
#endif

#endif
