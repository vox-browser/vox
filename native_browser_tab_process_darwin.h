#pragma once
#import <Cocoa/Cocoa.h>
static void vox_tab_window_prepare(void *handle) {
    NSWindow *window = (__bridge NSWindow *)handle;
    window.alphaValue = 0;
    window.ignoresMouseEvents = YES;
}
static void vox_tab_window_frame(void *handle, double *values) {
    NSRect frame = [(__bridge NSWindow *)handle frame];
    values[0] = frame.origin.x; values[1] = frame.origin.y;
    values[2] = frame.size.width; values[3] = frame.size.height;
}
static void vox_tab_window_show(void *handle, int visible, double x, double y, double w, double h) {
    NSWindow *window = (__bridge NSWindow *)handle;
    if (!visible) { [window orderOut:nil]; window.alphaValue = 1; window.ignoresMouseEvents = NO; return; }
    window.alphaValue = 1; window.ignoresMouseEvents = NO;
    if (w > 0 && h > 0) [window setFrame:NSMakeRect(x,y,w,h) display:YES];
    [window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
