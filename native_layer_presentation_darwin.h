#ifndef VOX_NATIVE_LAYER_PRESENTATION_DARWIN_H
#define VOX_NATIVE_LAYER_PRESENTATION_DARWIN_H
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdint.h>

static IMP native_layer_original_draw;
static IMP native_layer_original_move;
static IMP native_layer_original_backing;
static IMP native_layer_original_frame_size;
static IMP native_layer_original_parent_draw;
static IMP native_layer_original_parent_update;
static IMP native_layer_original_parent_wants_update;
static CGFloat native_layer_capture_scale;
static BOOL native_layer_presenting;
static BOOL native_layer_document_work_active;
// Main-thread redraw deliveries, distinct from merely servicing the run loop.
static uint64_t native_layer_redraw_generation;

static BOOL native_layer_is_browser_view(NSView *view) {
    Class browser = NSClassFromString(@"MyView2");
    return browser && [view isKindOfClass:browser];
}

static BOOL native_layer_has_browser_child(NSView *view) {
    for (NSView *child in view.subviews) {
        if (native_layer_is_browser_view(child) || native_layer_has_browser_child(child))
            return YES;
    }
    return NO;
}

static CGFloat native_layer_effective_scale(NSView *view) {
    CGFloat scale = native_layer_capture_scale > 0
        ? native_layer_capture_scale : view.window.backingScaleFactor;
    return isfinite(scale) && scale > 0 ? scale : 1;
}

// The image owns its bitmap storage after the temporary CGContext is released.
// A complete immutable frame becomes one Core Animation image, avoiding Quartz
// uploading and retaining a separate texture for each Skia primitive.
static CGImageRef native_layer_raster_frame(NSView *view, CGFloat scale, IMP draw) {
    NSRect bounds = view.bounds;
    if (!draw || !isfinite(scale) || scale <= 0
        || !isfinite(bounds.size.width) || !isfinite(bounds.size.height)
        || bounds.size.width <= 0 || bounds.size.height <= 0) return NULL;
    double pixel_width = ceil(bounds.size.width * scale);
    double pixel_height = ceil(bounds.size.height * scale);
    if (pixel_width > 16384 || pixel_height > 16384) return NULL;
    size_t width = (size_t)pixel_width, height = (size_t)pixel_height;
    if (!width || !height || width > SIZE_MAX / 4 / height) return NULL;
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef bitmap = CGBitmapContextCreate(NULL, width, height, 8, width * 4,
        color, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(color);
    if (!bitmap) return NULL;
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    CGImageRef image = NULL;
    @try {
        NSGraphicsContext.currentContext = [NSGraphicsContext
            graphicsContextWithCGContext:bitmap flipped:view.isFlipped];
        ((void (*)(id, SEL, NSRect))draw)(view, @selector(drawRect:), bounds);
        image = CGBitmapContextCreateImage(bitmap);
    } @finally {
        NSGraphicsContext.currentContext = previous;
        CGContextRelease(bitmap);
    }
    return image;
}

static void native_layer_present_frame(NSView *view, CGFloat scale, IMP draw) {
    CGImageRef image = native_layer_raster_frame(view, scale, draw);
    if (!image) return;
    // Disable implicit content/scale animations: an old frame must not be
    // retained for a cross-fade when navigation, selection or scrolling paints.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    view.layer.opaque = YES;
    view.layer.contentsGravity = kCAGravityResize;
    view.layer.contentsScale = scale;
    view.layer.contents = (__bridge id)image;
    [CATransaction commit];
    CGImageRelease(image);
}

static BOOL native_layer_wants_update(id self, SEL command) {
    (void)self; (void)command;
    return YES;
}

static void native_layer_update(id self, SEL command) {
    (void)command;
    if (native_layer_presenting || native_layer_document_work_active) return;
    native_layer_presenting = YES;
    @try {
    @autoreleasepool {
        native_layer_present_frame(self, native_layer_effective_scale(self),
            native_layer_original_draw);
    }
    } @finally {
        native_layer_presenting = NO;
    }
}

static void native_layer_moved_to_window(id self, SEL command) {
    if (native_layer_original_move)
        ((void (*)(id, SEL))native_layer_original_move)(self, command);
    NSView *view = self;
    // Frames are rasterized in sRGB. Matching the window's color space lets the
    // window server color-match on the GPU; otherwise Core Animation converts
    // every complete frame to the display's space on the CPU before commit.
    if (view.window) view.window.colorSpace = NSColorSpace.sRGBColorSpace;
    view.wantsLayer = YES;
    view.layer.opaque = YES;
    view.layer.contentsGravity = kCAGravityResize;
    view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
    view.needsDisplay = YES;
}

static void native_layer_backing_changed(id self, SEL command) {
    if (native_layer_original_backing)
        ((void (*)(id, SEL))native_layer_original_backing)(self, command);
    ++native_layer_redraw_generation;
    [(NSView *)self setNeedsDisplay:YES];
}

static void native_layer_frame_size_changed(id self, SEL command, NSSize size) {
    NSSize previous = [(NSView *)self frame].size;
    if (native_layer_original_frame_size)
        ((void (*)(id, SEL, NSSize))native_layer_original_frame_size)(self, command, size);
    if (!NSEqualSizes(previous, size)) {
        ++native_layer_redraw_generation;
        [(NSView *)self setNeedsDisplay:YES];
    }
}

static BOOL native_layer_parent_wants_update(id self, SEL command) {
    if (native_layer_has_browser_child(self)) return YES;
    return native_layer_original_parent_wants_update
        ? ((BOOL (*)(id, SEL))native_layer_original_parent_wants_update)(self, command)
        : NO;
}

static void native_layer_parent_update(id self, SEL command) {
    if (!native_layer_has_browser_child(self)) {
        if (native_layer_original_parent_update)
            ((void (*)(id, SEL))native_layer_original_parent_update)(self, command);
        return;
    }
    // The Sokol parent still owns display timing and pending window closure.
    // Its native branch skips the V frame; only the Cocoa child paints it.
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    @try {
        NSGraphicsContext.currentContext = nil;
        if (native_layer_original_parent_draw)
            ((void (*)(id, SEL, NSRect))native_layer_original_parent_draw)(self,
                @selector(drawRect:), [(NSView *)self bounds]);
    } @finally {
        NSGraphicsContext.currentContext = previous;
    }
}

static IMP native_layer_replace_method(Class klass, SEL selector, IMP replacement,
    const char *fallback_encoding) {
    Method method = class_getInstanceMethod(klass, selector);
    IMP previous = method ? method_getImplementation(method) : NULL;
    const char *encoding = method ? method_getTypeEncoding(method) : fallback_encoding;
    if (!class_addMethod(klass, selector, replacement, encoding))
        class_replaceMethod(klass, selector, replacement, encoding);
    return previous;
}

static void native_install_browser_layer_presentation(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class browser = NSClassFromString(@"MyView2");
        Class parent = NSClassFromString(@"_sapp_macos_view");
        if (!browser || !parent) return;
        native_layer_original_draw = method_getImplementation(
            class_getInstanceMethod(browser, @selector(drawRect:)));
        native_layer_original_move = native_layer_replace_method(browser,
            @selector(viewDidMoveToWindow), (IMP)native_layer_moved_to_window, "v@:");
        native_layer_original_backing = native_layer_replace_method(browser,
            @selector(viewDidChangeBackingProperties), (IMP)native_layer_backing_changed, "v@:");
        native_layer_original_frame_size = native_layer_replace_method(browser,
            @selector(setFrameSize:), (IMP)native_layer_frame_size_changed, "v@:{CGSize=dd}");
        native_layer_replace_method(browser, @selector(wantsUpdateLayer),
            (IMP)native_layer_wants_update, "B@:");
        native_layer_replace_method(browser, @selector(updateLayer),
            (IMP)native_layer_update, "v@:");
        native_layer_original_parent_draw = method_getImplementation(
            class_getInstanceMethod(parent, @selector(drawRect:)));
        native_layer_original_parent_wants_update = native_layer_replace_method(parent,
            @selector(wantsUpdateLayer), (IMP)native_layer_parent_wants_update, "B@:");
        native_layer_original_parent_update = native_layer_replace_method(parent,
            @selector(updateLayer), (IMP)native_layer_parent_update, "v@:");
    });
}

