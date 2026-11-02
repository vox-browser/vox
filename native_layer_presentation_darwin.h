#ifndef VOX_NATIVE_LAYER_PRESENTATION_DARWIN_H
#define VOX_NATIVE_LAYER_PRESENTATION_DARWIN_H
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdint.h>
#include "native_document_submission_darwin.h"
#include "native_initial_document_clear.h"
#include "native_frame_snapshot_darwin.h"
#if defined(__aarch64__)
#include <arm_neon.h>
#endif

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
static BOOL native_layer_copying_capture;
// Main-thread redraw deliveries, distinct from merely servicing the run loop.
static uint64_t native_layer_redraw_generation;
static uint64_t native_layer_paint_generation;
static uint64_t native_layer_last_prepared_generation;
static BOOL native_layer_paint_started;
static char native_layer_frame_generation_key;
static char native_layer_frame_bounds_key;

// This surface exists only during one native frame callback. The enclosing
// document canvas claims it before any pixels are painted; nested canvases
// and later layers retain ordinary source-over compositing.
static CGContextRef native_layer_document_bitmap;
static BOOL native_layer_document_bitmap_claimed;
static VoxInitialDocumentClear native_layer_initial_document_clear;

static BOOL native_layer_claim_document_bitmap(CGContextRef context) {
    if (!context || context != native_layer_document_bitmap
        || native_layer_document_bitmap_claimed) return NO;
    native_layer_document_bitmap_claimed = YES;
    return YES;
}

// The enclosing document layer claims this private frame before its first
// paint. Its destination retains the initial full clip and graphics state;
// only the separate source canvas is painted while that claim is active.
// Fuse format conversion and publication when image drawing would be an
// aligned, full-bitmap copy. Filters and all other placements use Quartz.
static BOOL native_layer_copy_document_bitmap(CGContextRef source,
    CGContextRef destination, CGFloat canvas_width, CGFloat canvas_height) {
    if (!source || !destination || source == destination
        || destination != native_layer_document_bitmap
        || !native_layer_document_bitmap_claimed) return NO;
    size_t width = CGBitmapContextGetWidth(destination);
    size_t height = CGBitmapContextGetHeight(destination);
    CGAffineTransform ctm = CGContextGetCTM(destination);
    if (!width || !height || !isfinite(canvas_width) || !isfinite(canvas_height)
        || canvas_width <= 0 || canvas_height <= 0
        || ctm.a <= 0 || ctm.d <= 0 || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0
        || canvas_width * ctm.a != (CGFloat)width
        || canvas_height * ctm.d != (CGFloat)height
        || CGBitmapContextGetWidth(source) != width
        || CGBitmapContextGetHeight(source) != height
        || CGBitmapContextGetBitsPerComponent(source) != 8
        || CGBitmapContextGetBitsPerPixel(source) != 32
        || CGBitmapContextGetBitmapInfo(source) !=
            (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)
        || CGBitmapContextGetBitsPerComponent(destination) != 8
        || CGBitmapContextGetBitsPerPixel(destination) != 32
        || CGBitmapContextGetBitmapInfo(destination) !=
            (kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little)) return NO;
    CGColorSpaceRef source_color = CGBitmapContextGetColorSpace(source);
    CGColorSpaceRef destination_color = CGBitmapContextGetColorSpace(destination);
    if (!source_color || !destination_color || !CFEqual(source_color, destination_color)) return NO;
    CGRect clip = CGContextGetClipBoundingBox(destination);
    if (!CGRectEqualToRect(clip, CGRectMake(0, 0, canvas_width, canvas_height))) return NO;
    size_t source_pitch = CGBitmapContextGetBytesPerRow(source);
    size_t destination_pitch = CGBitmapContextGetBytesPerRow(destination);
    if (width > SIZE_MAX / 4 || source_pitch < width * 4
        || destination_pitch < width * 4 || source_pitch > SIZE_MAX / height
        || destination_pitch > SIZE_MAX / height) return NO;
    CGContextFlush(source);
    CGContextFlush(destination);
    const uint8_t *input = (const uint8_t *)CGBitmapContextGetData(source);
    uint8_t *output = (uint8_t *)CGBitmapContextGetData(destination);
    if (!input || !output) return NO;
#if defined(__aarch64__)
    const uint8_t indices[] = {2, 1, 0, 3, 6, 5, 4, 7, 10, 9, 8, 11, 14, 13, 12, 15};
    uint8x16_t order = vld1q_u8(indices);
#endif
    for (size_t y = 0; y < height; ++y) {
        const uint8_t *row = input + y * source_pitch;
        uint8_t *target = output + y * destination_pitch;
        size_t x = 0;
#if defined(__aarch64__)
        for (; width - x >= 16; x += 16) {
            uint8x16_t a = vld1q_u8(row + x * 4);
            uint8x16_t b = vld1q_u8(row + x * 4 + 16);
            uint8x16_t c = vld1q_u8(row + x * 4 + 32);
            uint8x16_t d = vld1q_u8(row + x * 4 + 48);
            vst1q_u8(target + x * 4, vqtbl1q_u8(a, order));
            vst1q_u8(target + x * 4 + 16, vqtbl1q_u8(b, order));
            vst1q_u8(target + x * 4 + 32, vqtbl1q_u8(c, order));
            vst1q_u8(target + x * 4 + 48, vqtbl1q_u8(d, order));
        }
        for (; width - x >= 4; x += 4)
            vst1q_u8(target + x * 4, vqtbl1q_u8(vld1q_u8(row + x * 4), order));
#endif
        for (; x < width; ++x) {
            target[x * 4] = row[x * 4 + 2];
            target[x * 4 + 1] = row[x * 4 + 1];
            target[x * 4 + 2] = row[x * 4];
            target[x * 4 + 3] = row[x * 4 + 3];
        }
    }
    return YES;
}

