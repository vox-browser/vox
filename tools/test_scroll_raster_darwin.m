#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native/include/native_scroll_raster_darwin.h"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
#include "../native/include/native_layer_presentation_darwin.h"
#pragma clang diagnostic pop

static BOOL redraw_during_paint;
static int canvas_extra_width;
// An offscreen NSView may discard its dirty bit. Keep that bit observable while
// exercising the real layer publication and main-queue redraw delivery.
@interface VoxScrollRasterTestView : NSView {
    BOOL display_requested;
}
@end
@implementation VoxScrollRasterTestView
- (void)setNeedsDisplay:(BOOL)value { display_requested = value; }
- (BOOL)needsDisplay { return display_requested; }
@end

static void test_draw(id view, SEL command, NSRect bounds) {
    (void)view; (void)command; (void)bounds;
    vox_browser_frame_prepared();
    if (redraw_during_paint) ++native_layer_redraw_generation;
}

static void test_redraw_survives_layer_display(void) {
    NSView *view = [[VoxScrollRasterTestView alloc] initWithFrame:NSMakeRect(0, 0, 32, 32)];
    view.wantsLayer = YES;
    native_layer_original_draw = (IMP)test_draw;
    for (int pending = 0; pending < 2; ++pending) {
        redraw_during_paint = pending;
        native_layer_update(view, @selector(updateLayer));
        // Model AppKit clearing the dirty bit after returning from updateLayer.
        view.needsDisplay = NO;
        __block BOOL drained = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
        while (!drained && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:deadline];
        assert(drained);
        assert(view.needsDisplay == (BOOL)pending);
    }
    native_layer_original_draw = NULL;
}

static void test_completed_frame_covers_queued_redraw(void) {
    for (int disabled = 0; disabled < 2; ++disabled)
    for (int change = 0; change < 7; ++change) {
        if (disabled) setenv("VOX_DISABLE_COVERED_LAYER_REDRAWS", "1", 1);
        else unsetenv("VOX_DISABLE_COVERED_LAYER_REDRAWS");
        NSView *view = [[VoxScrollRasterTestView alloc] initWithFrame:NSMakeRect(0, 0, 32, 32)];
        view.wantsLayer = YES;
        native_layer_original_draw = (IMP)test_draw;
        redraw_during_paint = YES;
        native_layer_update(view, @selector(updateLayer)); // Queue a retained request.
        redraw_during_paint = NO;
        native_layer_update(view, @selector(updateLayer)); // Finish a newer frame first.
        view.needsDisplay = NO; // Model AppKit clearing its dirty bit.
        CGFloat saved_scale = native_layer_capture_scale;
        uintptr_t saved_view = native_layer_last_preparation_view;
        uint64_t saved_prepared = native_layer_last_prepared_generation;
        if (change == 1) ++native_layer_redraw_generation;
        if (change == 2) view.frame = NSMakeRect(0, 0, 33, 32);
        if (change == 3) view.needsDisplay = YES;
        if (change == 4) native_layer_capture_scale = native_layer_effective_scale(view) + 1;
        if (change == 5) native_layer_last_preparation_view = 0;
        if (change == 6) --native_layer_last_prepared_generation;
        __block BOOL drained = NO;
        dispatch_async(dispatch_get_main_queue(), ^{ drained = YES; });
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1];
        while (!drained && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:deadline];
        assert(drained);
        assert(view.needsDisplay == (BOOL)(disabled || change != 0));
        native_layer_capture_scale = saved_scale;
        native_layer_last_preparation_view = saved_view;
        native_layer_last_prepared_generation = saved_prepared;
    }
    unsetenv("VOX_DISABLE_COVERED_LAYER_REDRAWS");
    native_layer_original_draw = NULL;
}

static void test_independent_image_pixels_are_not_reused(void) {
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, 32, 32, 8, 128,
        color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(context);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:context flipped:NO]];
    native_discard_scroll_raster();
    double delta = 0;
    for (int frame = 0; frame < 3; ++frame) {
        assert(!native_begin_scroll_raster(1, 1, frame, 0, 32, 32, 1, &delta, NULL, 0, 1, 1));
        native_scroll_raster_independent_content();
        native_end_scroll_raster();
        assert(!native_scroll_raster.valid);
    }
    native_discard_scroll_raster();
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(context);
}

