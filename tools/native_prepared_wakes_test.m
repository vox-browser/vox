#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>
#include "native_layer_presentation_test_darwin.h"

@interface PreparedWakeApplication : NSApplication
@property NSUInteger postedEvents;
@end
@implementation PreparedWakeApplication
- (void)postEvent:(NSEvent *)event atStart:(BOOL)start {
    (void)event; (void)start;
    self.postedEvents++;
}
@end

static NSView *timer_test_view;
static NSView *native_browser_view(void) { return timer_test_view; }
static void native_trace_browser_redraw(const char *point) { (void)point; }
#include "native_prepared_wakes.inc"

static void pump(void) {
    CFAbsoluteTime until = CFAbsoluteTimeGetCurrent() + .025;
    while (CFAbsoluteTimeGetCurrent() < until)
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, .001, false);
}

static void run_on_real_worker(dispatch_block_t work) {
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        assert(!NSThread.isMainThread);
        work();
        dispatch_semaphore_signal(done);
    });
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
#if !__has_feature(objc_arc)
    dispatch_release(done);
#endif
}

static void prepare_phase(void) {
    native_layer_presenting = YES;
    native_layer_document_work_active = YES;
    native_layer_paint_started = NO;
}

static void prepared_draw(id view, SEL command, NSRect bounds) {
    native_layer_document_work_active = YES;
    native_wake_browser_during_preparation();
    vox_browser_frame_prepared();
    native_layer_test_draw(view, command, bounds);
    native_layer_document_work_active = NO;
}

