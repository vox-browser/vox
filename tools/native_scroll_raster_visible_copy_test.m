#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native_scroll_raster_darwin.h"

// Exercise the real ring reader independently of Quartz painting: omitted
// pixels must keep their sentinel and every other byte must match the ring.
static void test_visible_copy(void) {
    const size_t width = 79, height = 53, top = 3;
    for (int padding = 0; padding <= 20; padding += 20)
    for (size_t origin = 0; origin < height; origin += 13)
    for (int direction = -1; direction <= 1; ++direction)
    for (int promise = 0; promise <= 1; ++promise)
    for (int enabled = 0; enabled <= 1; ++enabled) {
        size_t pitch = width * 4 + padding, size = (top + height + 2) * pitch;
        uint8_t *pixels = malloc(width * height * 4), *actual = malloc(size);
        uint8_t *expected = malloc(size);
        assert(pixels && actual && expected);
        for (size_t i = 0; i < width * height * 4; ++i) pixels[i] = i * 37 + i / 47;
        memset(actual, 0xa5, size);
        memset(expected, 0xa5, size);
        VoxScrollRaster cache = {.pixels = pixels, .width = width, .height = height,
            .top = top, .row_origin = origin};
        // Overlapping, touching, nested, disjoint and full-width rectangles.
        const long rects[][4] = {{3, 2, 51, 25}, {21, 12, 73, 39},
            {10, 18, 13, 19}, {73, 12, 79, 39}, {0, 41, 79, 48}};
        memcpy(native_scroll_repainted, rects, sizeof(rects));
        native_scroll_repainted_count = sizeof(rects) / sizeof(*rects);
        setenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY", enabled ? "1" : "", 1);
        size_t first = direction < 0 ? 7 : 0;
        size_t count = height - (direction ? 7 : 0), omitted = 0;
        for (size_t y = first; y < first + count; ++y)
        for (size_t x = 0; x < width; ++x) {
            int skip = 0;
            if (promise && enabled) {
                for (size_t i = 0; i < sizeof(rects) / sizeof(*rects); ++i)
                    if (x >= (size_t)rects[i][0] && x < (size_t)rects[i][2]
                        && y >= (size_t)rects[i][1] && y < (size_t)rects[i][3]) skip = 1;
            }
            if (skip) omitted += 4;
            else memcpy(expected + (top + y) * pitch + x * 4,
                pixels + ((origin + y) % height) * width * 4 + x * 4, 4);
        }
        size_t result = native_scroll_raster_restore_visible(&cache, actual,
            pitch, first, count, promise);
        assert(result == omitted);
        assert(!memcmp(actual, expected, size));
        free(expected); free(actual); free(pixels);
    }
    unsetenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY");
}

static void test_small_damage_admission(void) {
    uint8_t ring[100 * 100 * 4], output[sizeof(ring)];
    memset(ring, 0x31, sizeof(ring));
    memset(output, 0xa5, sizeof(output));
    VoxScrollRaster cache = {.pixels = ring, .width = 100, .height = 100};
    // A two-percent patch is worth skipping; a single pixel uses bulk copy.
    long patch[] = {3, 7, 23, 17};
    memcpy(native_scroll_repainted[0], patch, sizeof(patch));
    native_scroll_repainted_count = 1;
    setenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY", "1", 1);
    assert(native_scroll_raster_restore_visible(&cache, output, 400, 0, 100, 1) == 800);
    assert(output[(7 * 100 + 3) * 4] == 0xa5);
    native_scroll_repainted[0][2] = 4; native_scroll_repainted[0][3] = 8;
    assert(native_scroll_raster_restore_visible(&cache, output, 400, 0, 100, 1) == 0);
    assert(!memcmp(output, ring, sizeof(ring)));
    unsetenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY");
}