static CGContextRef canvas(int width, int height, int scale) {
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef result = CGBitmapContextCreate(NULL, width * scale, height * scale,
        8, width * scale * 4, color,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    assert(result);
    CGContextScaleCTM(result, scale, scale);
    CGContextSetShouldAntialias(result, false);
    return result;
}

static void white(CGContextRef context, int width, int height) {
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
}

static void paint(CGContextRef context, int width, int height, int top,
    double scroll, int scale) {
    double canvas_height = CGBitmapContextGetHeight(context) / (double)scale;
    double bottom = canvas_height - top - height;
    white(context, width, canvas_height);
    // Asymmetric per-device-row colors catch reversed copies, density and
    // chrome-coordinate errors. The translucent overlays exercise old thumb
    // removal as well as changes in position and fade opacity.
    for (int row = 0; row < height * scale; ++row) {
        long source = lround(scroll * scale) + row;
        CGContextSetRGBFillColor(context, (source % 83) / 83.0,
            (source % 47) / 47.0, (source % 31) / 31.0, 1);
        CGContextFillRect(context, CGRectMake(0, bottom + height - (row + 1.0) / scale,
            width, 1.0 / scale));
    }
    CGContextFlush(context);
}

static void overlays(CGContextRef context, int width, int height, int top,
    double scroll, int scale, double opacity) {
    double bottom = CGBitmapContextGetHeight(context) / (double)scale - top - height;
    CGContextSetRGBFillColor(context, 0, 0, 0, opacity);
    CGContextFillRect(context, CGRectMake(width - 9, bottom + fmod(scroll, height - 20), 6, 20));
    CGContextFillRect(context, CGRectMake(fmod(scroll, width - 20), bottom + 2, 20, 6));
    CGContextFlush(context);
}

static void frame(int width, int height, int top, int scale, double scroll,
    uint64_t owner, uint64_t revision, int eligible, int expected_reuse, double opacity) {
    int canvas_height = height + top + 13;
    CGContextRef actual = canvas(width + canvas_extra_width, canvas_height, scale);
    CGContextRef expected = canvas(width + canvas_extra_width, canvas_height, scale);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    const char *disable_damage = getenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS");
    if (disable_damage && *disable_damage)
        white(actual, width + canvas_extra_width, canvas_height);
    double delta = 0;
    double previous_scroll = native_scroll_raster.scroll;
    // The browser allows reuse only when its content diff reconciles the
    // retained frame; unchanged content at an unchanged revision reconciles.
    static uint64_t last_revision, last_owner;
    int allow_reuse = native_scroll_raster.valid && last_revision == revision
        && last_owner == owner;
    last_revision = revision; last_owner = owner;
    assert(native_begin_scroll_raster(owner, revision, scroll, top, width, height,
        eligible, &delta, NULL, 0, allow_reuse, 1) == expected_reuse);
    if (native_scroll_raster.active) {
        size_t stored_rows = native_scroll_raster.damage_optimized && expected_reuse
            ? (size_t)llround(fabs(scroll - previous_scroll) * scale) : height * scale;
        assert(native_scroll_raster.dirty_rows == stored_rows);
        assert(native_scroll_raster.row_origin < native_scroll_raster.height);
    }
    white(actual, width + canvas_extra_width, canvas_height);
    paint(actual, width, height, top, scroll, scale);
    native_end_scroll_raster();
    overlays(actual, width, height, top, scroll, scale, opacity);
    white(expected, width + canvas_extra_width, canvas_height);
    paint(expected, width, height, top, scroll, scale);
    overlays(expected, width, height, top, scroll, scale, opacity);
    assert(CGBitmapContextGetBytesPerRow(actual) == CGBitmapContextGetBytesPerRow(expected));
    assert(memcmp(CGBitmapContextGetData(actual), CGBitmapContextGetData(expected),
        CGBitmapContextGetBytesPerRow(actual) * CGBitmapContextGetHeight(actual)) == 0);
    assert(native_scroll_raster.bytes <= 64 * 1024 * 1024);
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(actual);
    CGContextRelease(expected);
}

// A solid patch stands in for content that changed in place (a new video
// frame, a script-driven transform) while the rest of the viewport did not.
static void patch(CGContextRef context, int height, int top, double x, double y,
    double w, double h, int scale) {
    double canvas_height = CGBitmapContextGetHeight(context) / (double)scale;
    double bottom = canvas_height - top - height;
    CGContextSetRGBFillColor(context, 0.1, 0.9, 0.3, 1);
    CGContextFillRect(context, CGRectMake(x, bottom + height - (y + h), w, h));
    CGContextFlush(context);
}

static void compare_and_release(CGContextRef actual, CGContextRef expected) {
    assert(CGBitmapContextGetBytesPerRow(actual) == CGBitmapContextGetBytesPerRow(expected));
    assert(memcmp(CGBitmapContextGetData(actual), CGBitmapContextGetData(expected),
        CGBitmapContextGetBytesPerRow(actual) * CGBitmapContextGetHeight(actual)) == 0);
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(actual);
    CGContextRelease(expected);
}

// Stands in for a translucent video frame with antialiased rounded corners,
// whose pixels depend on what is painted beneath it.
static void video_stand_in(CGContextRef context, int height, int top, double scroll,
    int scale, int frame_number) {
    double canvas_height = CGBitmapContextGetHeight(context) / (double)scale;
    double bottom = canvas_height - top - height;
    double y = 140.25 - scroll;
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context, true);
    CGContextSetRGBFillColor(context, (frame_number * 37 % 101) / 101.0, 0.4,
        (frame_number * 53 % 89) / 89.0, 0.6);
    CGPathRef path = CGPathCreateWithRoundedRect(
        CGRectMake(20.25, bottom + height - (y + 39.5), 59.5, 39.5), 6, 6, NULL);
    CGContextAddPath(context, path);
    CGContextFillPath(context);
    CGPathRelease(path);
    CGContextRestoreGState(context);
    CGContextFlush(context);
}