// Only the enclosing document may borrow the fresh, unpainted frame. Its
// initial state must match the separate RGBA canvas that would be allocated.
static BOOL native_layer_begin_document_canvas(CGContextRef context,
    CGFloat canvas_width, CGFloat canvas_height, CGFloat scale) {
    if (!context || context != native_layer_document_bitmap
        || !native_layer_document_bitmap_claimed || !isfinite(scale) || scale <= 0
        || !isfinite(canvas_width) || !isfinite(canvas_height)
        || canvas_width <= 0 || canvas_height <= 0) return NO;
    size_t width = CGBitmapContextGetWidth(context);
    size_t height = CGBitmapContextGetHeight(context);
    CGAffineTransform ctm = CGContextGetCTM(context);
    if (!width || !height || canvas_width * scale != (CGFloat)width
        || canvas_height * scale != (CGFloat)height
        || ctm.a != scale || ctm.d != scale || ctm.b != 0 || ctm.c != 0
        || ctm.tx != 0 || ctm.ty != 0
        || CGBitmapContextGetBitsPerComponent(context) != 8
        || CGBitmapContextGetBitsPerPixel(context) != 32
        || CGBitmapContextGetBitmapInfo(context) !=
            (kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big)
        || !CGRectEqualToRect(CGContextGetClipBoundingBox(context),
            CGRectMake(0, 0, canvas_width, canvas_height))) return NO;
    CGColorSpaceRef color = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    BOOL same_color = color && CGBitmapContextGetColorSpace(context)
        && CFEqual(color, CGBitmapContextGetColorSpace(context));
    if (color) CGColorSpaceRelease(color);
    if (!same_color) return NO;
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context, true);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    native_layer_initial_document_clear = (VoxInitialDocumentClear){context, canvas_width, canvas_height};
    return YES;
}

static void native_layer_draw_document_image(CGContextRef context, CGRect rect,
    CGImageRef image, int fresh_destination) {
    if (fresh_destination) {
        CGContextSaveGState(context);
        CGContextSetBlendMode(context, kCGBlendModeCopy);
    }
    CGContextDrawImage(context, rect, image);
    if (fresh_destination) CGContextRestoreGState(context);
}


static int vox_browser_has_paint_context(void) {
    NSGraphicsContext *context = NSGraphicsContext.currentContext;
    return context != nil && context.CGContext != NULL;
}

// Preparation consumes callbacks, resources and layout before pixels are
// replayed. Requests serviced there belong to this frame; requests delivered
// after this boundary still invalidate it.
static void vox_browser_frame_prepared(void) {
    native_layer_paint_generation = native_layer_redraw_generation;
    native_layer_last_prepared_generation = native_layer_redraw_generation;
    native_layer_paint_started = YES;
}

static BOOL native_layer_is_browser_view(NSView *view) {
    Class browser = NSClassFromString(@"MyView2");
    return browser && [view isKindOfClass:browser];
}

// UI2/AppKit controls invalidate themselves when their model changes. A
// document-frame wake only needs the native canvas and its Sokol host tick.
// Preserve independently dirty sibling views without redrawing every control.
static NSUInteger native_layer_invalidate_canvases(NSView *view) {
    if (!view) return 0;
    NSUInteger count = 0;
    if (native_layer_is_browser_view(view)) {
        view.needsDisplay = YES;
        view.superview.needsDisplay = YES;
        count++;
    }
    for (NSView *child in view.subviews) count += native_layer_invalidate_canvases(child);
    return count;
}

static NSUInteger native_layer_request_canvas_frames(NSView *root) {
    NSUInteger count = native_layer_invalidate_canvases(root);
    if (!count) root.needsDisplay = YES;
    return count;
}

