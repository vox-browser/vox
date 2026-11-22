#include <assert.h>
#include <stdint.h>
#include <string.h>
#include "../native/include/native_svg_pattern_path_darwin.h"

enum { width = 128, height = 96, row_bytes = width * 4 };
typedef uint8_t Surface[height][row_bytes];

static const uint8_t *pixel(const Surface surface, int x, int y) {
    return &surface[height - 1 - y][x * 4];
}

static bool painted(const Surface surface, int x, int y) {
    const uint8_t *p = pixel(surface, x, y);
    return p[0] != 255 || p[1] != 255 || p[2] != 255;
}

static void render(Surface surface, CGColorSpaceRef color_space, CGImageRef image,
    CGPathRef path, const NativeSVGPatternStroke *stroke, bool even_odd) {
    CGContextRef ctx = CGBitmapContextCreate(surface, width, height, 8, row_bytes,
        color_space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(ctx);
    CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, width, height));
    CGContextSetShouldAntialias(ctx, false);
    CGAffineTransform to_canvas = CGAffineTransformMake(2, 0, 0, -2, 12, 48);
    CGAffineTransform pattern = CGAffineTransformMakeTranslation(3, 2);
    native_draw_svg_pattern_tile(ctx, path, even_odd, to_canvas, image,
        CGRectMake(3, 1, 12, 12), pattern, 0.5, stroke);
    assert(CGAffineTransformIsIdentity(CGContextGetCTM(ctx)));
    CGContextRelease(ctx);
}

int main(void) {
    static const uint8_t tile[] = {
        255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255,
        0, 255, 255, 255, 255, 0, 255, 255, 255, 255, 0, 255,
    };
    CGColorSpaceRef color_space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, tile, sizeof(tile), NULL);
    CGImageRef image = CGImageCreate(3, 2, 8, 32, 12, color_space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, provider, NULL,
        false, kCGRenderingIntentDefault);
    assert(image);
    CGPathRef rectangle = CGPathCreateWithRect(CGRectMake(0, -12, 58, 24), NULL);
    CGMutablePathRef line = CGPathCreateMutable();
    CGPathMoveToPoint(line, NULL, 5, 0);
    CGPathAddLineToPoint(line, NULL, 58, 0);

    const CGFloat dashes[] = {18, 10};
    NativeSVGPatternStroke stroke = {
        .width = 6, .cap = kCGLineCapButt, .join = kCGLineJoinMiter, .miter_limit = 4,
        .non_scaling = true, .dashes = dashes, .dash_count = 2, .dash_offset = 4,
    };
    Surface fill, non_scaling, scaling, solid, no_offset;
    render(fill, color_space, image, rectangle, NULL, false);
    render(non_scaling, color_space, image, line, &stroke, false);
    stroke.non_scaling = false;
    render(scaling, color_space, image, line, &stroke, false);
    stroke.dash_count = 0;
    render(solid, color_space, image, line, &stroke, false);
    stroke.non_scaling = true;
    stroke.dash_count = 2;
    stroke.dash_offset = 0;
    render(no_offset, color_space, image, line, &stroke, false);

    // The first 14 host pixels are painted after the four-pixel phase.
    // The scaling stroke evaluates the same phase in path coordinates.
    assert(!painted(non_scaling, 21, 48) && painted(non_scaling, 22, 48));
    assert(painted(non_scaling, 35, 48) && !painted(non_scaling, 36, 48));
    assert(!painted(non_scaling, 45, 48) && painted(non_scaling, 46, 48));
    assert(painted(no_offset, 38, 48) && !painted(non_scaling, 38, 48));
    assert(painted(scaling, 49, 48) && !painted(scaling, 50, 48));
    assert(painted(solid, 50, 48));

    // Geometry changes leave the tile phase and alpha equal to the fill.
    for (int y = 42; y < 54; ++y) {
        assert(painted(scaling, 30, y));
        assert(painted(non_scaling, 30, y) == (y >= 45 && y < 51));
        if (y >= 45 && y < 51) {
            for (int x = 22; x < 36; ++x) {
                assert(memcmp(pixel(fill, x, y), pixel(non_scaling, x, y), 4) == 0);
            }
        }
    }
    assert(memcmp(pixel(fill, 23, 48), pixel(fill, 32, 48), 4) != 0);

    CGMutablePathRef hole = CGPathCreateMutableCopy(rectangle);
    CGPathAddRect(hole, NULL, CGRectMake(5, -3, 15, 6));
    Surface even_odd;
    render(even_odd, color_space, image, hole, NULL, true);
    assert(!painted(even_odd, 26, 48) && painted(even_odd, 60, 48));

    const CGFloat dotted[] = {0, 8};
    stroke.dashes = dotted;
    stroke.cap = kCGLineCapRound;
    Surface dots;
    render(dots, color_space, image, line, &stroke, false);
    assert(painted(dots, 22, 48) && !painted(dots, 26, 48) && painted(dots, 30, 48));

    CGPathRelease(hole);
    CGPathRelease(line);
    CGPathRelease(rectangle);
    CGImageRelease(image);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(color_space);
    return 0;
}
