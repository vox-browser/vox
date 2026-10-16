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

typedef struct {
    float matrix[9];
    float source[4], destination[4], clip[4];
    float opacity;
    int width, height, pitch, flags, nearest;
    const uint8_t *pixels;
} VoxGraphiteImage;

typedef struct {
    float matrix[9], rect[12], thickness;
    uint8_t red, green, blue, alpha;
    int fill, anti_alias;
} VoxGraphiteShape;

#ifdef __cplusplus
extern "C" {
#endif
int vox_graphite_draw_shadow_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShadow *shadow);
int vox_graphite_draw_image_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteImage *image);
int vox_graphite_draw_shape_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShape *shape);
#ifdef __cplusplus
}
#endif

#endif