// Fractional damage leaves partially covered edge pixels in the retained
// copy. Compare final compositing against an independently restored baseline.
static void test_fractional_damage(int scale, int promise) {
    const int width = 89, height = 67, chrome = 4;
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    size_t pitch = (width * scale + 7) * 4;
    CGContextRef actual = CGBitmapContextCreate(NULL, width * scale,
        (height + chrome * 2) * scale, 8, pitch, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextRef expected = CGBitmapContextCreate(NULL, width * scale,
        (height + chrome * 2) * scale, 8, pitch, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(actual && expected);
    CGContextScaleCTM(actual, scale, scale);
    CGContextScaleCTM(expected, scale, scale);
    native_discard_scroll_raster();
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    double delta = 0;
    assert(!native_begin_scroll_raster(19, 1, 0, chrome, width, height,
        1, &delta, NULL, 0, 0, promise));
    uint8_t *a = CGBitmapContextGetData(actual), *e = CGBitmapContextGetData(expected);
    memset(a, 0xff, pitch * (height + chrome * 2) * scale);
    for (int y = 0; y < height * scale; ++y)
    for (int x = 0; x < width * scale; ++x) {
        uint8_t *pixel = a + (chrome * scale + y) * pitch + x * 4;
        pixel[0] = x * 13; pixel[1] = y * 17; pixel[2] = (x + y) * 7;
    }
    native_end_scroll_raster();
    double rects[][4] = {{3.2, 5.25, 62.3, 35.5}, {17.75, 25.1, 70.5, 30.6}};
    for (int frame = 0; frame < 18; ++frame) {
        double scroll = frame < 9 ? frame * 7 : (17 - frame) * 7;
        // Restore the old ring with its next origin before testing exclusion.
        long rows = lround((scroll - native_scroll_raster.scroll) * scale);
        size_t origin = (native_scroll_raster.row_origin + height * scale + rows)
            % (height * scale);
        memset(e, 0xff, pitch * (height + chrome * 2) * scale);
        for (int y = 0; y < height * scale; ++y) {
            if ((rows > 0 && y >= height * scale - rows) || (rows < 0 && y < -rows)) continue;
            memcpy(e + (chrome * scale + y) * pitch,
                native_scroll_raster.pixels
                    + ((origin + y) % (height * scale)) * width * scale * 4,
                width * scale * 4);
        }
        memset(a, 0xff, pitch * (height + chrome * 2) * scale);
        assert(native_begin_scroll_raster(19, frame + 2, scroll, chrome, width,
            height, 1, &delta, &rects[0][0], 2, 1, promise));
        CGRect clips[3] = {CGRectMake(0, rows < 0 ? chrome + height - fabs(delta)
            : chrome, width, fabs(delta))};
        for (int i = 0; i < 2; ++i)
            clips[i + 1] = CGRectMake(rects[i][0], chrome + height - rects[i][1]
                - rects[i][3], rects[i][2], rects[i][3]);
        CGContextSaveGState(expected);
        CGContextClipToRects(expected, clips, 3);
        for (int i = 0; i < 2; ++i) {
            CGContextRef context = i ? expected : actual;
            if (promise) {
                CGContextSetRGBFillColor(context, 1, 1, 1, 1);
                CGContextFillRect(context, CGRectMake(0, 0, width, height + chrome * 2));
            }
            CGContextSetRGBFillColor(context, 0.2, 0.6, 0.1, 0.4);
            CGContextFillRect(context, CGRectMake(0, 0, width, height + chrome * 2));
            CGContextFlush(context);
        }
        native_end_scroll_raster();
        CGContextRestoreGState(expected);
        assert(!memcmp(a, e, pitch * (height + chrome * 2) * scale));
    }
    [NSGraphicsContext restoreGraphicsState];
    native_discard_scroll_raster();
    CGContextRelease(actual); CGContextRelease(expected);
}

int main(void) {
    @autoreleasepool {
        test_visible_copy();
        test_small_damage_admission();
        setenv("VOX_SKIP_OVERWRITTEN_SCROLL_COPY", "1", 1);
        for (int scale = 1; scale <= 2; ++scale)
        for (int promise = 0; promise <= 1; ++promise)
            test_fractional_damage(scale, promise);
        puts("Visible scroll copy: exact overlap, ring wraps, padded rows, opaque contract and fractional clip edges");
    }
}
