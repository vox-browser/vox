#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "native_layer_presentation_darwin.h"
#include "native_snapshot_png_darwin.h"

static unsigned termination_calls;
@interface CaptureApplication : NSApplication
@end
@implementation CaptureApplication
- (void)terminate:(id)sender { (void)sender; ++termination_calls; }
@end

@interface CaptureWindow : NSObject
- (CGFloat)backingScaleFactor;
@end
@implementation CaptureWindow
- (CGFloat)backingScaleFactor { return 2; }
@end
@interface MyView2 : NSView
@property(strong) CaptureWindow *captureWindow;
@property NSUInteger captures;
@property size_t sourceWidth;
@property size_t sourceHeight;
@property CGFloat sourceScale;
@property CGFloat captureOverride;
@property NSRect capturedBounds;
@property NSInteger bitmapWidth;
@property NSInteger bitmapHeight;
@property BOOL flippedCapture;
@end
@implementation MyView2
- (BOOL)isFlipped { return self.flippedCapture; }
- (NSWindow *)window { return (NSWindow *)self.captureWindow; }
- (void)cacheDisplayInRect:(NSRect)bounds toBitmapImageRep:(NSBitmapImageRep *)bitmap {
    self.capturedBounds = bounds;
    self.bitmapWidth = bitmap.pixelsWide;
    self.bitmapHeight = bitmap.pixelsHigh;
    ++self.captures;
    CGImageRef image = (__bridge CGImageRef)self.layer.contents;
    self.sourceWidth = CGImageGetWidth(image);
    self.sourceHeight = CGImageGetHeight(image);
    self.sourceScale = self.layer.contentsScale;
    self.captureOverride = native_layer_capture_scale;
}
@end
static MyView2 *capture_view;
static unsigned draws;
static void capture_draw(id view, SEL command, NSRect bounds) {
    (void)view; (void)command;
    ++draws;
    CGContextRef context = NSGraphicsContext.currentContext.CGContext;
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, bounds);
}
typedef struct { const char *str; int len; } string;
static NSString *native_capture_string(string value) {
    NSString *result = [[NSString alloc] initWithBytes:value.str length:value.len
        encoding:NSUTF8StringEncoding];
#if !__has_feature(objc_arc)
    return [result autorelease];
#else
    return result;
#endif
}
static NSView *native_browser_view(void) { return capture_view; }
static void native_request_browser_redraw(void) {}
static unsigned document_process_checkpoints;
static unsigned document_coalition_checkpoints;
static unsigned document_audit_callbacks;
static char document_audit_path[4096];
static void document_audit(void *owner) {
    assert(owner == &document_audit_callbacks);
    assert(document_process_checkpoints == document_audit_callbacks + 1);
    assert(document_coalition_checkpoints == document_audit_callbacks + 1);
    assert([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithUTF8String:document_audit_path]]);
    ++document_audit_callbacks;
}
static void native_capture_instruction_checkpoint(const char *label) {
    if (strcmp(label, "capture_document_encoded") == 0) ++document_process_checkpoints;
}
static void vox_coalition_instruction_checkpoint(const char *label) {
    assert(strcmp(label, "capture_document_encoded") == 0);
    ++document_coalition_checkpoints;
}
// The runner extracts the real entry points and shared scheduling/scale helpers,
// preserving their deferred scheduling, encoding, and write behavior.
#include "native_capture_entry_points.inc"

