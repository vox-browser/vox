#pragma once
#include <Cocoa/Cocoa.h>

static void *ui2_test_window(void) {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    return (__bridge_retained void *)window;
}
static void *ui2_test_parent(void *window) { return (__bridge void *)[(__bridge NSWindow *)window contentView]; }
static void ui2_test_close(void *window) { [(__bridge NSWindow *)window close]; CFRelease(window); }
static int ui2_test_flat_hover(void *control) {
    NSButton *button = (__bridge NSButton *)control;
    return [button isKindOfClass:NSButton.class] && button.bezelStyle == NSBezelStyleRecessed
        && button.showsBorderOnlyWhileMouseInside;
}
