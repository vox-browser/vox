#pragma once
#import <Cocoa/Cocoa.h>
static NSView *native_browser_view(void);
static NSView *native_cached_browser_view;

static int vox_test_replaced_browser_view(void) {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,200,100)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    [window setReleasedWhenClosed:NO];
    NSView *old = [[NSView alloc] initWithFrame:NSMakeRect(0,0,200,100)];
    NSView *replacement = [[NSView alloc] initWithFrame:NSMakeRect(0,0,200,100)];
    [window setContentView:old];
    BOOL initial = native_browser_view() == old;
    [window setContentView:replacement];
    [old setFrameSize:NSMakeSize(80,60)];
    NSView *selected = native_browser_view();
    BOOL replaced = selected == replacement && selected.bounds.size.width == 200
        && selected.bounds.size.height == 100;
    native_cached_browser_view = nil;
    [window close];
#if !__has_feature(objc_arc)
    [replacement release]; [old release]; [window release];
#endif
    return initial && replaced;
}