static void compare_viewport_and_release(CGContextRef actual, CGContextRef expected,
    int height, int top, int scale) {
    size_t pitch = CGBitmapContextGetBytesPerRow(actual);
    assert(pitch == CGBitmapContextGetBytesPerRow(expected));
    const uint8_t *a = CGBitmapContextGetData(actual), *e = CGBitmapContextGetData(expected);
    assert(memcmp(a + (size_t)top * scale * pitch, e + (size_t)top * scale * pitch,
        (size_t)height * scale * pitch) == 0);
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(actual);
    CGContextRelease(expected);
}

// One frame of a page whose video advanced. A reused frame with a ready
// backdrop paints only the strip beneath it (the rest of the video rectangle
// holds stale pixels here), restores the backdrop and draws the new frame.
// `draw_video` 2 replays the video without capturing, as when another video
// restores in the same frame.
static void video_frame(int scale, double scroll, int frame_number, int allow_reuse,
    int expect_reuse, int expect_ready, int draw_video) {
    int width = 120, height = 100, top = 9, canvas_height = height + top + 13;
    const double document[4] = {16, 136, 68, 48};
    double damage[4] = {document[0], document[1] - scroll, document[2], document[3]};
    CGContextRef actual = canvas(width, canvas_height, scale);
    CGContextRef expected = canvas(width, canvas_height, scale);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    int ready = native_video_backdrop_ready(5, scroll, document[0], document[1],
        document[2], document[3]);
    assert(ready == expect_ready);
    double delta = 0;
    int reused = native_begin_scroll_raster(5, 1, scroll, top, width, height, 1, &delta,
        damage, 1, allow_reuse, 1);
    assert(reused == expect_reuse);
    white(actual, width, canvas_height);
    paint(actual, width, height, top, scroll, scale);
    if (draw_video) {
        if (draw_video == 2) {
            native_video_backdrop_invalidate(document[0], document[1], document[2], document[3]);
        } else if (reused && ready) {
            // Commands skipped beneath the video leave arbitrary pixels.
            patch(actual, height, top, 30, 140 - scroll, 30, 30, scale);
            assert(native_video_backdrop_restore(actual, document[0], document[1],
                document[2], document[3]));
        } else {
            native_video_backdrop_capture(actual, document[0], document[1],
                document[2], document[3]);
        }
        video_stand_in(actual, height, top, scroll, scale, frame_number);
    }
    native_end_scroll_raster();
    white(expected, width, canvas_height);
    paint(expected, width, height, top, scroll, scale);
    if (draw_video) video_stand_in(expected, height, top, scroll, scale, frame_number);
    compare_viewport_and_release(actual, expected, height, top, scale);
}

