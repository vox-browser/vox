#ifndef VOX_NATIVE_LAYER_PRESENTATION_TEST_DARWIN_H
#define VOX_NATIVE_LAYER_PRESENTATION_TEST_DARWIN_H
#include "native_layer_presentation_darwin.h"
#include <string.h>

// Offscreen views have no compositor to acknowledge a completed display.
// Control that acknowledgement explicitly for the frame-validity contract.
@interface NativeLayerFrameTestView : NSView { BOOL test_needs_display; }
@end
@implementation NativeLayerFrameTestView
- (BOOL)needsDisplay { return test_needs_display; }
- (void)setNeedsDisplay:(BOOL)value { test_needs_display = value; }
@end

static NSUInteger native_layer_test_draws;
static NSUInteger native_layer_test_parent_calls;
static BOOL native_layer_test_parent_had_no_context;
static void (*native_layer_test_frame_callback)(void *);
static void *native_layer_test_frame_target;
static void native_layer_test_draw(id self, SEL command, NSRect rect) {
    (void)self; (void)command;
    native_layer_test_draws++;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, rect);
    CGContextSetRGBFillColor(context, 0, 1, 0, 1);
    CGContextFillRect(context, CGRectMake(NSMidX(rect), rect.origin.y,
        rect.size.width / 2, rect.size.height));
}
static void native_layer_test_throw(id self, SEL command, NSRect rect) {
    (void)self; (void)command; (void)rect;
    [NSException raise:@"NativeLayerTest" format:@"context restoration"];
}
static void native_layer_test_asymmetric_draw(id self, SEL command, NSRect rect) {
    native_layer_test_draw(self, command, rect);
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, 0, 0, 1, 1);
    CGContextFillRect(context, NSMakeRect(rect.origin.x, NSMidY(rect), rect.size.width / 2,
        rect.size.height / 2));
}

