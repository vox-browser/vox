#include "../native/include/native_svg_mask_path_darwin.h"

extern int vox_test_mask_raster(uint8_t *, int, int, int, int, VoxGraphitePath *);

static int vox_test_mask_path(uint8_t *pixels, int size, const float *segments,
    int count, float x, float y, float scale, int stroke, int clipped)
{
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixels, size, size, 8, size * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return 0;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, size, size));
    if (clipped) {
        CGContextClipToRect(context, CGRectMake(0, 0, 24, size));
        CGContextSetAlpha(context, .5);
    }
    CGContextTranslateCTM(context, x, size - y);
    CGContextScaleCTM(context, scale, -scale);
    VoxGraphitePath path = {0};
    path.segments = segments; path.segment_count = count; path.even_odd = 1;
    path.red = path.green = path.blue = 12; path.alpha = 255;
    path.opacity = 1; path.stroke = stroke; path.stroke_width = 3;
    path.line_cap = 1; path.line_join = 1; path.miter_limit = 4;
    // These coverage references use the full staging bitmap. The native mask
    // layer tests exercise the bounded rectangle path with its actual outline.
    CGMutablePathRef outline = CGPathCreateMutable();
    if (!outline) {
        CGContextRelease(context);
        return 0;
    }
    int drawn = native_raster_svg_mask_path(context, &path, outline, vox_test_mask_raster);
    CGPathRelease(outline);
    CGContextRelease(context);
    return drawn;
}
