#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

// Injected only by test_native_browser_resize.py. Exercise AppKit's actual
// zoom/resize callbacks and wait for a newly sized, nonempty presented frame.
static NSWindow *test_window;
static NSView *test_view;
static NSRect original_frame;
static unsigned step;
static unsigned attempts;
static unsigned settled;
static CGSize previous_size;

static NSView *browser_view(NSView *view) {
    if ([view isKindOfClass:NSClassFromString(@"MyView2")]) return view;
    for (NSView *child in view.subviews) {
        NSView *found = browser_view(child);
        if (found) return found;
    }
    return nil;
}

static void fail(const char *message) {
    fprintf(stderr, "FAIL resize step %u: %s\n", step, message);
    fflush(stderr);
    _Exit(1);
}

static BOOL presented_frame_is_ready(void) {
    id contents = test_view.layer.contents;
    if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID())
        return NO;
    CGImageRef image = (__bridge CGImageRef)contents;
    CGSize size = test_view.bounds.size;
    CGFloat scale = test_view.layer.contentsScale;
    return size.width > 0 && size.height > 0 && scale > 0
        && CGImageGetWidth(image) == (size_t)ceil(size.width * scale)
        && CGImageGetHeight(image) == (size_t)ceil(size.height * scale);
}

static void advance(void);

static void poll(void) {
    if (++attempts > 300) fail("timed out waiting for the resized frame");
    if (!test_view) {
        for (NSWindow *window in NSApp.windows) {
            NSView *view = browser_view(window.contentView);
            if (!view) continue;
            test_window = window;
            test_view = view;
            original_frame = window.frame;
            previous_size = view.bounds.size;
            break;
        }
    }
    if (test_view && presented_frame_is_ready()) {
        CGSize size = test_view.bounds.size;
        // Every action changes geometry. Requiring the changed size prevents
        // a retained pre-resize image from satisfying this test.
        if (step == 0 || !CGSizeEqualToSize(size, previous_size)) {
            if (++settled >= 5) {
                fprintf(stderr, "PASS resize step %u: %.0fx%.0f scale=%.1f\n",
                    step, size.width, size.height, test_view.layer.contentsScale);
                fflush(stderr);
                previous_size = size;
                settled = 0;
                attempts = 0;
                advance();
                return;
            }
        } else settled = 0;
    } else settled = 0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC),
        dispatch_get_main_queue(), ^{ poll(); });
}

static void advance(void) {
    switch (++step) {
        case 1: [test_window zoom:nil]; break;
        case 2:
            [test_window zoom:nil];
            if (!NSEqualRects(test_window.frame, original_frame))
                fail("zoom did not restore the original window frame");
            break;
        case 3: [test_window setContentSize:NSMakeSize(640, 480)]; break;
        case 4: [test_window setContentSize:NSMakeSize(1200, 900)]; break;
        case 5: [test_window setFrame:original_frame display:YES]; break;
        default:
            fprintf(stderr, "PASS native browser maximize, restore and resize\n");
            fflush(stderr);
            _Exit(0);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC),
        dispatch_get_main_queue(), ^{ poll(); });
}

__attribute__((constructor)) static void start_resize_test(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{ poll(); });
}
