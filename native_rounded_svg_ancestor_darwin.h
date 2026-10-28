#ifndef VOX_NATIVE_ROUNDED_SVG_ANCESTOR_DARWIN_H
#define VOX_NATIVE_ROUNDED_SVG_ANCESTOR_DARWIN_H

#include "native_graphite_bridge.h"
#include <CoreGraphics/CoreGraphics.h>
#include <math.h>

typedef int (*NativeSvgPathBatch)(CGContextRef, const VoxGraphitePath *, int,
    const float *, float, float, float, float, float, float, float, float, float,
    int, const float *);

// A mask separates the child's rounded background from its ancestor's overflow
// clip. Retain both coverage stages, using the same rasterizer for each one.
// Compositing a CoreGraphics ellipse here produces different edge coverage.
static int native_draw_rounded_svg_ancestor_in_context(CGContextRef destination,
    NativeSvgPathBatch draw_batch, const VoxGraphitePath *paths, int count,
    const float *outer, float x, float y, float width, float height,
    float page_x, float page_y, float scroll_y, float canvas_width,
    float canvas_height, const float *rounded_clip)
{
    if (!destination || !draw_batch || !paths || count <= 0 || !outer || !rounded_clip
        || !isfinite(canvas_width) || !isfinite(canvas_height)
        || canvas_width <= 0 || canvas_height <= 0)
        return 0;
    CGAffineTransform ctm = CGContextGetCTM(destination);
    if (!isfinite(ctm.a) || !isfinite(ctm.d) || ctm.a <= 0 || ctm.d <= 0
        || ctm.b != 0 || ctm.c != 0 || ctm.tx != 0 || ctm.ty != 0)
        return 0;
    double device_width = ceil(canvas_width * ctm.a);
    double device_height = ceil(canvas_height * ctm.d);
    // Bound both temporary surfaces before converting dimensions to size_t.
    if (!isfinite(device_width) || !isfinite(device_height)
        || device_width < 1 || device_height < 1
        || device_width * device_height > 8 * 1024 * 1024)
        return 0;
    size_t pixel_width = (size_t)device_width, pixel_height = (size_t)device_height;
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    if (!space) return 0;
    CGBitmapInfo format = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    CGContextRef content = CGBitmapContextCreate(NULL, pixel_width, pixel_height,
        8, pixel_width * 4, space, format);
    CGContextRef mask = CGBitmapContextCreate(NULL, pixel_width, pixel_height,
        8, pixel_width * 4, space, format);
    CGColorSpaceRelease(space);
    int success = 0;
    CGImageRef mask_image = NULL, content_image = NULL;
    float rect[5 * 12] = {0};
    VoxGraphitePath white = {0};
    CGRect bounds = CGRectMake(0, 0, device_width / ctm.a, device_height / ctm.d);
    if (!content || !mask) goto done;
    CGContextScaleCTM(content, ctm.a, ctm.d);
    CGContextScaleCTM(mask, ctm.a, ctm.d);
    if (!draw_batch(content, paths, count, outer, x, y, width, height,
            page_x, page_y, scroll_y, canvas_width, canvas_height, 0, rounded_clip))
        goto done;
    // The ancestor is an opaque rectangle clipped by the independent rounded
    // boundary, in the same local space as the complete background recording.
    rect[0] = 0; rect[1] = x; rect[2] = y;
    rect[12] = 1; rect[13] = x + width; rect[14] = y;
    rect[24] = 1; rect[25] = x + width; rect[26] = y + height;
    rect[36] = 1; rect[37] = x; rect[38] = y + height;
    rect[48] = 5;
    white.matrix[0] = white.matrix[4] = white.matrix[8] = 1;
    white.segments = rect; white.segment_count = 5;
    white.red = white.green = white.blue = white.alpha = 255;
    if (!draw_batch(mask, &white, 1, outer, x, y, width, height,
            page_x, page_y, scroll_y, canvas_width, canvas_height, 0, rounded_clip))
        goto done;
    mask_image = CGBitmapContextCreateImage(mask);
    if (!mask_image) goto done;
    CGContextSetInterpolationQuality(content, kCGInterpolationNone);
    CGContextSetBlendMode(content, kCGBlendModeDestinationIn);
    CGContextDrawImage(content, bounds, mask_image);
    content_image = CGBitmapContextCreateImage(content);
    if (!content_image) goto done;
    // No destination pixels or graphics state change until both draws succeed.
    CGContextSaveGState(destination);
    CGContextSetInterpolationQuality(destination, kCGInterpolationNone);
    CGContextDrawImage(destination, bounds, content_image);
    CGContextRestoreGState(destination);
    success = 1;
done:
    if (content_image) CGImageRelease(content_image);
    if (mask_image) CGImageRelease(mask_image);
    if (content) CGContextRelease(content);
    if (mask) CGContextRelease(mask);
    return success;
}

#endif
