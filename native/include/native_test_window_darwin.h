#ifndef VOX_NATIVE_TEST_WINDOW_DARWIN_H
#define VOX_NATIVE_TEST_WINDOW_DARWIN_H
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

static NSScreen *native_test_window_screen;
static IMP native_test_window_original_activate;
static IMP native_test_window_original_order;

// Snapshot the pointer's display before Sokol activates the application. In a
// mirrored arrangement there is no independent display to move the test onto.
static NSScreen *native_test_window_other_screen(NSArray<NSScreen *> *screens,
    NSPoint pointer, NSScreen *fallback) {
    NSScreen *active = fallback ?: screens.firstObject;
    for (NSScreen *screen in screens) {
        if (NSPointInRect(pointer, screen.frame)) {
            active = screen;
            break;
        }
    }
    for (NSScreen *screen in screens) {
        if (screen != active && !NSEqualRects(screen.frame, active.frame))
            return screen;
    }
    return active;
}

static void native_test_window_position(NSWindow *window, NSScreen *screen) {
    if (!window || !screen) return;
    NSRect visible = screen.visibleFrame;
    NSRect frame = window.frame;
    // Preserve the requested viewport size, including on a smaller display.
    [window setFrameOrigin:NSMakePoint(MAX(NSMinX(visible), NSMaxX(visible) - NSWidth(frame)),
        NSMaxY(visible) - NSHeight(frame))];
}

static void native_test_window_ignore_activation(id application, SEL selector, BOOL flag) {
    (void)application;
    (void)selector;
    (void)flag;
}

static void native_test_window_order(NSWindow *window, SEL selector, id sender) {
    (void)selector;
    NSScreen *screen = native_test_window_screen;
    if (![[NSScreen screens] containsObject:screen]) screen = window.screen;
    native_test_window_position(window, screen);
    // Key status inside the inactive application preserves caret rendering.
    // Neither call activates the application or replaces the user's focus.
    [window makeKeyWindow];
    [window orderFront:sender];
}

void native_prepare_test_window(void) {
    if (native_test_window_original_activate) return;
    [NSApplication sharedApplication];
    native_test_window_screen = native_test_window_other_screen(NSScreen.screens,
        NSEvent.mouseLocation, NSScreen.mainScreen);
#if !__has_feature(objc_arc)
    [native_test_window_screen retain];
#endif
    // Sokol unconditionally calls both methods before its init callback. Limit
    // these replacements to test startup, then restore AppKit's implementations.
    native_test_window_original_activate = method_setImplementation(
        class_getInstanceMethod(NSApplication.class, @selector(activateIgnoringOtherApps:)),
        (IMP)native_test_window_ignore_activation);
    native_test_window_original_order = method_setImplementation(
        class_getInstanceMethod(NSWindow.class, @selector(makeKeyAndOrderFront:)),
        (IMP)native_test_window_order);
}

void native_finish_test_window(void) {
    if (!native_test_window_original_activate) return;
    method_setImplementation(class_getInstanceMethod(NSApplication.class,
        @selector(activateIgnoringOtherApps:)), native_test_window_original_activate);
    method_setImplementation(class_getInstanceMethod(NSWindow.class,
        @selector(makeKeyAndOrderFront:)), native_test_window_original_order);
    native_test_window_original_activate = NULL;
    native_test_window_original_order = NULL;
#if !__has_feature(objc_arc)
    [native_test_window_screen release];
#endif
    native_test_window_screen = nil;
}
#endif
