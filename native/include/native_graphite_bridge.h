#ifndef VOX_NATIVE_GRAPHITE_BRIDGE_H
#define VOX_NATIVE_GRAPHITE_BRIDGE_H

#include <stdint.h>
#include <stddef.h>
#include "native_image_color_profile.h"
#include "native_gpu_canvas_limits.h"

enum {
    VOX_GRAPHITE_IMAGE_FORCE_MSAA = 32,
    VOX_GRAPHITE_IMAGE_REPEAT_X = 64,
    VOX_GRAPHITE_IMAGE_REPEAT_Y = 128,
    // A separately composited opaque CSS mask at the image clip's rounded box.
    VOX_GRAPHITE_IMAGE_ROUNDED_ALPHA_MASK = 256,
    VOX_GRAPHITE_IMAGE_YUV422 = 512,
    // A media frame: Chromium's compositor samples the uploaded frame
    // directly instead of resizing it through the image decode cache.
    VOX_GRAPHITE_IMAGE_VIDEO_FRAME = 1024,
    // An authored overflow clip remains an operation even when its rectangle
    // equals the image destination: it affects GPU shader interpolation.
    VOX_GRAPHITE_IMAGE_EXPLICIT_RECT_CLIP = 2048,
    // A whole background tile keeps filtering beyond its adjusted source.
    VOX_GRAPHITE_IMAGE_UNCLAMPED_SOURCE = 4096,
    // A full-resolution alpha plane follows the packed Y/U/V payload.
    VOX_GRAPHITE_IMAGE_YUVA_ALPHA = 8192
};

// Plain-value paint descriptors shared by V and the native Quartz painter.
// The names predate the removed Graphite backend that first consumed them.
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
    // 7 a uniform ring sharing its outer clip layer with the background,
    // 8 equal opaque solid sides with some zero-width sides (outer rectangle).
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
    // Used by modes 2..5 and 8, including present transparent sides in 2..5.
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

// Retained compositor tiles: each RGBA IOSurface's rectangle maps to the
// specified canvas rectangle, starting from `previous` (same dimensions).
typedef struct {
    void *surface, *previous;
    int canvas_x, canvas_y, surface_x, surface_y, width, height;
} VoxGraphiteCanvasSurfaceRegion;

#endif
