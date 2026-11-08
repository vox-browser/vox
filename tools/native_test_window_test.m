#include <assert.h>
#include "../native/include/native_test_window_darwin.h"

@interface TestDisplay : NSObject
@property NSRect frame;
@property NSRect visibleFrame;
@end
@implementation TestDisplay
@end

static NSScreen *display(CGFloat x, CGFloat y, CGFloat width, CGFloat height) {
    TestDisplay *screen = [TestDisplay new];
    screen.frame = NSMakeRect(x, y, width, height);
    screen.visibleFrame = NSInsetRect(screen.frame, 10, 25);
    return (NSScreen *)screen;
}

int main(void) {
    @autoreleasepool {
        NSScreen *primary = display(0, 0, 1920, 1080);
        NSScreen *left = display(-1440, 0, 1440, 900);
        NSScreen *above = display(0, 1080, 1920, 1080);
        NSScreen *mirror = display(0, 0, 1920, 1080);
        assert(native_test_window_other_screen(@[primary, left], NSMakePoint(100, 100), primary) == left);
        assert(native_test_window_other_screen(@[primary, left], NSMakePoint(-100, 100), primary) == primary);
        assert(native_test_window_other_screen(@[primary, above], NSMakePoint(100, 1500), primary) == primary);
        assert(native_test_window_other_screen(@[primary], NSMakePoint(100, 100), primary) == primary);
        assert(native_test_window_other_screen(@[primary, mirror], NSMakePoint(100, 100), primary) == primary);
        assert(native_test_window_other_screen(@[], NSZeroPoint, nil) == nil);
        // A pointer in a gap uses the display known to AppKit.
        assert(native_test_window_other_screen(@[primary, left], NSMakePoint(4000, 4000), left) == primary);

        [NSApplication sharedApplication];
        pid_t foreground = NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
        assert(foreground != getpid());
        IMP activate = method_getImplementation(class_getInstanceMethod(NSApplication.class,
            @selector(activateIgnoringOtherApps:)));
        IMP order = method_getImplementation(class_getInstanceMethod(NSWindow.class,
            @selector(makeKeyAndOrderFront:)));
        NSScreen *expected = native_test_window_other_screen(NSScreen.screens,
            NSEvent.mouseLocation, NSScreen.mainScreen);
        native_prepare_test_window();
        native_prepare_test_window(); // repeated preparation must not replace the saved IMPs
        assert(native_test_window_screen == expected);
        NSApp.activationPolicy = NSApplicationActivationPolicyRegular;
        [NSApp activateIgnoringOtherApps:YES]; // Sokol startup sequence
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed = NO;
        [window makeKeyAndOrderFront:nil];
        NSSize size = window.frame.size;
        assert(window.visible);
        assert(fabs(NSMaxY(window.frame) - NSMaxY(expected.visibleFrame)) < 1);
        assert(fabs(NSMinX(window.frame) - MAX(NSMinX(expected.visibleFrame),
            NSMaxX(expected.visibleFrame) - size.width)) < 1);
        assert(window.contentView.bounds.size.width == 800);
        assert(window.contentView.bounds.size.height == 600);
        // Exercise the same view-snapshot mechanism while the app is inactive.
        NSBitmapImageRep *bitmap = [window.contentView bitmapImageRepForCachingDisplayInRect:window.contentView.bounds];
        [window.contentView cacheDisplayInRect:window.contentView.bounds toBitmapImageRep:bitmap];
        assert(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0);
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        assert(NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier == foreground);
        assert(!NSApp.active);
        native_finish_test_window();
        native_finish_test_window();
        assert(method_getImplementation(class_getInstanceMethod(NSApplication.class,
            @selector(activateIgnoringOtherApps:))) == activate);
        assert(method_getImplementation(class_getInstanceMethod(NSWindow.class,
            @selector(makeKeyAndOrderFront:))) == order);
        // Positioning preserves an oversized viewport instead of resizing it.
        [window setContentSize:NSMakeSize(2200, 600)];
        native_test_window_position(window, left);
        assert(window.contentView.bounds.size.width == 2200);
        assert(NSMinX(window.frame) == NSMinX(left.visibleFrame));
        [window close];
        [window release];
        printf("PASS display selection, viewport placement, inactive capture and startup-hook restoration (%lu live displays)\n",
            (unsigned long)NSScreen.screens.count);
        [primary release];
        [left release];
        [above release];
        [mirror release];
    }
}
