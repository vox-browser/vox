#import <Cocoa/Cocoa.h>
#include <assert.h>
#include "../native/include/native_layer_presentation_darwin.h"
// The full browser's Sokol view supplies this class. The redraw fixture uses
// its class identity to distinguish the document canvas from sibling controls.
@interface MyView2 : NSView
@end
@implementation MyView2
@end
static NSView *native_cached_browser_view;
#include "browser_view_functions.inc"
#include "native_browser_view_cache_test.h"
#include "../native/include/native_redraw_test_darwin.h"
@interface VoxWindowSelectionApplication : NSObject
@property(nonatomic, strong) NSWindow *helper;
@property(nonatomic, strong) NSWindow *browser;
@property BOOL active;
@end
@implementation VoxWindowSelectionApplication
- (NSWindow *)mainWindow { return self.active ? self.helper : nil; }
- (NSWindow *)keyWindow { return self.active ? self.helper : nil; }
- (NSArray *)windows { return @[self.helper, self.browser]; }
@end
int main(void) { @autoreleasepool {
    assert(native_test_async_redraw_without_active_window() == 31);
    [NSApplication sharedApplication];
    assert(vox_test_replaced_browser_view());
    NSWindow *browser = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    NSWindow *helper = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,16) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    browser.releasedWhenClosed = NO; helper.releasedWhenClosed = NO;
    NSApplication *original = NSApp;
    VoxWindowSelectionApplication *fake = [VoxWindowSelectionApplication new];
    fake.browser = browser; fake.helper = helper;
    native_cached_browser_view = browser.contentView;
    NSApp = (NSApplication *)fake;
    for (int cycle = 0; cycle < 10; ++cycle) {
        fake.active = cycle % 2;
        NSView *selected = native_browser_view();
        assert(selected == browser.contentView);
        assert(selected.bounds.size.width == 800 && selected.bounds.size.height == 600);
    }
    NSApp = original;
    native_cached_browser_view = nil;
    [helper close]; [browser close];
    puts("PASS browser window survives auxiliary key/main windows and content-view replacement");
} }