static int native_test_capture_copy_preserves_pixels_and_skips_redundant_frames(void) {
    @autoreleasepool {
        NSView *view = [[NativeLayerFrameTestView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        view.wantsLayer = YES;
        IMP original = native_layer_original_draw;
        BOOL previous_copying = native_layer_copying_capture;
        uint64_t generation = native_layer_redraw_generation;
        NSGraphicsContext *previous = NSGraphicsContext.currentContext;
        CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef target = CGBitmapContextCreate(NULL, 4, 2, 8, 16, color,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(color);
        int result = 0;
        @try {
            native_layer_test_draws = 0;
            native_layer_original_draw = (IMP)native_layer_test_asymmetric_draw;
            native_layer_present_frame(view, 1, native_layer_original_draw);
            view.needsDisplay = NO;
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:target flipped:NO];
            native_layer_copying_capture = YES;
            native_layer_draw(view, @selector(drawRect:), view.bounds);
            if (native_layer_test_draws == 1) result |= 1;
            CGImageRef image = CGBitmapContextCreateImage(target);
            CFDataRef expected = CGDataProviderCopyData(CGImageGetDataProvider((__bridge CGImageRef)view.layer.contents));
            CFDataRef actual = CGDataProviderCopyData(CGImageGetDataProvider(image));
            if (CFDataGetLength(expected) == CFDataGetLength(actual)
                && !memcmp(CFDataGetBytePtr(expected), CFDataGetBytePtr(actual), CFDataGetLength(expected)))
                result |= 2;
            CFRelease(expected); CFRelease(actual); CGImageRelease(image);
            view.needsDisplay = YES;
            native_layer_update(view, @selector(updateLayer));
            if (native_layer_test_draws == 1) result |= 4;
            ++native_layer_redraw_generation;
            native_layer_draw(view, @selector(drawRect:), view.bounds);
            if (native_layer_test_draws == 2) result |= 8;
            native_layer_copying_capture = NO;
            native_layer_draw(view, @selector(drawRect:), view.bounds);
            if (native_layer_test_draws == 3) result |= 16;
        } @finally {
            native_layer_copying_capture = previous_copying;
            native_layer_original_draw = original;
            native_layer_redraw_generation = generation;
            NSGraphicsContext.currentContext = previous;
            CGContextRelease(target);
        }
#if !__has_feature(objc_arc)
        [view release];
#endif
        return result;
    }
}
static void native_layer_test_invalidating_draw(id self, SEL command, NSRect rect) {
    native_layer_test_draw(self, command, rect);
    ++native_layer_redraw_generation;
}
static void native_layer_test_moving_draw(id self, SEL command, NSRect rect) {
    native_layer_test_draw(self, command, rect);
    NSView *view = self;
    NSRect bounds = view.bounds;
    bounds.origin.x += 1;
    view.bounds = bounds;
}
static void native_layer_test_preparing_draw(id self, SEL command, NSRect rect) {
    ++native_layer_redraw_generation;
    vox_browser_frame_prepared();
    native_layer_test_draw(self, command, rect);
}
static void native_layer_test_invalidating_paint(id self, SEL command, NSRect rect) {
    vox_browser_frame_prepared();
    native_layer_test_invalidating_draw(self, command, rect);
}
static void native_layer_test_parent(id self, SEL command, NSRect rect) {
    (void)self; (void)command; (void)rect;
    native_layer_test_parent_calls++;
    native_layer_test_parent_had_no_context = NSGraphicsContext.currentContext == nil;
    if (native_layer_test_frame_callback)
        native_layer_test_frame_callback(native_layer_test_frame_target);
}

static int native_test_parent_tick_frame_ownership(void (*frame)(void *), void *target) {
    @autoreleasepool {
        Class browser = NSClassFromString(@"MyView2");
        if (!browser) return 0;
        NSView *parent = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        NSView *child = [[browser alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        [parent addSubview:child];
        IMP original = native_layer_original_parent_draw;
        NSGraphicsContext *previous = NSGraphicsContext.currentContext;
        native_layer_original_parent_draw = (IMP)native_layer_test_parent;
        native_layer_test_frame_callback = frame;
        native_layer_test_frame_target = target;
        int result = 0;
        @try {
            native_layer_parent_update(parent, @selector(updateLayer));
            if (native_layer_test_parent_had_no_context
                && NSGraphicsContext.currentContext == previous) result |= 1;
            CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
            CGContextRef bitmap = CGBitmapContextCreate(NULL, 4, 2, 8, 16, color,
                kCGImageAlphaPremultipliedLast);
            CGColorSpaceRelease(color);
            NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:bitmap flipped:NO];
            if (vox_browser_has_paint_context()) result |= 2;
            NSGraphicsContext.currentContext = nil;
            if (!vox_browser_has_paint_context()) result |= 4;
            CGContextRelease(bitmap);
        } @finally {
            NSGraphicsContext.currentContext = previous;
            native_layer_original_parent_draw = original;
            native_layer_test_frame_callback = NULL;
            native_layer_test_frame_target = NULL;
        }
#if !__has_feature(objc_arc)
        [child release]; [parent release];
#endif
        return result;
    }
}
static BOOL native_layer_test_image(CGImageRef image, size_t width, size_t height) {
    if (!image || CGImageGetWidth(image) != width || CGImageGetHeight(image) != height)
        return NO;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
    if (!data) return NO;
    const UInt8 *bytes = CFDataGetBytePtr(data);
    size_t row = CGImageGetBytesPerRow(image);
    BOOL correct = CFDataGetLength(data) >= row * height;
    for (size_t y = 0; correct && y < height; y++) {
        for (size_t x = 0; x < width; x++) {
            const UInt8 *pixel = bytes + y * row + x * 4;
            if (pixel[0] != (x < width / 2 ? 255 : 0)
                || pixel[1] != (x >= width / 2 ? 255 : 0)
                || pixel[2] != 0 || pixel[3] != 255) {
                correct = NO; break;
            }
        }
    }
    CFRelease(data);
    return correct;
}
static int native_test_layer_frame_scale_capture_and_callbacks(void) {
    @autoreleasepool {
        int result = 0;
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        view.bounds = NSMakeRect(3, 5, 4, 2);
        native_layer_test_draws = 0;
        NSGraphicsContext *previous = NSGraphicsContext.currentContext;
        CGImageRef first = native_layer_raster_frame(view, 1, (IMP)native_layer_test_draw);
        if (native_layer_test_image(first, 4, 2)) result |= 1;
        CGImageRef retina = native_layer_raster_frame(view, 2, (IMP)native_layer_test_draw);
        if (native_layer_test_image(retina, 8, 4)) result |= 2;
        if (native_layer_test_draws == 2 && NSGraphicsContext.currentContext == previous)
            result |= 4;
        view.wantsLayer = YES;
        native_layer_present_frame(view, 2, (IMP)native_layer_test_draw);
        if (view.layer.contentsScale == 2 && view.layer.opaque
            && native_layer_test_image((__bridge CGImageRef)view.layer.contents, 8, 4)
            && view.layer.animationKeys.count == 0) result |= 8;
        // A logical-pixel capture is a fresh 1x raster, never a downsample of
        // the previously presented Retina image. The source image remains owned.
        native_layer_present_frame(view, 1, (IMP)native_layer_test_draw);
        if (view.layer.contentsScale == 1
            && native_layer_test_image((__bridge CGImageRef)view.layer.contents, 4, 2)
            && native_layer_test_image(retina, 8, 4)) result |= 16;
        view.frame = NSMakeRect(0, 0, 6, 4);
        view.bounds = NSMakeRect(3, 5, 6, 4);
        CGImageRef resized = native_layer_raster_frame(view, 2, (IMP)native_layer_test_draw);
        if (native_layer_test_image(resized, 12, 8)) result |= 32;
        BOOL threw = NO;
        @try { native_layer_raster_frame(view, 1, (IMP)native_layer_test_throw); }
        @catch (NSException *exception) { threw = [exception.name isEqualToString:@"NativeLayerTest"]; }
        if (threw && NSGraphicsContext.currentContext == previous) result |= 64;
        if (!native_layer_raster_frame(view, NAN, (IMP)native_layer_test_draw)
            && !native_layer_raster_frame(view, 0, (IMP)native_layer_test_draw)
            && !native_layer_raster_frame(view, 100000, (IMP)native_layer_test_draw)) result |= 128;
        IMP cache = method_getImplementation(class_getInstanceMethod([NSView class],
            @selector(cacheDisplayInRect:toBitmapImageRep:)));
        native_install_browser_layer_presentation();
        if (method_getImplementation(class_getInstanceMethod([NSView class],
            @selector(cacheDisplayInRect:toBitmapImageRep:))) == cache) result |= 256;
        Class browser = NSClassFromString(@"MyView2");
        if (browser) {
            NSView *parent = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
            NSView *child = [[browser alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
            [parent addSubview:child];
            IMP original = native_layer_original_parent_draw;
            native_layer_original_parent_draw = (IMP)native_layer_test_parent;
            native_layer_test_parent_calls = 0;
            native_layer_parent_update(parent, @selector(updateLayer));
            native_layer_original_parent_draw = original;
            if (native_layer_test_parent_calls == 1 && native_layer_test_parent_had_no_context
                && NSGraphicsContext.currentContext == previous && child.superview == parent)
                result |= 512;
#if !__has_feature(objc_arc)
            [child release]; [parent release];
#endif
        }
        if (first) CGImageRelease(first);
        if (retina) CGImageRelease(retina);
        if (resized) CGImageRelease(resized);
#if !__has_feature(objc_arc)
        [view release];
#endif
        return result;
    }
}

static int native_test_layer_uses_document_capture_density(void) {
    @autoreleasepool {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        const char *delay = getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
        const char *scale = getenv("LADYBIRD_SCREENSHOT_SCALE");
        char *saved_delay = delay ? strdup(delay) : NULL;
        char *saved_scale = scale ? strdup(scale) : NULL;
        CGFloat previous = native_layer_capture_scale;
        native_layer_capture_scale = 0;
        setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "0", 1);
        unsetenv("LADYBIRD_SCREENSHOT_SCALE");
        int result = native_layer_effective_scale(view) == 1 ? 1 : 0;
        setenv("LADYBIRD_SCREENSHOT_SCALE", "2", 1);
        if (native_layer_effective_scale(view) == 2) result |= 2;
        native_layer_capture_scale = 1.5;
        if (native_layer_effective_scale(view) == 1.5) result |= 4;
        native_layer_capture_scale = 0;
        const char *invalid[] = {"0", "-1", ".5", "nan", "invalid"};
        for (size_t index = 0; index < sizeof(invalid) / sizeof(invalid[0]); ++index) {
            setenv("LADYBIRD_SCREENSHOT_SCALE", invalid[index], 1);
            if (native_layer_effective_scale(view) != 1) result |= 64;
        }
        if (!(result & 64)) result |= 8;
        unsetenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
        setenv("LADYBIRD_SCREENSHOT_SCALE", "2", 1);
        if (native_layer_effective_scale(view) == 1) result |= 16;
        native_layer_capture_scale = previous;
        if (saved_delay) { setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", saved_delay, 1); free(saved_delay); }
        else unsetenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
        if (saved_scale) { setenv("LADYBIRD_SCREENSHOT_SCALE", saved_scale, 1); free(saved_scale); }
        else unsetenv("LADYBIRD_SCREENSHOT_SCALE");
#if !__has_feature(objc_arc)
        [view release];
#endif
        return result;
    }
}

static int native_test_layer_capture_frame_invalidation(void) {
    @autoreleasepool {
        NSView *view = [[NativeLayerFrameTestView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        view.wantsLayer = YES;
        uint64_t previous = native_layer_redraw_generation;
        int result = 0;
        if (!native_layer_frame_is_current(view, 1)) result |= 1;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_draw);
        view.needsDisplay = NO;
        if (native_layer_frame_is_current(view, 1)) result |= 2;
        if (!native_layer_frame_is_current(view, 2)) result |= 4;
        view.needsDisplay = YES;
        if (!native_layer_frame_is_current(view, 1)) result |= 8;
        view.needsDisplay = NO;
        ++native_layer_redraw_generation;
        if (!native_layer_frame_is_current(view, 1)) result |= 16;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_draw);
        view.bounds = NSMakeRect(1, 0, 4, 2);
        view.needsDisplay = NO;
        if (!native_layer_frame_is_current(view, 1)) result |= 32;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_invalidating_draw);
        view.needsDisplay = NO;
        if (!native_layer_frame_is_current(view, 1)) result |= 64;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_moving_draw);
        view.needsDisplay = NO;
        if (!native_layer_frame_is_current(view, 1)) result |= 128;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_draw);
        view.needsDisplay = NO;
        native_layer_restore_frame_scale(view);
        if (!view.needsDisplay) result |= 256;
        native_layer_present_frame(view, 2, (IMP)native_layer_test_draw);
        view.needsDisplay = NO;
        native_layer_restore_frame_scale(view);
        if (view.needsDisplay) result |= 512;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_preparing_draw);
        view.needsDisplay = NO;
        if (native_layer_frame_is_current(view, 1)) result |= 1024;
        native_layer_present_frame(view, 1, (IMP)native_layer_test_invalidating_paint);
        view.needsDisplay = NO;
        if (!native_layer_frame_is_current(view, 1)) result |= 2048;
        native_layer_redraw_generation = previous;
#if !__has_feature(objc_arc)
        [view release];
#endif
        return result;
    }
}
#endif
