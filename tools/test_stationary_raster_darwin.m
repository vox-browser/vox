#import <Cocoa/Cocoa.h>
#include <assert.h>
static int fail_snapshot_creation;
static CGImageRef create_snapshot(CGContextRef context) {
    return fail_snapshot_creation ? NULL : CGBitmapContextCreateImage(context);
}
#define CGBitmapContextCreateImage create_snapshot
#include "../native_stationary_raster_darwin.h"
#undef CGBitmapContextCreateImage

static int bitmap_padding;

static CGContextRef bitmap(int width, int height, int scale) {
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width * scale, height * scale,
        8, width * scale * 4 + bitmap_padding, color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    CGContextScaleCTM(context, scale, scale);
    return context;
}
static int begin(int owner, int revision, int generation, double scroll,
    double top, double zoom, double opacity) {
    return native_begin_stationary_raster(owner, revision, generation, scroll, top, zoom, opacity, 1);
}
static void fill(CGContextRef context, int seed) {
    size_t pitch = CGBitmapContextGetBytesPerRow(context), h = CGBitmapContextGetHeight(context);
    uint8_t *pixels = CGBitmapContextGetData(context);
    for (size_t i = 0; i < pitch * h; ++i) pixels[i] = (uint8_t)(i * 13 + i / pitch + seed);
}
static void assert_image_bytes(CGImageRef image, const uint8_t *expected, size_t bytes) {
    assert(image);
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    assert(data && CFDataGetLength(data) == (CFIndex)bytes);
    assert(!memcmp(expected, CFDataGetBytePtr(data), bytes));
    CFRelease(data);
}

