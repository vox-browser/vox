#include "../native_opacity_canvas_pool_darwin.h"
#include <CoreText/CoreText.h>
#include <assert.h>
#include <math.h>
#include <stdio.h>

static size_t comparisons;
static CTFontRef font;
static CGGlyph glyph;

static VoxOpacityCanvas fresh(size_t width, size_t height, CGColorSpaceRef space) {
    VoxOpacityCanvas canvas = {0};
    canvas.pixels = calloc(height, width * 4);
    canvas.context = CGBitmapContextCreate(canvas.pixels, width, height, 8, width * 4,
        space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    assert(canvas.context);
    return canvas;
}

static void assert_empty(VoxOpacityCanvas canvas) {
    assert(CGBitmapContextGetData(canvas.context) == canvas.pixels);
    size_t bytes = native_opacity_canvas_bytes(canvas);
    for (size_t i = 0; i < bytes; ++i) assert(canvas.pixels[i] == 0);
    assert(CGAffineTransformIsIdentity(CGContextGetCTM(canvas.context)));
    assert(CGAffineTransformIsIdentity(CGContextGetTextMatrix(canvas.context)));
    assert(CGPointEqualToPoint(CGContextGetTextPosition(canvas.context), CGPointZero));
    assert(CGContextIsPathEmpty(canvas.context));
}

static CGRect paint(VoxOpacityCanvas canvas, int iteration) {
    CGContextRef context = canvas.context;
    size_t width = CGBitmapContextGetWidth(context), height = CGBitmapContextGetHeight(context);
    CGFloat scale = iteration % 2 + 1;
    CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, .125 * (iteration % 5), .25 * (iteration % 3));
    // Changing and disjoint fractional clips; thin and empty regions too.
    CGRect clip = CGRectMake((iteration * 31) % width / scale,
        (iteration * 17) % height / scale, (iteration % 37) / scale, (iteration % 29) / scale);
    CGContextClipToRect(context, clip);
    CGRect device = CGContextConvertRectToDeviceSpace(context, CGContextGetClipBoundingBox(context));
    if (iteration % 3 == 0) {
        CGContextAddEllipseInRect(context, clip);
        CGContextClip(context);
    }
    CGContextSetRGBFillColor(context, .375, .625, .875, .7);
    CGContextFillRect(context, CGRectMake(-1000, -1000, 3000, 3000));
    CGContextSetAlpha(context, .375);
    CGContextSetBlendMode(context, kCGBlendModeScreen);
    CGContextSetRGBFillColor(context, .75, .125, .5, .625);
    CGContextFillEllipseInRect(context, CGRectInset(clip, -2.5, -1.25));
    CGContextSetShouldSmoothFonts(context, true);
    CGContextSetShouldSubpixelPositionFonts(context, true);
    CGContextSetShouldSubpixelQuantizeFonts(context, true);
    CGPoint position = CGPointMake(clip.origin.x + .375, clip.origin.y + 13.125);
    CTFontDrawGlyphs(font, &glyph, &position, 1, context);
    CGContextSetLineWidth(context, 3.5);
    CGContextSetLineDash(context, 1, (CGFloat[]){2, 3}, 2);
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(2, 3));
    CGContextSetTextPosition(context, 7, 11);
    CGContextMoveToPoint(context, 17, 19);
    CGContextAddLineToPoint(context, 29, 31);
    CGContextSetAllowsAntialiasing(context, false);
    CGContextSetAllowsFontSmoothing(context, false);
    CGContextSetAllowsFontSubpixelPositioning(context, false);
    CGContextSetAllowsFontSubpixelQuantization(context, false);
    CGContextFlush(context);
    return device;
}

static void release(VoxOpacityCanvas canvas, CGRect device) {
    size_t width = CGBitmapContextGetWidth(canvas.context), height = CGBitmapContextGetHeight(canvas.context);
    size_t left = fmax(0, fmin(width, floor(CGRectGetMinX(device))));
    size_t top = fmax(0, fmin(height, floor(CGRectGetMinY(device))));
    size_t right = fmax(left, fmin(width, ceil(CGRectGetMaxX(device))));
    size_t bottom = fmax(top, fmin(height, ceil(CGRectGetMaxY(device))));
    native_release_opacity_canvas(canvas, left, top, right, bottom);
}

static void compare_sequence(CGColorSpaceRef space, size_t width, size_t height) {
    for (int i = 0; i < 128; ++i) {
        VoxOpacityCanvas actual = native_acquire_opacity_canvas(width, height, space);
        assert(actual.context);
        assert_empty(actual);
        VoxOpacityCanvas expected = fresh(width, height, space);
        CGRect bounds = paint(actual, i);
        paint(expected, i);
        assert(!memcmp(actual.pixels, expected.pixels, native_opacity_canvas_bytes(actual)));
        native_destroy_opacity_canvas(expected);
        // A live nested group cannot alias the parent's pixels or context.
        VoxOpacityCanvas nested = native_acquire_opacity_canvas(width, height, space);
        assert(nested.context && nested.context != actual.context && nested.pixels != actual.pixels);
        assert_empty(nested);
        release(nested, paint(nested, i + 11));
        release(actual, bounds);
        assert(native_opacity_canvas_pool_bytes <= VOX_OPACITY_CANVAS_POOL_BYTES);
        ++comparisons;
    }
}