static BOOL native_layer_has_browser_child(NSView *view) {
    for (NSView *child in view.subviews) {
        if (native_layer_is_browser_view(child) || native_layer_has_browser_child(child))
            return YES;
    }
    return NO;
}

static CGFloat native_layer_effective_scale(NSView *view) {
    if (native_layer_capture_scale > 0) return native_layer_capture_scale;
    // Capture documents already expose this density as devicePixelRatio.
    // Use it for their presented frames too, rather than supersampling at the
    // display's Retina scale and repainting at the requested scale for capture.
    if (getenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS") != NULL) {
        const char *value = getenv("LADYBIRD_SCREENSHOT_SCALE");
        double requested = value ? strtod(value, NULL) : 1;
        return isfinite(requested) && requested > 1 ? requested : 1;
    }
    CGFloat scale = view.window.backingScaleFactor;
    return isfinite(scale) && scale > 0 ? scale : 1;
}

// The image owns its bitmap storage after the temporary CGContext is released.
// A complete immutable frame becomes one Core Animation image, avoiding Quartz
// uploading and retaining a separate texture for each Skia primitive.
static CGImageRef native_layer_raster_frame_with_submission(NSView *view, CGFloat scale, IMP draw,
    NativeDocumentSubmissionFrame *submission) {
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
        color, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(color);
    if (!bitmap) return NULL;
    CGContextScaleCTM(bitmap, scale, scale);
    CGContextTranslateCTM(bitmap, -bounds.origin.x, -bounds.origin.y);
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    CGImageRef image = NULL;
    CGContextRef previous_bitmap = native_layer_document_bitmap;
    BOOL previous_claimed = native_layer_document_bitmap_claimed;
    VoxInitialDocumentClear previous_initial_clear = native_layer_initial_document_clear;
    NativeDocumentSubmissionFrame frame = { .bitmap = bitmap,
        .token = ++native_document_submission_sequence };
    NativeDocumentSubmissionFrame *previous_submission = native_document_submission_current;
    VoxFrameSnapshot previous_snapshot = vox_frame_snapshot_begin(bitmap);
    @try {
        native_document_submission_current = &frame;
        native_layer_document_bitmap = bitmap;
        native_layer_document_bitmap_claimed = NO;
        native_layer_initial_document_clear = (VoxInitialDocumentClear){0};
        NSGraphicsContext.currentContext = [NSGraphicsContext
            graphicsContextWithCGContext:bitmap flipped:view.isFlipped];
        ((void (*)(id, SEL, NSRect))draw)(view, @selector(drawRect:), bounds);
        image = vox_frame_snapshot_copy(bitmap);
    } @finally {
        vox_frame_snapshot_restore(previous_snapshot);
        native_document_submission_current = previous_submission;
        native_layer_document_bitmap = previous_bitmap;
        native_layer_document_bitmap_claimed = previous_claimed;
        native_layer_initial_document_clear = previous_initial_clear;
        NSGraphicsContext.currentContext = previous;
        CGContextRelease(bitmap);
    }
    if (image && submission) *submission = frame;
    return image;
}

static CGImageRef native_layer_raster_frame(NSView *view, CGFloat scale, IMP draw) {
    return native_layer_raster_frame_with_submission(view, scale, draw, NULL);
}