static void test_video_backdrop_composites_new_frames_exactly(int scale) {
    native_discard_scroll_raster();
    video_frame(scale, 100, 0, 0, 0, 0, 1);
    video_frame(scale, 100, 1, 1, 1, 1, 1);
    // Scrolling keeps rows that stay visible; a partly visible video restores
    // only its visible rows.
    video_frame(scale, 104, 2, 1, 1, 1, 1);
    video_frame(scale, 160, 3, 1, 1, 1, 1);
    // Rows that left the viewport may have changed unseen; they return through
    // the exposed strip and must be captured again first.
    video_frame(scale, 100, 4, 1, 1, 0, 1);
    video_frame(scale, 100, 5, 1, 1, 1, 1);
    // A complete repaint invalidates every row, then captures the visible ones.
    video_frame(scale, 100, 6, 0, 0, 1, 1);
    video_frame(scale, 100, 7, 1, 1, 1, 1);
    video_frame(scale, 100, 8, 0, 0, 1, 0);
    video_frame(scale, 100, 9, 1, 1, 0, 1);
    // Rows repainted beneath a video that did not capture are stale.
    video_frame(scale, 100, 10, 1, 1, 1, 2);
    video_frame(scale, 100, 11, 1, 1, 0, 1);
    video_frame(scale, 100, 12, 1, 1, 1, 1);
    // A fractional device-pixel scroll cannot anchor rows to the document.
    if (scale == 1) assert(!native_video_backdrop_ready(5, 100.5, 16, 136, 68, 48));
    // Another document, or a discarded ring, has no backdrop.
    assert(!native_video_backdrop_ready(6, 100, 16, 136, 68, 48));
    native_discard_scroll_raster();
    assert(!native_video_backdrop_ready(5, 100, 16, 136, 68, 48));
}

// A changed content revision reconciled into damage rectangles repaints only
// those rectangles, the retained patch then scrolls with the document, and a
// revision change without reconciliation still forces complete replay.
static void test_damage_rects_repaint_only_changed_content(int scale) {
    int width = 161, height = 121, top = 9;
    int canvas_height = height + top + 13;
    native_discard_scroll_raster();
    frame(width, height, top, scale, 100, 3, 1, 1, 0, 0);
    double rect[4] = {40, 30, 50, 20};
    CGContextRef actual = canvas(width, canvas_height, scale);
    CGContextRef expected = canvas(width, canvas_height, scale);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    double delta = 1;
    assert(native_begin_scroll_raster(3, 2, 100, top, width, height, 1, &delta, rect, 1, 1, 1) == 1);
    assert(delta == 0);
    // Only the damaged rows return to the ring; there is no exposed strip.
    assert(native_scroll_raster.dirty_rows == 0);
    assert(native_scroll_raster.damage_row_count == 1);
    assert(native_scroll_raster.damage_rows[0][0] == (size_t)(30 * scale));
    assert(native_scroll_raster.damage_rows[0][1] == (size_t)(20 * scale));
    white(actual, width, canvas_height);
    paint(actual, width, height, top, 100, scale);
    patch(actual, height, top, 40, 30, 50, 20, scale);
    // Writes outside the damage rectangle must be clipped away.
    patch(actual, height, top, 0, 0, 10, 10, scale);
    native_end_scroll_raster();
    overlays(actual, width, height, top, 100, scale, 0.5);
    white(expected, width, canvas_height);
    paint(expected, width, height, top, 100, scale);
    patch(expected, height, top, 40, 30, 50, 20, scale);
    overlays(expected, width, height, top, 100, scale, 0.5);
    compare_and_release(actual, expected);

    actual = canvas(width, canvas_height, scale);
    expected = canvas(width, canvas_height, scale);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    assert(native_begin_scroll_raster(3, 2, 107, top, width, height, 1, &delta, NULL, 0, 1, 1) == 1);
    assert(delta == 7);
    white(actual, width, canvas_height);
    paint(actual, width, height, top, 107, scale);
    native_end_scroll_raster();
    overlays(actual, width, height, top, 107, scale, 0.5);
    white(expected, width, canvas_height);
    paint(expected, width, height, top, 107, scale);
    patch(expected, height, top, 40, 23, 50, 20, scale);
    overlays(expected, width, height, top, 107, scale, 0.5);
    compare_and_release(actual, expected);

    actual = canvas(width, canvas_height, scale);
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:
        [NSGraphicsContext graphicsContextWithCGContext:actual flipped:NO]];
    assert(native_begin_scroll_raster(3, 3, 114, top, width, height, 1, &delta, NULL, 0, 0, 1) == 0);
    native_end_scroll_raster();
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(actual);
    native_discard_scroll_raster();
}