static void native_layer_prepare_capture(NSView *view, BOOL render) {
    if (native_layer_is_browser_view(view)) {
        if (render) native_layer_update(view, @selector(updateLayer));
        else view.needsDisplay = YES;
    }
    for (NSView *child in view.subviews) native_layer_prepare_capture(child, render);
}

// Cooperative document work can service main-queue timers while an old frame
// remains presented. Capture only after that work and any layer draw finish,
// so the logical-resolution redraw below cannot reuse a backing-scale image.
static void native_when_document_work_idle(dispatch_block_t capture) {
    if (native_layer_document_work_active || native_layer_presenting) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC),
            dispatch_get_main_queue(), ^{
                native_when_document_work_idle(capture);
            });
        return;
    }
    capture();
}

// Both screenshot entry points use this scoped override. AppKit's ordinary
// NSView capture API remains unchanged for every other application/view.
static void native_cache_display_in_bitmap(NSView *view, NSRect bounds,
    NSBitmapImageRep *bitmap) {
    CGFloat previous = native_layer_capture_scale;
    CGFloat scale_x = bounds.size.width > 0 ? bitmap.pixelsWide / bounds.size.width : 1;
    CGFloat scale_y = bounds.size.height > 0 ? bitmap.pixelsHigh / bounds.size.height : 1;
    native_layer_capture_scale = fmax(scale_x, scale_y);
    @try {
        native_layer_prepare_capture(view, YES);
        [view cacheDisplayInRect:bounds toBitmapImageRep:bitmap];
    } @finally {
        native_layer_capture_scale = previous;
        native_layer_prepare_capture(view, NO);
    }
}
#endif