static void test_immutable_snapshot(int scale) {
    native_discard_stationary_raster();
    CGContextRef source = bitmap(32, 24, scale);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:source flipped:NO];
    assert(!native_begin_stationary_raster_snapshot(1, 2, 3, .5, 7, 1, .4, 1, 1));
    BOOL copied = getenv("VOX_COPY_STATIONARY_RASTER_PIXELS") != NULL;
    assert((native_stationary_raster.pixels != NULL) == copied);
    fill(source, 17);
    size_t bytes = CGBitmapContextGetBytesPerRow(source) * CGBitmapContextGetHeight(source);
    uint8_t *expected = malloc(bytes);
    memcpy(expected, CGBitmapContextGetData(source), bytes);
    native_end_stationary_raster();
    assert((native_stationary_raster.pixels != NULL) == copied);
    assert((native_stationary_raster.image == NULL) == copied);

    CGContextRef destination = bitmap(32, 24, scale);
    CGContextRef wrong = bitmap(33, 24, scale);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:destination flipped:NO];
    fill(destination, 91);
    VoxFrameSnapshot previous = vox_frame_snapshot_begin(destination);
    assert(native_begin_stationary_raster_snapshot(1, 2, 3, .5, 7, 1, .4, 1, 1));
    assert((vox_frame_snapshot.image == NULL) == copied);
    if (!copied) {
        assert(memcmp(expected, CGBitmapContextGetData(destination), bytes));
        assert(!vox_frame_snapshot_select(wrong, native_stationary_raster.image));
        assert(!vox_frame_snapshot_select(destination, native_stationary_raster.image));
        // A nested capture cannot borrow its parent's selected image. Restoring
        // it also restores the parent's retained image and context identity.
        VoxFrameSnapshot outer = vox_frame_snapshot_begin(wrong);
        assert(!vox_frame_snapshot_select(wrong, native_stationary_raster.image));
        assert(!vox_frame_snapshot_select(destination, native_stationary_raster.image));
        vox_frame_snapshot_restore(outer);
        assert(vox_frame_snapshot.image);
    }
    // The selected image owns its bytes even when the cache is discarded.
    native_discard_stationary_raster();
    CGImageRef image = vox_frame_snapshot_copy(destination);
    assert_image_bytes(image, expected, bytes);
    vox_frame_snapshot_restore(previous);
    assert_image_bytes(image, expected, bytes);
    CGImageRelease(image);

    // Without an active native frame target, ordinary bitmap drawing still
    // receives the exact cached bytes through the existing copy path.
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:source flipped:NO];
    assert(!native_begin_stationary_raster_snapshot(1, 2, 4, .5, 7, 1, .4, 1, 1));
    fill(source, 17);
    native_end_stationary_raster();
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:destination flipped:NO];
    fill(destination, 91);
    assert(native_begin_stationary_raster_snapshot(1, 2, 4, .5, 7, 1, .4, 1, 1));
    assert(!memcmp(expected, CGBitmapContextGetData(destination), bytes));
    assert(!native_begin_stationary_raster_snapshot(1, 3, 4, .5, 7, 1, .4, 1, 1));
    native_stationary_raster_independent_content();
    native_end_stationary_raster();
    assert(!native_stationary_raster.valid && !native_stationary_raster.image);
    native_discard_stationary_raster();
    free(expected);
    NSGraphicsContext.currentContext = nil;
    CGContextRelease(wrong);
    CGContextRelease(destination);
    CGContextRelease(source);
}
static void test_snapshot_copy_mode_transitions(void) {
    native_discard_stationary_raster();
    CGContextRef context = bitmap(32, 24, 2);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    unsetenv("VOX_COPY_STATIONARY_RASTER_PIXELS");
    assert(!native_begin_stationary_raster_snapshot(1, 2, 3, 0, 0, 1, 1, 1, 1));
    fill(context, 17); native_end_stationary_raster();
    assert(native_stationary_raster.image && !native_stationary_raster.pixels);
    // A changed document retires its old immutable image before replay starts.
    assert(!native_begin_stationary_raster_snapshot(1, 3, 3, 0, 0, 1, 1, 1, 1));
    assert(!native_stationary_raster.image && !native_stationary_raster.pixels);
    fill(context, 31); native_end_stationary_raster();
    assert(native_stationary_raster.image && !native_stationary_raster.pixels);
    setenv("VOX_COPY_STATIONARY_RASTER_PIXELS", "1", 1);
    assert(!native_begin_stationary_raster_snapshot(1, 3, 3, 0, 0, 1, 1, 1, 1));
    assert(!native_stationary_raster.image && native_stationary_raster.pixels);
    fill(context, 47); native_end_stationary_raster();
    size_t bytes = native_stationary_raster.bytes;
    uint8_t *expected = malloc(bytes);
    memcpy(expected, CGBitmapContextGetData(context), bytes);
    fill(context, 91);
    assert(native_begin_stationary_raster_snapshot(1, 3, 3, 0, 0, 1, 1, 1, 1));
    assert(!memcmp(expected, CGBitmapContextGetData(context), bytes));
    // Snapshot allocation failure keeps a byte-backed cache, with the same
    // exact fallback reuse on a later fresh frame.
    assert(!native_begin_stationary_raster_snapshot(1, 4, 3, 0, 0, 1, 1, 1, 1));
    fill(context, 47);
    fail_snapshot_creation = 1; native_end_stationary_raster(); fail_snapshot_creation = 0;
    assert(native_stationary_raster.valid && !native_stationary_raster.image
        && native_stationary_raster.pixels);
    fill(context, 91);
    assert(native_begin_stationary_raster_snapshot(1, 4, 3, 0, 0, 1, 1, 1, 1));
    assert(!memcmp(expected, CGBitmapContextGetData(context), bytes));
    unsetenv("VOX_COPY_STATIONARY_RASTER_PIXELS");
    assert(!native_begin_stationary_raster_snapshot(1, 3, 3, 0, 0, 1, 1, 1, 1));
    assert(!native_stationary_raster.image && !native_stationary_raster.pixels);
    fill(context, 47); native_end_stationary_raster();
    fill(context, 91);
    assert(native_begin_stationary_raster_snapshot(1, 3, 3, 0, 0, 1, 1, 1, 1));
    assert(!memcmp(expected, CGBitmapContextGetData(context), bytes));
    native_discard_stationary_raster(); free(expected);
    NSGraphicsContext.currentContext = nil; CGContextRelease(context);
}
// Before a document has pixels, UI2 frames are one white fill keyed by a
// reserved owner. Later same-size blank frames present the retained frame and
// never touch their own fresh bitmap; a document key replaces the cache.
static int begin_blank(void) {
    return native_begin_stationary_raster_snapshot(UINT64_MAX, 0, 0, 0, 0, 1, 0, 1, 1);
}
static int all_bytes(CGContextRef context, uint8_t value) {
    const uint8_t *pixels = CGBitmapContextGetData(context);
    size_t pitch = CGBitmapContextGetBytesPerRow(context), height = CGBitmapContextGetHeight(context);
    size_t row = CGBitmapContextGetWidth(context) * 4;
    for (size_t y = 0; y < height; ++y) for (size_t x = 0; x < row; ++x)
        if (pixels[y * pitch + x] != value) return 0;
    return 1;
}
static void white(CGContextRef context) {
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, 32, 24));
}
static void test_blank_frames(int scale) {
    BOOL copied = getenv("VOX_COPY_STATIONARY_RASTER_PIXELS") != NULL;
    native_discard_stationary_raster();
    CGContextRef first = bitmap(32, 24, scale);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:first flipped:NO];
    VoxFrameSnapshot previous = vox_frame_snapshot_begin(first);
    assert(!begin_blank());
    white(first);
    native_end_stationary_raster();
    assert(all_bytes(first, 255));
    vox_frame_snapshot_restore(previous);
    for (int frame = 0; frame < 3; ++frame) {
        CGContextRef fresh = bitmap(32, 24, scale);
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:fresh flipped:NO];
        previous = vox_frame_snapshot_begin(fresh);
        assert(begin_blank());
        native_end_stationary_raster();
        CGImageRef image = vox_frame_snapshot_copy(fresh);
        assert(image);
        if (copied) assert(all_bytes(fresh, 255));
        else {
            // The frame presents the retained white image; its bitmap stays fresh.
            assert(image == native_stationary_raster.image && all_bytes(fresh, 0));
            CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
            const uint8_t *bytes = CFDataGetBytePtr(data);
            for (CFIndex i = 0; i < CFDataGetLength(data); ++i) assert(bytes[i] == 255);
            CFRelease(data);
        }
        CGImageRelease(image);
        vox_frame_snapshot_restore(previous);
        NSGraphicsContext.currentContext = nil;
        CGContextRelease(fresh);
    }
    // A resized blank frame fills again; the first document frame replaces the cache.
    CGContextRef resized = bitmap(33, 24, scale);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:resized flipped:NO];
    assert(!begin_blank());
    native_end_stationary_raster();
    CGContextRef document = bitmap(33, 24, scale);
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:document flipped:NO];
    assert(!native_begin_stationary_raster_snapshot(7, 1, 1, 0, 0, 1, 0, 1, 1));
    assert(native_stationary_raster.image == NULL);
    native_end_stationary_raster();
    assert(!begin_blank());
    NSGraphicsContext.currentContext = nil;
    native_discard_stationary_raster();
    CGContextRelease(document);
    CGContextRelease(resized);
    CGContextRelease(first);
}
int main(void) {
    @autoreleasepool {
        for (int scale = 1; scale <= 2; ++scale) {
            native_discard_stationary_raster();
            CGContextRef context = bitmap(32, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
            assert(!begin(1, 2, 3, 0.5, 7, 1, .4));
            fill(context, 17);
            size_t bytes = CGBitmapContextGetBytesPerRow(context) * CGBitmapContextGetHeight(context);
            uint8_t *expected = malloc(bytes);
            memcpy(expected, CGBitmapContextGetData(context), bytes);
            native_end_stationary_raster();
            // Every use starts with a fresh destination, including subpixel
            // scroll offsets. The copied document is byte-identical.
            for (int frame = 0; frame < 3; ++frame) {
                fill(context, 91);
                assert(begin(1, 2, 3, .5, 7, 1, .4));
                assert(!memcmp(expected, CGBitmapContextGetData(context), bytes));
            }
            assert(!begin(2, 2, 3, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 3, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .5, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 7, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1.25, .4)); native_end_stationary_raster();
            assert(!begin(2, 3, 4, .75, 8, 1.25, .5)); native_end_stationary_raster();
            assert(begin(2, 3, 4, .75, 8, 1.25, .5));
            // Timelines outside DOM invalidation never publish a retained still.
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            native_stationary_raster_independent_content(); native_end_stationary_raster();
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5)); native_end_stationary_raster();
            CGContextSaveGState(context);
            CGContextClipToRect(context, CGRectMake(0, 0, 10, 10));
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            CGContextRestoreGState(context);
            assert(!native_stationary_raster.valid);
            assert(!native_begin_stationary_raster(2, 4, 4, .75, 8, 1.25, .5, 0));
            assert(!begin(2, 4, 4, NAN, 8, 1.25, .5));
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            fill(context, 17);
            native_end_stationary_raster();
            // AppKit creates a new bitmap for each publication. Reuse must
            // work across context identities, but never across dimensions.
            CGContextRef fresh = bitmap(32, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:fresh flipped:NO];
            assert(begin(2, 4, 4, .75, 8, 1.25, .5));
            assert(!memcmp(expected, CGBitmapContextGetData(fresh), bytes));
            CGContextRef resized = bitmap(33, 24, scale);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:resized flipped:NO];
            assert(!begin(2, 4, 4, .75, 8, 1.25, .5));
            native_end_stationary_raster();
            assert(begin(2, 4, 4, .75, 8, 1.25, .5));
            free(expected);
            NSGraphicsContext.currentContext = nil;
            CGContextRelease(fresh);
            CGContextRelease(resized);
            CGContextRelease(context);
        }
        test_immutable_snapshot(1);
        test_immutable_snapshot(2);
        bitmap_padding = 16;
        test_immutable_snapshot(1);
        test_immutable_snapshot(2);
        bitmap_padding = 0;
        BOOL copied = getenv("VOX_COPY_STATIONARY_RASTER_PIXELS") != NULL;
        test_snapshot_copy_mode_transitions();
        if (copied) setenv("VOX_COPY_STATIONARY_RASTER_PIXELS", "1", 1);
        test_blank_frames(1);
        test_blank_frames(2);
        native_discard_stationary_raster();
    }
    puts("stationary raster: exact copies, all input invalidations, dynamic content, clip guards and blank frames passed");
    return 0;
}
