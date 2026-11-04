#pragma once
#import <Cocoa/Cocoa.h>
#include <stdint.h>
// Shared native state; see platform/native_state.h in Vox. The adapter is staged
// outside the repository, so it repeats those definitions.
#ifndef VOX_NATIVE_STATE_H
#define VOX_NATIVE_STATE_H
#if defined(V_PARALLEL_CC) && !defined(V_PARALLEL_CC_OUT_0)
#define VOX_NATIVE_STATE extern
#define VOX_NATIVE_STATE_INIT(...)
#elif defined(V_PARALLEL_CC)
#define VOX_NATIVE_STATE
#define VOX_NATIVE_STATE_INIT(...) = __VA_ARGS__
#else
#define VOX_NATIVE_STATE static
#define VOX_NATIVE_STATE_INIT(...) = __VA_ARGS__
#endif
#endif
// Generic normalized-event delivery for an existing host window. UI policy is V.
typedef int32_t (*UI2EmbeddedKey)(void *);
VOX_NATIVE_STATE id ui2_embedded_key_monitor;
static void ui2_remove_embedded_key_monitor(void) {
    if (ui2_embedded_key_monitor) [NSEvent removeMonitor:ui2_embedded_key_monitor];
    ui2_embedded_key_monitor = nil;
}
static void ui2_install_embedded_key_monitor(void *handle, UI2EmbeddedKey callback) {
    ui2_remove_embedded_key_monitor();
    #if __has_feature(objc_arc)
    __weak NSWindow *window = (__bridge NSWindow *)handle;
    #else
    NSWindow *window = (__bridge NSWindow *)handle;
    #endif
    ui2_embedded_key_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
        if (!window) return event;
        return callback((__bridge void *)event) ? nil : event;
    }];
}
typedef int32_t (*UI2EmbeddedWheel)(void *);
VOX_NATIVE_STATE id ui2_embedded_wheel_monitor;
static void ui2_remove_embedded_wheel_monitor(void) {
    if (ui2_embedded_wheel_monitor) [NSEvent removeMonitor:ui2_embedded_wheel_monitor];
    ui2_embedded_wheel_monitor=nil;
}
static void ui2_install_embedded_wheel_monitor(UI2EmbeddedWheel callback) {
    ui2_remove_embedded_wheel_monitor();
    ui2_embedded_wheel_monitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskScrollWheel handler:^NSEvent *(NSEvent *event) {
        return callback((__bridge void *)event) ? nil : event;
    }];
}

static int32_t ui2_embedded_edit(void *handle, const char *action) {
    NSEvent *event=(__bridge NSEvent *)handle;
    NSResponder *responder=event.window.firstResponder;
    if (![responder isKindOfClass:NSTextView.class]) return 0;
    return [responder tryToPerform:NSSelectorFromString([NSString stringWithUTF8String:action]) with:nil];
}