static void pump_for(double seconds) {
    CFAbsoluteTime until = CFAbsoluteTimeGetCurrent() + seconds;
    while (CFAbsoluteTimeGetCurrent() < until)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, .005, false);
}
int main(int argc, char **argv) {
    assert(argc == 2);
    @autoreleasepool {
        [CaptureApplication sharedApplication];
        assert([NSApp isKindOfClass:CaptureApplication.class]);
        assert(NSApp.windows.count == 0);
        capture_view = [[MyView2 alloc] initWithFrame:NSMakeRect(0, 0, 32, 16)];
        CaptureWindow *window = [CaptureWindow new];
        capture_view.captureWindow = window;
#if !__has_feature(objc_arc)
        [window release];
#endif
        capture_view.wantsLayer = YES;
        native_layer_original_draw = (IMP)capture_draw;
        setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "0", 1);
        setenv("LADYBIRD_SCREENSHOT_SCALE", "1", 1);
        __block unsigned idle_calls = 0;
        native_when_document_work_idle(^{ ++idle_calls; });
        assert(idle_calls == 1); // An idle call retains synchronous semantics.
        for (unsigned entry = 0; entry < 2; ++entry) {
            for (unsigned busy = 0; busy < 2; ++busy) {
                // Ordinary presentation follows the window's 2x backing scale.
                // Capture-mode presentation instead follows its explicit 1x DPR.
                unsetenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS");
                native_layer_update(capture_view, @selector(updateLayer));
                assert(CGImageGetWidth((__bridge CGImageRef)capture_view.layer.contents) == 64);
                assert(capture_view.layer.contentsScale == 2);
                setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "0", 1);
                NSUInteger previous = capture_view.captures;
                unsigned previous_draws = draws;
                if (busy == 0) native_layer_document_work_active = YES;
                else native_layer_presenting = YES;
                // The implementation's autoreleased path and the caller's UTF-8
                // buffer must survive repeated deferred blocks after this pool.
                @autoreleasepool {
                    NSString *path = [NSString stringWithFormat:@"%s/entry-%u-busy-%u.png",
                        argv[1], entry, busy];
                    string value = { path.UTF8String, (int)[path lengthOfBytesUsingEncoding:NSUTF8StringEncoding] };
                    if (entry == 0) native_cache_browser_snapshot(value);
                    else schedule_native_screenshot(value);
                }
                pump_for(.025);
                assert(capture_view.captures == previous);
                assert(draws == previous_draws);
                assert(native_layer_capture_scale == 0);
                native_layer_document_work_active = NO;
                native_layer_presenting = NO;
                CFAbsoluteTime timeout = CFAbsoluteTimeGetCurrent() + 5;
                while (capture_view.captures == previous && CFAbsoluteTimeGetCurrent() < timeout)
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode, .005, false);
                assert(capture_view.captures == previous + 1);
                assert(draws == previous_draws + 1);
                assert(capture_view.sourceWidth == 32 && capture_view.sourceHeight == 16);
                assert(capture_view.sourceScale == 1 && capture_view.captureOverride == 1);
                assert(native_layer_capture_scale == 0 && !native_layer_presenting);
                NSString *path = [NSString stringWithFormat:@"%s/entry-%u-busy-%u.png", argv[1], entry, busy];
                assert([[NSFileManager defaultManager] fileExistsAtPath:path]);
                pump_for(.01);
                assert(capture_view.captures == previous + 1); // No duplicate retry delivery.
                assert(termination_calls == (entry == 0 ? 0 : busy + 1));
                printf("entry=%s busy=%s deferred=1 fresh_source=32x16 scale=1 once=1 path_alive=1\n",
                    entry == 0 ? "snapshot" : "screenshot", busy == 0 ? "work" : "presenting");
            }
        }
        assert(capture_view.captures == 4);
        assert(termination_calls == 2 && NSApp.windows.count == 0);
        assert(document_process_checkpoints == 0 && document_coalition_checkpoints == 0);
        // A top inset describes the same crop in flipped and unflipped views.
        // A nonzero bounds origin catches accidental frame-coordinate cropping.
        [capture_view setBounds:NSMakeRect(7, 11, 32, 16)];
        for (unsigned flipped = 0; flipped < 2; ++flipped) {
            capture_view.flippedCapture = flipped;
            NSUInteger previous = capture_view.captures;
            unsigned previous_terminations = termination_calls;
            native_layer_document_work_active = YES;
            @autoreleasepool {
                NSString *path = [NSString stringWithFormat:@"%s/document-%u.png", argv[1], flipped];
                snprintf(document_audit_path, sizeof(document_audit_path), "%s", path.fileSystemRepresentation);
                string value = { path.UTF8String, (int)[path lengthOfBytesUsingEncoding:NSUTF8StringEncoding] };
                schedule_native_document_screenshot(value, 3, 20, 8, &document_audit_callbacks, document_audit);
            }
            pump_for(.025);
            assert(capture_view.captures == previous);
            native_layer_document_work_active = NO;
            CFAbsoluteTime timeout = CFAbsoluteTimeGetCurrent() + 5;
            while (termination_calls == previous_terminations && CFAbsoluteTimeGetCurrent() < timeout)
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, .005, false);
            assert(capture_view.captures == previous + 1);
            assert(termination_calls == previous_terminations + 1);
            assert(NSEqualRects(capture_view.capturedBounds, NSMakeRect(7, flipped ? 14 : 16, 20, 8)));
            assert(capture_view.bitmapWidth == 20 && capture_view.bitmapHeight == 8);
            NSString *path = [NSString stringWithFormat:@"%s/document-%u.png", argv[1], flipped];
            NSBitmapImageRep *image = [NSBitmapImageRep imageRepWithContentsOfFile:path];
            assert(image != nil && image.pixelsWide == 20 && image.pixelsHigh == 8);
            assert(document_process_checkpoints == flipped + 1);
            assert(document_coalition_checkpoints == flipped + 1);
            assert(document_audit_callbacks == flipped + 1);
            printf("document flipped=%u deferred=1 bounds=1 png=20x8 process=1 coalition=1\n", flipped);
        }
        const double invalid[][3] = {
            { NAN, 20, 8 }, { 3, INFINITY, 8 }, { 3, 20, NAN },
            { -1, 20, 8 }, { 3, 0, 8 }, { 3, 20, 0 },
            { 3, 33, 8 }, { 10, 20, 8 }
        };
        for (unsigned index = 0; index < sizeof(invalid) / sizeof(invalid[0]); ++index) {
            NSUInteger previous = capture_view.captures;
            unsigned previous_terminations = termination_calls;
            NSString *path = [NSString stringWithFormat:@"%s/invalid-%u.png", argv[1], index];
            string value = { path.UTF8String, (int)[path lengthOfBytesUsingEncoding:NSUTF8StringEncoding] };
            schedule_native_document_screenshot(value, invalid[index][0], invalid[index][1], invalid[index][2], &document_audit_callbacks, document_audit);
            CFAbsoluteTime timeout = CFAbsoluteTimeGetCurrent() + 5;
            while (termination_calls == previous_terminations && CFAbsoluteTimeGetCurrent() < timeout)
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, .005, false);
            assert(termination_calls == previous_terminations + 1 && capture_view.captures == previous);
            assert(![[NSFileManager defaultManager] fileExistsAtPath:path]);
            assert(document_process_checkpoints == 2 && document_coalition_checkpoints == 2);
            assert(document_audit_callbacks == 2);
            printf("document invalid=%u rejected=1 no_png=1 no_checkpoint=1\n", index);
        }
        assert(capture_view.captures == 6 && termination_calls == 12);
        assert(NSApp.windows.count == 0);
        assert(NSGraphicsContext.currentContext == nil);
        capture_view.captureWindow = nil;
#if !__has_feature(objc_arc)
        [capture_view release];
#endif
        capture_view = nil;
        puts("PASS deferred actual snapshot/screenshot entry points preserve logical scale and path lifetime");
    }
}
