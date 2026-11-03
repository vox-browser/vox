#import <Cocoa/Cocoa.h>
#include <assert.h>

// The real backend's subclass boundary, without starting its event loop.
static unsigned initializations, close_requests;
@interface _sapp_macos_window : NSWindow
@end
@implementation _sapp_macos_window
- (instancetype)initWithContentRect:(NSRect)rect styleMask:(NSWindowStyleMask)style
    backing:(NSBackingStoreType)backing defer:(BOOL)defer {
    ++initializations;
    return [super initWithContentRect:rect styleMask:style backing:backing defer:defer];
}
@end
@interface HostDelegate : NSObject <NSWindowDelegate>
@end
@implementation HostDelegate
- (BOOL)windowShouldClose:(NSWindow *)window { (void)window; ++close_requests; return YES; }
@end
#include "../native_browser_chrome_style_darwin.h"

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    setenv("VOX_TITLED_BROWSER_HOST", "1", 1);
    assert(!native_browser_chrome_configure_window_host());
    unsetenv("VOX_TITLED_BROWSER_HOST");
    assert(native_browser_chrome_configure_window_host());
    assert(native_browser_chrome_configure_window_host());
    NSWindow *window = [[_sapp_macos_window alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    HostDelegate *delegate = [HostDelegate new]; window.delegate = delegate;
    assert(initializations == 1);
    assert(!(window.styleMask & NSWindowStyleMaskTitled));
    assert(window.styleMask & NSWindowStyleMaskClosable);
    assert(window.styleMask & NSWindowStyleMaskMiniaturizable);
    assert(window.styleMask & NSWindowStyleMaskResizable);
    assert(window.styleMask & NSWindowStyleMaskFullSizeContentView);
    assert(window.collectionBehavior & NSWindowCollectionBehaviorFullScreenPrimary);
    assert(window.canBecomeKeyWindow && window.canBecomeMainWindow);
    assert(NSEqualSizes(window.contentView.bounds.size, NSMakeSize(800,600)));
    native_browser_chrome_prepare_window((__bridge void *)window.contentView);
    window.minSize = NSMakeSize(640,480);
    [window setContentSize:NSMakeSize(900,700)];
    assert(NSEqualSizes(window.contentView.bounds.size, NSMakeSize(900,700)));
    assert(NSEqualSizes(window.minSize, NSMakeSize(640,480)));
    native_browser_chrome_restore_window();
    assert(!(window.styleMask & NSWindowStyleMaskTitled));
    [window performClose:nil];
    assert(close_requests == 1);
    // Ordinary AppKit windows retain their normal title bar and focus policy.
    NSWindow *ordinary = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    ordinary.releasedWhenClosed = NO;
    assert(ordinary.styleMask & NSWindowStyleMaskTitled);
    assert(initializations == 1);
    [ordinary close];
    puts("PASS UI2 window host dimensions, capabilities, focus, resizing, close delegate and ordinary-window isolation");
} return 0; }
