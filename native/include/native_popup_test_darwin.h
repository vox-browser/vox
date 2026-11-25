#pragma once
#import <Cocoa/Cocoa.h>

static void native_test_popup_post_key(NSWindow *window, unsigned short code, NSString *characters) {
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
        modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber
        context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:code];
    [NSApp postEvent:event atStart:NO];
}

static void *native_test_popup_keys(void *handle, bool choose) {
    NSWindow *window = (__bridge NSWindow *)handle;
    [window makeKeyAndOrderFront:nil];
    NSTimer *timer = [NSTimer timerWithTimeInterval:0.05 repeats:NO block:^(NSTimer *unused) {
        (void)unused;
        if (choose) {
            NSString *down = [NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey];
            native_test_popup_post_key(window, 125, down);
            native_test_popup_post_key(window, 125, down);
            native_test_popup_post_key(window, 36, @"\r");
        } else {
            native_test_popup_post_key(window, 53, @"\033");
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:timer forMode:NSEventTrackingRunLoopMode];
    return (__bridge_retained void *)timer;
}

static void native_test_popup_keys_cleanup(void *handle) {
    [(__bridge NSTimer *)handle invalidate];
    CFRelease(handle);
}