int main(void) {
    @autoreleasepool {
        assert(native_test_layer_retains_immutable_frame_without_copying_pixels() == 63);
        puts("PASS immutable document snapshots retain pixels and run frame callbacks");
        setenv("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "0", 1);
        unsetenv("LADYBIRD_SCREENSHOT_SCALE");
        PreparedWakeApplication *application = [PreparedWakeApplication sharedApplication];
        assert(native_test_capture_copy_preserves_pixels_and_skips_redundant_frames() == 31);
        assert(native_test_layer_capture_frame_invalidation() == 4095);
        assert(native_test_layer_uses_document_capture_density() == 31);
        puts("PASS existing raster copying, frame invalidation and density contracts");
        native_layer_last_prepared_generation = native_layer_redraw_generation;

        prepare_phase();
        NSUInteger posts = application.postedEvents;
        uint64_t generation = native_layer_redraw_generation;
        native_wake_browser_during_preparation();
        native_wake_browser_during_preparation();
        assert(native_layer_redraw_generation == generation + 2);
        vox_browser_frame_prepared();
        pump();
        assert(application.postedEvents == posts);
        assert(native_layer_paint_generation == native_layer_redraw_generation);
        puts("PASS preparation requests consumed by the current frame");

        prepare_phase();
        native_wake_browser_during_preparation();
        pump();
        assert(application.postedEvents == ++posts);
        assert(native_layer_paint_generation != native_layer_redraw_generation);
        puts("PASS unfinished preparation still requests a frame");

        prepare_phase();
        native_wake_browser_during_preparation();
        vox_browser_frame_prepared();
        native_layer_paint_started = NO;
        native_wake_browser_during_preparation();
        pump();
        assert(application.postedEvents == ++posts);
        assert(native_layer_paint_generation != native_layer_redraw_generation);
        puts("PASS coalesced request after the boundary is retained");

        vox_browser_frame_prepared();
        native_wake_browser_during_preparation();
        pump();
        assert(application.postedEvents == ++posts);
        assert(native_layer_paint_generation != native_layer_redraw_generation);
        puts("PASS replay-time request uses the ordinary wake");

        prepare_phase();
        vox_browser_frame_prepared();
        run_on_real_worker(^{
            native_wake_browser_during_preparation();
        });
        pump();
        assert(application.postedEvents == ++posts);
        assert(native_layer_paint_generation != native_layer_redraw_generation);
        puts("PASS worker completion keeps its ordinary wake");

        native_layer_presenting = NO;
        native_layer_document_work_active = NO;
        native_layer_paint_started = NO;
        NSView *view = [[NativeLayerFrameTestView alloc] initWithFrame:NSMakeRect(0, 0, 4, 2)];
        view.wantsLayer = YES;
        native_layer_original_draw = (IMP)prepared_draw;
        native_layer_update(view, @selector(updateLayer));
        assert(native_layer_preparation_started == 0 && native_layer_preparation_view == 0);
        assert(native_layer_last_preparation_started > 0
            && native_layer_last_preparation_view == (uintptr_t)(__bridge void *)view);
        view.needsDisplay = NO;
        pump();
        assert(application.postedEvents == posts);
        assert(native_layer_frame_is_current(view, 1));
        assert(native_layer_test_image((__bridge CGImageRef)view.layer.contents, 4, 2));
        double prepared_boundary = native_layer_last_preparation_started;
        native_layer_copying_capture = YES;
        native_layer_update(view, @selector(updateLayer));
        native_layer_copying_capture = NO;
        assert(native_layer_last_preparation_started == prepared_boundary);
        native_wake_browser();
        pump();
        assert(application.postedEvents == ++posts);
        assert(!native_layer_frame_is_current(view, 1));
        puts("PASS current pixels remain reusable and later work invalidates them");
        timer_test_view = view;
        native_layer_last_preparation_view = (uintptr_t)(__bridge void *)view;
        setenv("VOX_COALESCE_EXPIRED_FRAME_TIMERS", "1", 1);
        native_layer_last_preparation_started = 0;
        native_wake_browser_after(0);
        pump();
        assert(application.postedEvents == ++posts);
        generation = native_layer_redraw_generation;
        native_wake_browser_after(0);
        native_layer_last_preparation_started = CACurrentMediaTime() + 1;
        pump();
        assert(application.postedEvents == posts && native_layer_redraw_generation == generation);
        puts("PASS expired frame timer consumed without invalidating current input");

        // Finishing preparation after a deadline is insufficient when that
        // preparation began before the work became due.
        native_layer_preparation_started = CACurrentMediaTime() - 1;
        native_layer_preparation_view = (uintptr_t)(__bridge void *)view;
        native_wake_browser_after(0);
        vox_browser_frame_prepared();
        pump();
        assert(application.postedEvents == ++posts);
        native_layer_preparation_started = 0;
        native_layer_preparation_view = 0;
        native_layer_last_preparation_started = CACurrentMediaTime();
        native_wake_browser_after(2);
        pump();
        assert(application.postedEvents == ++posts);
        puts("PASS future deadlines and work due during preparation retain their wake");

        native_wake_browser_after(0);
        native_layer_last_preparation_started = CACurrentMediaTime() + 1;
        native_layer_last_preparation_view = 0;
        pump();
        assert(application.postedEvents == ++posts);
        native_layer_last_preparation_view = (uintptr_t)(__bridge void *)view;
        run_on_real_worker(^{
            native_wake_browser_after(0);
        });
        pump();
        assert(application.postedEvents == ++posts);
        puts("PASS other-window preparation and worker timers retain their wake");
        native_wake_browser_after(0);
        timer_test_view = nil;
        pump();
        assert(application.postedEvents == ++posts);
        timer_test_view = view;
        puts("PASS changing the target window retains the original wake");

        unsetenv("VOX_COALESCE_EXPIRED_FRAME_TIMERS");
        native_wake_browser_after(0);
        native_layer_last_preparation_started = CACurrentMediaTime() + 1;
        pump();
        assert(application.postedEvents == ++posts);
        puts("PASS timer control keeps the original wake behavior");
        timer_test_view = nil;
#if !__has_feature(objc_arc)
        [view release];
#endif
    }
    return 0;
}
