#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native_layer_presentation_test_darwin.h"
#include "native_presented_capture_darwin.h"

@interface MyView2 : NativeLayerFrameTestView
@property BOOL testFlipped;
@end
@implementation MyView2
- (BOOL)isFlipped { return self.testFlipped; }
- (void)drawRect:(NSRect)rect { native_layer_draw(self, @selector(drawRect:), rect); }
@end

static void compare_region(MyView2 *canvas, NSView *root, NSRect rect, NSInteger scale)
{
    NSInteger width = rect.size.width * scale, height = rect.size.height * scale;
    NSBitmapImageRep *actual = native_presented_capture_bitmap(root, rect, width, height);
    assert(actual && actual.pixelsWide == width && actual.pixelsHigh == height);
    NSBitmapImageRep *expected = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4
        hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
        bytesPerRow:width * 4 bitsPerPixel:32];
    // Exercise the existing Quartz replay directly. Windowless AppKit subtree
    // capture can return transparent pixels above the display's own density.
    NSRect local = [canvas convertRect:rect fromView:root];
    NSGraphicsContext *previous = NSGraphicsContext.currentContext;
    BOOL previous_copying = native_layer_copying_capture;
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:expected];
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    if (canvas.isFlipped) {
        CGContextTranslateCTM(context, 0, height);
        CGContextScaleCTM(context, scale, -scale);
    } else CGContextScaleCTM(context, scale, scale);
    CGContextTranslateCTM(context, -local.origin.x, -local.origin.y);
    native_layer_copying_capture = YES;
    native_layer_draw(canvas, @selector(drawRect:), local);
    native_layer_copying_capture = previous_copying;
    NSGraphicsContext.currentContext = previous;
    expected = [expected bitmapImageRepByConvertingToColorSpace:NSColorSpace.sRGBColorSpace
        renderingIntent:NSColorRenderingIntentRelativeColorimetric];
    assert(expected && expected.bitsPerPixel == actual.bitsPerPixel);
    assert(NSEqualSizes(actual.size, expected.size));
    for (NSInteger y = 0; y < height; ++y) for (NSInteger x = 0; x < width; ++x) {
        uint8_t *a = actual.bitmapData + y * actual.bytesPerRow + x * 4;
        uint8_t *b = expected.bitmapData + y * expected.bytesPerRow + x * 4;
        if (memcmp(a,b,4)) {
            fprintf(stderr,"Capture mismatch scale=%ld flipped=%d rect=%g,%g %gx%g at %ld,%ld actual=%u,%u,%u,%u expected=%u,%u,%u,%u\n",
                (long)scale, canvas.isFlipped, rect.origin.x,rect.origin.y,rect.size.width,rect.size.height,
                (long)x,(long)y,a[0],a[1],a[2],a[3],b[0],b[1],b[2],b[3]);
            abort();
        }
    }
    assert(CFEqual(CGImageGetColorSpace(actual.CGImage), CGImageGetColorSpace(expected.CGImage)));
    assert(native_layer_capture_scale == 0);
}

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "0", 1);
    native_layer_original_draw = (IMP)native_layer_test_asymmetric_draw;
    unsigned comparisons = 0;
    for (NSInteger scale = 1; scale <= 2; ++scale) for (int orientation = 0; orientation < 2; ++orientation) {
        BOOL flipped = orientation != 0;
        setenv("LADYBIRD_SCREENSHOT_SCALE", scale == 1 ? "1" : "2", 1);
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,40,32)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        MyView2 *canvas = [[MyView2 alloc] initWithFrame:NSMakeRect(0,0,32,24)];
        window.contentView = canvas;
        canvas.testFlipped = flipped; canvas.wantsLayer = YES;
        native_layer_present_frame(canvas, scale, native_layer_original_draw);
        canvas.needsDisplay = NO;
        // Full frames and asymmetric cropped regions retain Quartz row order
        // for either coordinate orientation and capture density.
        compare_region(canvas, canvas, canvas.bounds, scale); ++comparisons;
        compare_region(canvas, canvas, NSMakeRect(3,5,19,11), scale); ++comparisons;
        NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0,0,40,32)];
        window.contentView = root;
        canvas.frame = NSMakeRect(4,3,32,24); [root addSubview:canvas];
        canvas.needsDisplay = NO;
        compare_region(canvas, root, [root convertRect:NSMakeRect(3,5,19,11) fromView:canvas], scale); ++comparisons;
        NSRect region = [root convertRect:canvas.bounds fromView:canvas];
        NSView *overlay = [[NSView alloc] initWithFrame:NSMakeRect(5,5,10,10)];
        [root addSubview:overlay];
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        overlay.hidden = YES;
        assert(native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        overlay.hidden = NO; overlay.frame = NSMakeRect(36,27,4,4);
        assert(native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        canvas.alphaValue = .5;
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        canvas.alphaValue = 1;
        canvas.layer.transform = CATransform3DMakeScale(.9,1,1);
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        canvas.layer.transform = CATransform3DIdentity;
        canvas.layer.contentsRect = CGRectMake(0,0,.5,1);
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        canvas.layer.contentsRect = CGRectMake(0,0,1,1);
        CALayer *extra = [CALayer layer]; extra.frame = CGRectMake(0,0,10,10);
        [canvas.layer addSublayer:extra];
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        [extra removeFromSuperlayer];
        setenv("VOX_DISABLE_PRESENTED_CAPTURE", "1", 1);
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        unsetenv("VOX_DISABLE_PRESENTED_CAPTURE");
        IMP original = native_layer_original_draw; native_layer_original_draw = NULL;
        ++native_layer_redraw_generation;
        assert(!native_presented_capture_bitmap(root, region, 32 * scale, 24 * scale));
        assert(native_layer_capture_scale == 0);
        native_layer_original_draw = original;
        [canvas removeFromSuperview];
        [window close];
#if !__has_feature(objc_arc)
        [overlay release]; [root release]; [canvas release]; [window release];
#endif
    }
    assert(!native_presented_capture_bitmap(nil, NSMakeRect(0,0,1,1), 1, 1));
    printf("PASS %u exact presented-frame captures, cropped/flipped regions and overlay/state fallbacks\n", comparisons);
} return 0; }
