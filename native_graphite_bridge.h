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
    float source[4], destination[4], clip[12];
    float opacity;
    int width, height, pitch, flags, nearest;
    const uint8_t *pixels;
    // A PNG gAMA/cHRM profile: inverse gamma, whether primaries follow, then
    // red, green, blue and white chromaticities. Untagged images are sRGB.
    int has_color_profile;
    float color_profile[10];
} VoxGraphiteImage;

typedef struct {
    float matrix[9], rect[12], thickness;
    uint8_t red, green, blue, alpha;
    int fill, anti_alias;
    // Multisample the render pass, as Chromium does for a raster tile once any
    // draw in it needs MSAA.
    int force_msaa;
    // Rectangles clipped out without antialiasing, as left, top, right and
    // bottom in the shape's local coordinates.
    const float *clip_outs;
    int clip_out_count;
    // A filled, anti-aliased rounded rectangle drawn first in the same render
    // pass, as Chromium draws consecutive shapes into one raster tile: x, y,
    // width, height and four corner radius pairs, then its RGBA color.
    int has_underlay;
    float underlay_rect[12];
    uint8_t underlay_rgba[4];
    int has_float_color;
    float float_color[4];
} VoxGraphiteShape;

// An SVG path in the browser's serialized segment format: twelve floats per
// segment, beginning with the segment kind.
typedef struct {
    float matrix[9];
    const float *segments;
    int segment_count, even_odd;
    uint8_t red, green, blue, alpha;
    // A stroke instead of a fill; caps and joins use the SVG enumeration order.
    int stroke, line_cap, line_join;
    float stroke_width, miter_limit;
    // An optional gradient paint instead of the solid color: 1 linear (start,
    // end), 2 two-point conical (start, start radius, end, end radius). Stops
    // hold red, green, blue, alpha and offset; the tile mode follows SkTileMode.
    int gradient, tile_mode, linear_color_space, stop_count;
    float gradient_points[6], gradient_matrix[9], opacity;
    const float *stops;
} VoxGraphitePath;

#ifdef __cplusplus
extern "C" {
#endif
// Owner/main-thread idle cache eviction. Does not initialize an unused backend
// or destroy live paint resources; the next draw may rebuild temporary caches.
void vox_graphite_release_unused_graphics_memory(void);
int vox_graphite_draw_shadow_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShadow *shadow);
int vox_graphite_draw_image_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteImage *image);
int vox_graphite_draw_image_tiles(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteImage *images, int count);
int vox_graphite_draw_shape_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShape *shape);
int vox_graphite_draw_path_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphitePath *path);
int vox_graphite_convert_icc_rgba(uint8_t *pixels, int count,
    const uint8_t *profile, int profile_size);
#ifdef __cplusplus
}
#endif

#endif