static void native_layer_present_frame(NSView *view, CGFloat scale, IMP draw) {
    uint64_t generation = native_layer_redraw_generation;
    NSRect bounds = view.bounds;
    BOOL previous_started = native_layer_paint_started;
    uint64_t previous_generation = native_layer_paint_generation;
    native_layer_paint_started = NO;
    CGImageRef image = NULL;
    NativeDocumentSubmissionFrame submission = {0};
    @try {
        image = native_layer_raster_frame_with_submission(view, scale, draw, &submission);
        if (native_layer_paint_started) generation = native_layer_paint_generation;
    } @finally {
        native_layer_paint_started = previous_started;
        native_layer_paint_generation = previous_generation;
    }
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
    native_document_submission_acknowledge(&submission);
    objc_setAssociatedObject(view, &native_layer_frame_generation_key,
        @(generation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &native_layer_frame_bounds_key,
        [NSValue valueWithRect:bounds], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGImageRelease(image);
}

static void native_layer_restore_frame_scale(NSView *view) {
    // A capture at the presentation density has nothing to restore. Preserve
    // existing invalidation, but do not schedule a redundant post-capture frame.
    if (view.layer.contentsScale != native_layer_effective_scale(view))
        view.needsDisplay = YES;
}

static BOOL native_layer_frame_matches_input(NSView *view, CGFloat scale) {
    NSNumber *generation = objc_getAssociatedObject(view, &native_layer_frame_generation_key);
    NSValue *bounds = objc_getAssociatedObject(view, &native_layer_frame_bounds_key);
    id contents = view.layer.contents;
    if (!generation || !bounds || !contents
        || generation.unsignedLongLongValue != native_layer_redraw_generation
        || !NSEqualRects(bounds.rectValue, view.bounds) || view.layer.contentsScale != scale
        || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID()) return NO;
    CGImageRef image = (__bridge CGImageRef)contents;
    return CGImageGetWidth(image) == ceil(view.bounds.size.width * scale)
        && CGImageGetHeight(image) == ceil(view.bounds.size.height * scale);
}

static BOOL native_layer_frame_is_current(NSView *view, CGFloat scale) {
    return !view.needsDisplay && native_layer_frame_matches_input(view, scale);
}

static void native_layer_draw(id self, SEL command, NSRect rect) {
    NSView *view = self;
    if (native_layer_copying_capture
        && native_layer_frame_matches_input(view, native_layer_effective_scale(view))) {
        CGContextRef context = NSGraphicsContext.currentContext.CGContext;
        if (context) {
            CGContextSaveGState(context);
            if (view.isFlipped) {
                CGContextTranslateCTM(context, 0, NSMinY(view.bounds) + NSMaxY(view.bounds));
                CGContextScaleCTM(context, 1, -1);
            }
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            CGContextDrawImage(context, view.bounds, (__bridge CGImageRef)view.layer.contents);
            CGContextRestoreGState(context);
            if (getenv("VOX_PROFILE_INSTRUCTIONS")) fprintf(stderr, "Vox capture draw: copied presented raster\n");
            return;
        }
    }
    if (native_layer_original_draw)
        ((void (*)(id, SEL, NSRect))native_layer_original_draw)(self, command, rect);
}

static BOOL native_layer_wants_update(id self, SEL command) {
    (void)self; (void)command;
    return YES;
}

static void native_layer_update(id self, SEL command) {
    (void)command;
    if (native_layer_presenting || native_layer_document_work_active) return;
    // AppKit may dirty layers as part of cacheDisplayInRect:. Their document
    // input has not changed; keep the immutable pixels prepared for this copy.
    if (native_layer_copying_capture
        && native_layer_frame_matches_input(self, native_layer_effective_scale(self))) {
        if (getenv("VOX_PROFILE_INSTRUCTIONS")) fprintf(stderr, "Vox capture update: retained presented raster\n");
        return;
    }
    native_layer_presenting = YES;
    @try {
    @autoreleasepool {
        native_layer_present_frame(self, native_layer_effective_scale(self),
            native_layer_original_draw);
    }
    } @finally {
        native_layer_presenting = NO;
    }
    // AppKit clears needsDisplay after updateLayer returns. Input or timers
    // serviced during replay can dirty this very layer, then lose that dirty
    // bit at the end of the current display pass. Deliver the retained request
    // once the pass has finished rather than waiting for an unrelated timer.
    NSView *view = self;
    NSNumber *painted = objc_getAssociatedObject(view, &native_layer_frame_generation_key);
    if (painted && painted.unsignedLongLongValue != native_layer_redraw_generation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            view.needsDisplay = YES;
        });
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
        native_layer_original_draw = native_layer_replace_method(browser,
            @selector(drawRect:), (IMP)native_layer_draw, "v@:{CGRect={CGPoint=dd}{CGSize=dd}}");
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
        if (render) {
            // Capture the current presented pixels without delivering another
            // V frame. Dirty, resized, superseded or differently scaled frames
            // still take the ordinary draw path.
            if (!native_layer_frame_is_current(view, native_layer_effective_scale(view))) {
                if (getenv("VOX_PROFILE_INSTRUCTIONS")) {
                    NSNumber *generation = objc_getAssociatedObject(view, &native_layer_frame_generation_key);
                    fprintf(stderr, "Vox capture stale frame: dirty=%d generation=%llu/%llu scale=%g/%g\n",
                        view.needsDisplay, generation.unsignedLongLongValue,
                        (unsigned long long)native_layer_redraw_generation,
                        (double)view.layer.contentsScale, (double)native_layer_effective_scale(view));
                }
                native_layer_update(view, @selector(updateLayer));
                if (getenv("VOX_PROFILE_INSTRUCTIONS")) fprintf(stderr, "Vox capture frame: rasterized\n");
            } else if (getenv("VOX_PROFILE_INSTRUCTIONS")) {
                fprintf(stderr, "Vox capture frame: reused\n");
            }
        }
        else native_layer_restore_frame_scale(view);
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
        BOOL previous_copying = native_layer_copying_capture;
        native_layer_copying_capture = YES;
        @try {
            [view cacheDisplayInRect:bounds toBitmapImageRep:bitmap];
        } @finally {
            native_layer_copying_capture = previous_copying;
        }
    } @finally {
        native_layer_capture_scale = previous;
        native_layer_prepare_capture(view, NO);
    }
}
#endif
