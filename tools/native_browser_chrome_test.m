#import <Cocoa/Cocoa.h>
#include "../native_browser_chrome_style_darwin.h"
#include <assert.h>

// Only the OS host boundary remains native. UI2 widgets are exercised by
// browserui/mounted_darwin_test.v and main_address_bar_test.v.
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    NSWindowStyleMask originalMask = window.styleMask;
    NSRect originalContent = window.contentView.bounds;
    native_browser_chrome_prepare_window((__bridge void *)window.contentView);
    assert(window.titleVisibility == NSWindowTitleHidden);
    assert(window.styleMask & NSWindowStyleMaskFullSizeContentView);
    assert(NSEqualSizes(window.contentView.bounds.size, originalContent.size));
    for (int i=0;i<3;++i) assert([window standardWindowButton:(NSWindowButton)i].hidden);
    native_browser_chrome_prepare_window((__bridge void *)window.contentView);
    native_browser_chrome_restore_window();
    assert(window.styleMask == originalMask);
    for (int i=0;i<3;++i) assert(![window standardWindowButton:(NSWindowButton)i].hidden);
    native_browser_chrome_restore_window();
    [window close];
} return 0; }