int main(void) {
    @autoreleasepool {
        for (int scale = 1; scale <= 2; ++scale) {
            native_discard_scroll_raster();
            frame(160, 120, 8, scale, 0, 1, 1, 1, 0, 0);
            for (int scroll = 7; scroll <= 70; scroll += 7)
                frame(160, 120, 8, scale, scroll, 1, 1, 1, 1, 0.7);
            for (int scroll = 63; scroll >= 0; scroll -= 7)
                frame(160, 120, 8, scale, scroll, 1, 1, 1, 1, 0.3);
            frame(160, 120, 8, scale, 0, 1, 1, 1, 1, 0);
            frame(160, 120, 8, scale, 7, 1, 2, 1, 0, 0.5);
            frame(160, 120, 8, scale, 14, 2, 2, 1, 0, 0.5);
            frame(161, 120, 8, scale, 21, 2, 2, 1, 0, 0.5);
            frame(161, 121, 8, scale, 28, 2, 2, 1, 0, 0.5);
            frame(161, 121, 9, scale, 35, 2, 2, 1, 0, 0.5);
            frame(161, 121, 9, scale, 350, 2, 2, 1, 0, 0.5);
            frame(161, 121, 9, scale, 357.25, 2, 2, 1, 0, 0.5);
            frame(161, 121, 9, scale, 364.25, 2, 2, 1, 1, 0.5);
            frame(161, 121, 9, scale, 371.25, 2, 2, 0, 0, 0.5);
            assert(!native_scroll_raster.pixels);
            frame(161, 121, 9, scale, 378.25, 2, 2, 1, 0, 0.5);
            setenv("VOX_DISABLE_SCROLL_RASTER_REUSE", "1", 1);
            frame(161, 121, 9, scale, 385.25, 2, 2, 1, 0, 0.5);
            assert(!native_scroll_raster.pixels);
            unsetenv("VOX_DISABLE_SCROLL_RASTER_REUSE");
            frame(161, 121, 9, scale, 392.25, 2, 2, 1, 0, 0.5);
            // Wrap the ring repeatedly in either direction, including partial
            // viewport widths where the canvas pitch exceeds a cache row.
            for (int padded = 0; padded < 2; ++padded) {
                canvas_extra_width = padded ? 17 : 0;
                native_discard_scroll_raster();
                frame(161, 121, 9, scale, 0, 2, 2, 1, 0, 0);
                for (int scroll = 60; scroll <= 600; scroll += 60)
                    frame(161, 121, 9, scale, scroll, 2, 2, 1, 1, 0.5);
                for (int scroll = 540; scroll >= 0; scroll -= 60)
                    frame(161, 121, 9, scale, scroll, 2, 2, 1, 1, 0.3);
                frame(161, 121, 9, scale, 0, 2, 2, 1, 1, 0);
                frame(161, 121, 9, scale, 120, 2, 2, 1, 1, 0.5);
                frame(161, 121, 9, scale, 121, 2, 2, 1, 1, 0.5);
                frame(161, 121, 9, scale, 242, 2, 2, 1, 0, 0.5);
                setenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS", "1", 1);
                frame(161, 121, 9, scale, 243, 2, 2, 1, 0, 0.5);
                frame(161, 121, 9, scale, 244, 2, 2, 1, 1, 0.5);
                unsetenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS");
                frame(161, 121, 9, scale, 245, 2, 2, 1, 0, 0.5);
                frame(161, 121, 9, scale, 246, 2, 2, 1, 1, 0.5);
                setenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS", "", 1);
                frame(161, 121, 9, scale, 247, 2, 2, 1, 1, 0.5);
                unsetenv("VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS");
            }
            canvas_extra_width = 0;
        }
        // A density change must not shift pixels from a different device grid.
        frame(161, 121, 9, 1, 399.25, 2, 2, 1, 0, 0.5);
        CGContextRef translated = canvas(161, 130, 1);
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:
            [NSGraphicsContext graphicsContextWithCGContext:translated flipped:NO]];
        CGContextTranslateCTM(translated, 1, 0);
        double delta = 0;
        assert(!native_begin_scroll_raster(2, 2, 406.25, 9, 161, 121, 1, &delta, NULL, 0, 1, 1));
        assert(!native_scroll_raster.pixels);
        [NSGraphicsContext restoreGraphicsState];
        CGContextRelease(translated);
        native_discard_scroll_raster();
        test_independent_image_pixels_are_not_reused();
        for (int scale = 1; scale <= 2; ++scale)
            test_damage_rects_repaint_only_changed_content(scale);
        for (int scale = 1; scale <= 2; ++scale)
            test_video_backdrop_composites_new_frames_exactly(scale);
        test_redraw_survives_layer_display();
        test_completed_frame_covers_queued_redraw();
        puts("Scroll raster: exact pixels across scroll direction, overlay fades, revision, navigation, resize, density and fallback");
    }
}
