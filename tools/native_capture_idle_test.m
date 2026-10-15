#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <assert.h>
#include <stdio.h>
#include "native_layer_presentation_darwin.h"

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
@end
@implementation MyView2
- (NSWindow *)window { return (NSWindow *)self.captureWindow; }
- (void)cacheDisplayInRect:(NSRect)bounds toBitmapImageRep:(NSBitmapImageRep *)bitmap {
    (void)bounds; (void)bitmap;
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
// The runner extracts these two complete functions from the actual native
// implementation, preserving their scheduling, encoding, and write behavior.
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
        __block unsigned idle_calls = 0;
        native_when_document_work_idle(^{ ++idle_calls; });
        assert(idle_calls == 1); // An idle call retains synchronous semantics.
        for (unsigned entry = 0; entry < 2; ++entry) {
            for (unsigned busy = 0; busy < 2; ++busy) {
                native_layer_update(capture_view, @selector(updateLayer));
                assert(CGImageGetWidth((__bridge CGImageRef)capture_view.layer.contents) == 64);
                assert(capture_view.layer.contentsScale == 2);
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
        assert(NSGraphicsContext.currentContext == nil);
        capture_view.captureWindow = nil;
#if !__has_feature(objc_arc)
        [capture_view release];
#endif
        capture_view = nil;
        puts("PASS deferred actual snapshot/screenshot entry points preserve logical scale and path lifetime");
    }
}
