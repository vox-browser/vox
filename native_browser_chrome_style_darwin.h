#pragma once
#include <Cocoa/Cocoa.h>

// Keep the normal titled-window behavior (key focus, resizing, fullscreen and
// the close delegate), while the browser owns every pixel of its top row.
static __weak NSWindow *vox_chrome_styled_window;
static NSWindowStyleMask vox_chrome_original_mask;
static NSWindowTitleVisibility vox_chrome_original_title_visibility;
static BOOL vox_chrome_original_transparent_titlebar;
static BOOL vox_chrome_original_buttons_hidden[3];
static NSTitlebarSeparatorStyle vox_chrome_original_separator;

@interface VoxBrowserToolbarBackground : NSView
@end
@implementation VoxBrowserToolbarBackground
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (void)drawRect:(NSRect)dirty {
	[[NSColor colorWithSRGBRed:.969 green:.969 blue:.969 alpha:1] setFill]; NSRectFill(self.bounds);
	NSRect address = NSMakeRect(78.5, 32.5, MAX(0, self.bounds.size.width-119), 22);
	NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:address xRadius:2 yRadius:2];
	[NSColor.whiteColor setFill]; [outline fill];
	[[NSColor colorWithSRGBRed:.77 green:.77 blue:.77 alpha:1] setStroke]; [outline stroke];
	[[NSColor colorWithWhite:.55 alpha:1] setStroke];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(84.5, 38.5, 9, 9)] stroke];
	NSBezierPath *info = [NSBezierPath bezierPath]; info.lineWidth = 1;
	[info moveToPoint:NSMakePoint(89, 42.5)]; [info lineToPoint:NSMakePoint(89, 46)]; [info stroke];
	[[NSColor colorWithWhite:.55 alpha:1] setFill]; NSRectFill(NSMakeRect(88.5, 40.5, 1, 1));
	[[NSColor colorWithWhite:.80 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, 59, self.bounds.size.width, 1));
}
@end
static VoxBrowserToolbarBackground *vox_chrome_toolbar_background;

static void native_browser_chrome_style_history(void *control) {
	NSButton *button = (__bridge NSButton *)control;
	button.bordered = NO;
	button.title = @"";
	button.image = [NSImage imageWithSystemSymbolName:@"clock.arrow.circlepath" accessibilityDescription:@"History"];
	button.imagePosition = NSImageOnly;
	button.contentTintColor = [NSColor colorWithWhite:.49 alpha:1];
	button.focusRingType = NSFocusRingTypeNone;
}

static void native_browser_chrome_restore_window(void) {
	[vox_chrome_toolbar_background removeFromSuperview]; vox_chrome_toolbar_background = nil;
	NSWindow *window = vox_chrome_styled_window;
	if (window) {
		window.styleMask = vox_chrome_original_mask;
		window.titleVisibility = vox_chrome_original_title_visibility;
		window.titlebarAppearsTransparent = vox_chrome_original_transparent_titlebar;
		window.titlebarSeparatorStyle = vox_chrome_original_separator;
		for (int i = 0; i < 3; ++i) [window standardWindowButton:(NSWindowButton)i].hidden = vox_chrome_original_buttons_hidden[i];
	}
	vox_chrome_styled_window = nil;
}

static void native_browser_chrome_prepare_window(void *parent_pointer) {
	NSWindow *window = [(__bridge NSView *)parent_pointer window];
	if (!window || window == vox_chrome_styled_window) return;
	native_browser_chrome_restore_window();
	vox_chrome_styled_window = window;
	vox_chrome_original_mask = window.styleMask;
	vox_chrome_original_title_visibility = window.titleVisibility;
	vox_chrome_original_transparent_titlebar = window.titlebarAppearsTransparent;
	vox_chrome_original_separator = window.titlebarSeparatorStyle;
	for (int i = 0; i < 3; ++i) vox_chrome_original_buttons_hidden[i] = [window standardWindowButton:(NSWindowButton)i].hidden;
	window.titleVisibility = NSWindowTitleHidden;
	window.titlebarAppearsTransparent = YES;
	window.styleMask |= NSWindowStyleMaskFullSizeContentView;
	window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
	// FullSizeContentView removes the title-bar height from the outer frame,
	// preserving the content size requested by Sokol and screenshot clients.
	for (int i = 0; i < 3; ++i) [window standardWindowButton:(NSWindowButton)i].hidden = YES;
}

