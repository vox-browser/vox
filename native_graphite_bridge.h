#ifndef VOX_NATIVE_GRAPHITE_BRIDGE_H
#define VOX_NATIVE_GRAPHITE_BRIDGE_H

#include <stdint.h>
#include <stddef.h>
#include "native_image_color_profile.h"

enum {
    VOX_GRAPHITE_IMAGE_FORCE_MSAA = 32,
    VOX_GRAPHITE_IMAGE_REPEAT_X = 64,
    VOX_GRAPHITE_IMAGE_REPEAT_Y = 128
};

// Only pixels and plain values cross this boundary. The compatibility GPU
// backend owns its Skia objects independently of the translated engine's Skia.
typedef struct {
    float matrix[9];
    float shadow[12];
    float content[12];
    float blur;
    uint8_t red, green, blue, alpha;
    int has_float_color;
    float float_color[4];
} VoxGraphiteShadow;

typedef struct {
    float matrix[9];
    float source[4], destination[4], clip[12];
    float opacity;
    int width, height, pitch, flags, nearest;
    const uint8_t *pixels;
    // A retained numerical ICC or legacy gAMA/cHRM image color space.
    int has_color_profile;
    float color_profile[VOX_IMAGE_COLOR_PROFILE_VALUES];
    // Background color and image share one rounded clip and MSAA coverage.
    int has_background_color;
    uint8_t background_rgba[4];
    // An adjacent CSS border restores the image clip before its stroke, while
    // retaining the render pass's multisample coverage.
    float border_rect[12], border_width;
    uint8_t border_rgba[4];
} VoxGraphiteImage;

typedef struct {
    float matrix[9], rect[12], thickness;
    uint8_t red, green, blue, alpha;
    // fill: 0 stroke, 1 fill, 2..5 a single top/right/bottom/left border,
    // 6 a uniform elliptical ring (center rectangle, border_widths[0]),
    // 7 a uniform ring sharing its outer clip layer with the background.
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
    // Used by modes 2..5, including geometrically present transparent sides.
    float border_widths[4];
    int has_float_underlay_color;
    float underlay_float_color[4];
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
    int non_scaling_stroke;
    float stroke_width, miter_limit;
    // An optional gradient paint instead of the solid color: 1 linear (start,
    // end), 2 two-point conical (start, start radius, end, end radius). Stops
    // hold red, green, blue, alpha and offset; the tile mode follows SkTileMode.
    int gradient, tile_mode, linear_color_space, stop_count;
    float gradient_points[6], gradient_matrix[9], opacity;
    const float *stops;
    int has_float_alpha;
    // Optional rounded clips in the path's local coordinate space.
    int has_clip;
    float clip[12];
    int has_ancestor_clip;
    float ancestor_clip[12];
    int has_float_color;
    float float_color[4];
    // CSS interpolates premultiplied colors; SVG retains straight components.
    int gradient_premul;
} VoxGraphitePath;

#ifdef __cplusplus
extern "C" {
#endif
// Owner/main-thread idle cache eviction. Does not initialize an unused backend
// or destroy live paint resources; the next draw may rebuild temporary caches.
void vox_graphite_release_unused_graphics_memory(void);
void vox_graphite_picture_release_unused_graphics_memory(void);
// Idle polling: -1 means a live context is still in use/recently used, 1
// means it was released, and 0 means there is no context to retire.
int vox_graphite_release_idle_graphics_memory(void);
void vox_graphite_finish_frame(void);
int vox_graphite_picture_release_idle_graphics_memory(void);
int vox_graphite_draw_picture_pixels(uint8_t *pixels, int width, int height,
    int pitch, const void *bytes, size_t size, const float *matrix);
// Render on the original target, then transfer only the requested device-pixel
// rectangle. Target dimensions and coordinates still determine GPU coverage.
int vox_graphite_draw_picture_region_pixels(uint8_t *pixels, int width, int height,
    int pitch, int x, int y, int region_width, int region_height,
    const void *bytes, size_t size, const float *matrix);
int vox_graphite_draw_shadow_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShadow *shadow);
int vox_graphite_draw_image_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteImage *image);
int vox_graphite_draw_image_tiles(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteImage *images, int count);
// CPU decode uploads use this backend's Chromium-pinned Skia in both leaf and
// retained-picture draws. Input/output are premultiplied RGBA in the source
// color space. Only downsampling is supported; row padding is left untouched.
int vox_graphite_resize_rgba_pixels(const VoxGraphiteImage *image,
    uint8_t *pixels, int width, int height, int pitch);
int vox_graphite_draw_shape_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphiteShape *shape);
// CPU pixels for a subregion of an otherwise transparent GPU surface. The
// shape matrix and raster dimensions remain in the original tile coordinates.
typedef struct VoxGraphitePixelRegion {
    int x, y, width, height, pitch;
    uint8_t *pixels;
} VoxGraphitePixelRegion;
typedef struct VoxGraphitePictureRegion {
    VoxGraphitePixelRegion output;
    const void *bytes;
    size_t size;
    float matrix[9];
} VoxGraphitePictureRegion;
// Independent tiles of one picture group. Inputs remain immutable throughout
// the call. Wait once, and publish no CPU output unless every transfer succeeds.
int vox_graphite_draw_picture_regions_pixels(const VoxGraphitePictureRegion *regions,
    int count, int surface_width, int surface_height);
// Image interpolation uses the complete surface extent. Only the region has a
// CPU backdrop; the rest is transparent. Failure leaves the region untouched.
int vox_graphite_draw_image_region_pixels(const VoxGraphitePixelRegion *region,
    int surface_width, int surface_height, int has_background, const VoxGraphiteImage *image);
// Retain full GPU coordinates while writing at most four disjoint CPU views.
// Unsupported shapes and failures leave every view and its padding untouched.
int vox_graphite_draw_rounded_parts_pixels(const VoxGraphitePixelRegion *regions, int count,
    int width, int height, int has_background, const VoxGraphiteShape *shape);
int vox_graphite_draw_shape_region_pixels(const VoxGraphitePixelRegion *region,
    int surface_width, int surface_height, int has_background, const VoxGraphiteShape *shape);
// Independent tiles of one leaf, each with its own immutable backdrop and
// descriptor. Wait once for the batch; failure leaves all CPU views untouched.
int vox_graphite_draw_shape_regions_pixels(const VoxGraphitePixelRegion *regions,
    const VoxGraphiteShape *shapes, int count, int surface_width, int surface_height,
    int has_background);
int vox_graphite_draw_path_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphitePath *path);
int vox_graphite_draw_path_region_pixels(const VoxGraphitePixelRegion *region,
    int surface_width, int surface_height, int has_background, const VoxGraphitePath *path);
// Disjoint views of one unchanged solid fill, resolved in one GPU submission.
// Failure leaves all CPU views untouched.
int vox_graphite_draw_path_parts_pixels(const VoxGraphitePixelRegion *regions, int count,
    int surface_width, int surface_height, int has_background, const VoxGraphitePath *path);
int vox_graphite_draw_path_batch_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphitePath *paths, int count);
int vox_graphite_draw_svg_image_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphitePath *paths, int count,
    const float *parent_matrix, const float *viewport, const float *rounded_clip);
int vox_graphite_draw_svg_pattern_pixels(uint8_t *pixels, int width, int height,
    int pitch, int has_background, const VoxGraphitePath *paths, int count,
    const float *parent_matrix, const float *tile, const float *clip, float opacity, int linear);
int vox_graphite_convert_icc_rgba(uint8_t *pixels, int count,
    const uint8_t *profile, int profile_size);
#ifdef __cplusplus
}
#endif

#endif