int main(void) {
    font = CTFontCreateWithName(CFSTR("Helvetica"), 18, NULL);
    assert(font && CTFontGetGlyphsForCharacters(font, (UniChar[]){'A'}, &glyph, 1));
    CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorSpaceRef p3 = CGColorSpaceCreateWithName(kCGColorSpaceDisplayP3);
    CGColorSpaceRef linear = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
    for (int disabled = 0; disabled < 2; ++disabled) {
        setenv("VOX_DISABLE_OPACITY_CANVAS_POOL", disabled ? "1" : "", 1);
        for (size_t size = 0; size < 3; ++size)
            for (size_t space = 0; space < 3; ++space)
                compare_sequence((CGColorSpaceRef[]){srgb, p3, linear}[space],
                    (size_t[]){67, 129, 251}[size], (size_t[]){43, 83, 137}[size]);
        native_discard_opacity_canvas_pool();
        assert(native_opacity_canvas_pool_bytes == 0);
    }
    unsetenv("VOX_DISABLE_OPACITY_CANVAS_POOL");
    // Equivalent color-space objects may share a canvas; different spaces may not.
    VoxOpacityCanvas original = native_acquire_opacity_canvas(67, 43, srgb);
    CGContextRef identity = original.context;
    native_release_opacity_canvas(original, 0, 0, 67, 43);
    CGColorSpaceRef equivalent = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    VoxOpacityCanvas reused = native_acquire_opacity_canvas(67, 43, equivalent);
    assert(reused.context == identity);
    native_release_opacity_canvas(reused, 0, 0, 67, 43);
    VoxOpacityCanvas other = native_acquire_opacity_canvas(67, 43, p3);
    assert(other.context != identity);
    // Retained Quartz snapshots must remain immutable when the canvas returns.
    CGRect dirty = paint(other, 20);
    CGImageRef snapshot = CGBitmapContextCreateImage(other.context);
    CFDataRef before = CGDataProviderCopyData(CGImageGetDataProvider(snapshot));
    release(other, dirty);
    other = native_acquire_opacity_canvas(67, 43, p3);
    assert_empty(other);
    release(other, paint(other, 23));
    CFDataRef after = CGDataProviderCopyData(CGImageGetDataProvider(snapshot));
    assert(CFEqual(before, after));
    CFRelease(before); CFRelease(after); CGImageRelease(snapshot);
    native_discard_opacity_canvas_pool();
    // A third idle canvas evicts the two existing slots.
    VoxOpacityCanvas a = native_acquire_opacity_canvas(33, 17, srgb);
    VoxOpacityCanvas b = native_acquire_opacity_canvas(35, 19, srgb);
    VoxOpacityCanvas c = native_acquire_opacity_canvas(37, 23, srgb);
    native_release_opacity_canvas(a, 0, 0, 33, 17);
    native_release_opacity_canvas(b, 0, 0, 35, 19);
    assert(native_opacity_canvas_pool_bytes == (33 * 17 + 35 * 19) * 4);
    native_release_opacity_canvas(c, 0, 0, 37, 23);
    assert(native_opacity_canvas_pool_bytes == 37 * 23 * 4);
    native_discard_opacity_canvas_pool();
    // Two individually eligible allocations still obey the aggregate budget.
    a = native_acquire_opacity_canvas(4096, 1056, srgb);
    b = native_acquire_opacity_canvas(4096, 1056, srgb);
    assert(a.context && b.context && a.context != b.context);
    native_release_opacity_canvas(a, 0, 0, 4096, 1056);
    native_release_opacity_canvas(b, 0, 0, 4096, 1056);
    assert(native_opacity_canvas_pool_bytes == 4096 * 1056 * 4);
    native_discard_opacity_canvas_pool();
    // Oversized and invalid clearing regions cannot enter the idle pool.
    other = native_acquire_opacity_canvas(4096, 2049, srgb);
    assert(other.context);
    native_release_opacity_canvas(other, 0, 0, 4096, 2049);
    assert(native_opacity_canvas_pool_bytes == 0);
    other = native_acquire_opacity_canvas(67, 43, srgb);
    native_release_opacity_canvas(other, 0, 0, 68, 43);
    assert(native_opacity_canvas_pool_bytes == 0);
    assert(!native_acquire_opacity_canvas(SIZE_MAX, 2, srgb).context);
    assert(!native_acquire_opacity_canvas(2, SIZE_MAX, srgb).context);
    CGColorSpaceRelease(equivalent);
    CGColorSpaceRelease(srgb); CGColorSpaceRelease(p3); CGColorSpaceRelease(linear);
    CFRelease(font);
    printf("Opacity canvas pool: %zu exact comparisons, nested ownership, eviction, state reset and snapshots passed\n", comparisons);
    return 0;
}
