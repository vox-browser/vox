#import <Cocoa/Cocoa.h>
#include "../native_browser_chrome_style_darwin.h"
#include "../native_browser_tabs_darwin.h"
#include <assert.h>

@interface VoxChromeTestWindow : NSWindow
@property int closedCount;
@property int minimizedCount;
@property int zoomedCount;
@end
@implementation VoxChromeTestWindow
- (void)performClose:(id)sender { self.closedCount++; }
- (void)performMiniaturize:(id)sender { self.minimizedCount++; }
- (void)zoom:(id)sender { self.zoomedCount++; }
@end
@interface VoxChromeTestToolbar : NSView
@end
@implementation VoxChromeTestToolbar
- (BOOL)isFlipped { return YES; }
@end
static int tabAction;
static void tab_action(void *owner, int action, int index) { tabAction = action + 1; }

int main(void) { @autoreleasepool {
	[NSApplication sharedApplication];
	VoxChromeTestWindow *window = [[VoxChromeTestWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600)
		styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
		backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
	NSWindowStyleMask originalMask = window.styleMask;
	native_browser_chrome_prepare_window((__bridge void *)window.contentView);
	assert(window.titleVisibility == NSWindowTitleHidden);
	assert(window.styleMask & NSWindowStyleMaskFullSizeContentView);
	assert(window.frame.size.height == 600 && window.contentView.bounds.size.height == 600);
	for (int i=0; i<3; ++i) assert([window standardWindowButton:(NSWindowButton)i].hidden);
	VoxChromeTestToolbar *toolbar = [[VoxChromeTestToolbar alloc] initWithFrame:NSMakeRect(0,540,800,60)];
	[window.contentView addSubview:toolbar];
	NSButton *back = [[NSButton alloc] initWithFrame:NSMakeRect(5,33,22,22)];
	NSButton *forward = [[NSButton alloc] initWithFrame:NSMakeRect(27,33,22,22)];
	NSButton *reload = [[NSButton alloc] initWithFrame:NSMakeRect(49,33,22,22)];
	NSTextField *address = [[NSTextField alloc] initWithFrame:NSMakeRect(98,34,696,20)];
	for (NSView *control in @[back,forward,reload,address]) [toolbar addSubview:control];
	forward.enabled = NO; address.stringValue = @"chrome://apps";
	native_browser_chrome_style_controls((__bridge void *)toolbar,(__bridge void *)back,(__bridge void *)forward,
		(__bridge void *)reload,(__bridge void *)address);
	assert(!back.bordered && !forward.bordered && !reload.bordered);
	assert(back.image && forward.image && reload.image && !forward.enabled);
	assert(!address.bezeled && !address.bordered && !address.drawsBackground);
	assert([window makeFirstResponder:address]);
	NSText *editor = address.currentEditor;
	assert(editor);
	editor.selectedRange = NSMakeRange(7,4);
	// UI2 reconciles its children from the bottom on every refresh. Its first
	// child moves below our unmanaged background, followed by the other controls.
	// Styling must restore the background behind them even when it already exists.
	NSView *previous = nil;
	for (NSView *control in @[back,forward,reload,address]) {
		[toolbar addSubview:control positioned:previous ? NSWindowAbove : NSWindowBelow relativeTo:previous];
		previous = control;
	}
	native_browser_chrome_style_controls((__bridge void *)toolbar,(__bridge void *)back,(__bridge void *)forward,
		(__bridge void *)reload,(__bridge void *)address);
	assert(toolbar.subviews.firstObject == vox_chrome_toolbar_background);
	NSPoint addressPoint = [toolbar convertPoint:NSMakePoint(110,44) toView:toolbar.superview];
	NSView *addressHit = [toolbar hitTest:addressPoint];
	assert(addressHit == address || [addressHit isDescendantOf:address]);
	assert([address.stringValue isEqualToString:@"chrome://apps"]);
	assert(window.firstResponder == editor && NSEqualRanges(editor.selectedRange, NSMakeRange(7,4)));
	[window endEditingFor:address];
	assert([address.stringValue isEqualToString:@"chrome://apps"]);
	native_browser_tabs_update((__bridge void *)toolbar,NULL,tab_action,1,0,0,1,184);
	native_browser_tab_title(0,(const unsigned char *)"Apps",4);
	int windowButtons=0;
	for (NSView *view in vox_browser_tab_strip.subviews) {
		if (![view isKindOfClass:VoxBrowserWindowButton.class]) continue;
		VoxBrowserWindowButton *button = (VoxBrowserWindowButton *)view;
		assert(NSEqualRects(button.frame, NSMakeRect(10+button.windowAction*16,8,12,12)));
		NSPoint center = [button convertPoint:NSMakePoint(6,6) toView:window.contentView.superview];
		assert([window.contentView.superview hitTest:center] == button);
		[button performClick:nil]; windowButtons++;
	}
	assert(windowButtons == 3 && window.closedCount == 1 && window.minimizedCount == 1 && window.zoomedCount == 1);
	for (NSView *view in vox_browser_tab_strip.subviews.copy) {
		if ([view isKindOfClass:VoxTabButton.class] && ((VoxTabButton *)view).smallButton) [(NSButton *)view performClick:nil];
	}
	assert(tabAction == 3);
	// Resizing keeps the integrated row inside the content view.
	[window setContentSize:NSMakeSize(640,480)]; toolbar.frame = NSMakeRect(0,420,640,60);
	address.frame = NSMakeRect(98,34,536,20);
	native_browser_chrome_style_controls((__bridge void *)toolbar,(__bridge void *)back,(__bridge void *)forward,
		(__bridge void *)reload,(__bridge void *)address);
	native_browser_tabs_update((__bridge void *)toolbar,NULL,tab_action,1,0,0,1,184);
	native_browser_tab_title(0,(const unsigned char *)"Apps",4);
	NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:304 pixelsHigh:60
		bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	bitmap.size = NSMakeSize(304,60);
	// The reference is a crop of the leftmost 304 pixels of a wider window.
	[toolbar cacheDisplayInRect:NSMakeRect(0,0,304,60) toBitmapImageRep:bitmap];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"/tmp/vox-classic-chrome.png" atomically:YES];
	native_browser_tabs_remove(); native_browser_chrome_restore_window();
	assert(window.styleMask == originalMask && window.titleVisibility == NSWindowTitleVisible);
	assert(![window standardWindowButton:NSWindowCloseButton].hidden);
	[window close];
	puts("PASS: integrated title row, window actions, hit testing, compact controls, sizing and restoration");
} }
