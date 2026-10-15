#ifndef VOX_NATIVE_LAYER_PRESENTATION_TEST_DARWIN_H
#define VOX_NATIVE_LAYER_PRESENTATION_TEST_DARWIN_H
#include "native_layer_presentation_darwin.h"

static NSUInteger native_layer_test_draws;
static NSUInteger native_layer_test_parent_calls;
static BOOL native_layer_test_parent_had_no_context;
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
static void native_layer_test_parent(id self, SEL command, NSRect rect) {
    (void)self; (void)command; (void)rect;
    native_layer_test_parent_calls++;
    native_layer_test_parent_had_no_context = NSGraphicsContext.currentContext == nil;
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
            if (pixel[0] != 0 || pixel[1] != (x >= width / 2 ? 255 : 0)
                || pixel[2] != (x < width / 2 ? 255 : 0) || pixel[3] != 255) {
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
#endif