static NSImage *vox_chrome_navigation_image(int kind) {
	static NSImage *images[3];
	if (images[kind]) return images[kind];
	images[kind] = [NSImage imageWithSize:NSMakeSize(16,16) flipped:NO drawingHandler:^BOOL(NSRect rect) {
		[[NSColor colorWithSRGBRed:.49 green:.49 blue:.49 alpha:1] setStroke];
		NSBezierPath *path = [NSBezierPath bezierPath]; path.lineWidth = 1.4;
		path.lineCapStyle = NSLineCapStyleRound; path.lineJoinStyle = NSLineJoinStyleRound;
		if (kind < 2) {
			CGFloat tip = kind == 0 ? 3.5 : 12.5, tail = kind == 0 ? 12.5 : 3.5;
			CGFloat shoulder = kind == 0 ? 7.5 : 8.5;
			[path moveToPoint:NSMakePoint(tail,8)]; [path lineToPoint:NSMakePoint(tip,8)];
			[path moveToPoint:NSMakePoint(shoulder,12)]; [path lineToPoint:NSMakePoint(tip,8)];
			[path lineToPoint:NSMakePoint(shoulder,4)]; [path stroke];
		} else {
			[path appendBezierPathWithArcWithCenter:NSMakePoint(8,8) radius:4.5 startAngle:45 endAngle:335 clockwise:NO];
			[path stroke];
			[[NSColor colorWithWhite:.49 alpha:1] setFill];
			NSBezierPath *arrow = [NSBezierPath bezierPath];
			[arrow moveToPoint:NSMakePoint(12,13)]; [arrow lineToPoint:NSMakePoint(12,8.5)];
			[arrow lineToPoint:NSMakePoint(8,12)]; [arrow closePath]; [arrow fill];
		}
		return YES;
	}];
	return images[kind];
}

static void native_browser_chrome_style_controls(void *toolbar_pointer, void *back_pointer,
	void *forward_pointer, void *reload_pointer, void *address_pointer) {
	NSView *toolbar = (__bridge NSView *)toolbar_pointer;
	if (!toolbar) return;
	toolbar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
	if (vox_chrome_toolbar_background.superview != toolbar) {
		[vox_chrome_toolbar_background removeFromSuperview];
		vox_chrome_toolbar_background = [[VoxBrowserToolbarBackground alloc] initWithFrame:toolbar.bounds];
		vox_chrome_toolbar_background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	}
	// UI2 reorders its managed children during reconciliation. Keep this native
	// background below them after every refresh, including focus/resize updates.
	[toolbar addSubview:vox_chrome_toolbar_background positioned:NSWindowBelow relativeTo:nil];
	vox_chrome_toolbar_background.frame = toolbar.bounds;
	vox_chrome_toolbar_background.needsDisplay = YES;
	NSButton *buttons[] = {(__bridge NSButton *)back_pointer, (__bridge NSButton *)forward_pointer, (__bridge NSButton *)reload_pointer};
	for (int i = 0; i < 3; ++i) {
		buttons[i].bordered = NO; buttons[i].title = @"";
		buttons[i].image = vox_chrome_navigation_image(i);
		buttons[i].imagePosition = NSImageOnly;
		buttons[i].focusRingType = NSFocusRingTypeNone;
	}
	NSTextField *address = (__bridge NSTextField *)address_pointer;
	address.bordered = NO; address.bezeled = NO; address.drawsBackground = NO;
	address.focusRingType = NSFocusRingTypeNone;
	address.font = [NSFont systemFontOfSize:12];
	address.textColor = [NSColor colorWithWhite:.22 alpha:1];
}
