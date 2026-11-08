#pragma once
#include "../../native/include/native_address_bar_test_darwin.h"

@interface UI2ReopenTestDelegate : NSObject <NSApplicationDelegate>
@end
@implementation UI2ReopenTestDelegate
@end

static id ui2_test_previous_delegate;
static id ui2_test_reopen_delegate;
static void ui2_test_reopen_begin(void) {
    ui2_test_previous_delegate = NSApp.delegate;
    ui2_test_reopen_delegate = [UI2ReopenTestDelegate new];
    NSApp.delegate = ui2_test_reopen_delegate;
}
static void ui2_test_reopen_end(void) {
    NSApp.delegate = ui2_test_previous_delegate;
    ui2_test_reopen_delegate = nil;
    ui2_test_previous_delegate = nil;
}
static int32_t ui2_test_reopen(int32_t visible) {
    return [NSApp.delegate applicationShouldHandleReopen:NSApp hasVisibleWindows:visible != 0];
}
static void ui2_test_reopen_hide(void *handle) {
    [(__bridge NSWindow *)handle orderOut:nil];
}
static int32_t ui2_test_reopen_minimize(void *handle) {
    NSWindow *window = (__bridge NSWindow *)handle;
    window.styleMask |= NSWindowStyleMaskMiniaturizable;
    [window miniaturize:nil];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!window.miniaturized && deadline.timeIntervalSinceNow > 0)
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    return window.miniaturized;
}
static int32_t ui2_test_reopen_visible(void *handle) {
    NSWindow *window = (__bridge NSWindow *)handle;
    return window.visible && !window.miniaturized;
}
