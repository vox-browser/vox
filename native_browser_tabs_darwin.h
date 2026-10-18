#pragma once
#include <Cocoa/Cocoa.h>

typedef void (*VoxTabAction)(void *, int, int);
@interface VoxTabButton : NSButton
@property BOOL selectedTab;
@property BOOL smallButton;
@end

// The low, sloping shoulders and overlapping edges follow the classic Chrome
// tab silhouette. Use native buttons for focus, tooltips and accessibility.
static NSBezierPath *vox_tab_path(NSRect r) {
	NSBezierPath *p = [NSBezierPath bezierPath];
	[p moveToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];
	[p curveToPoint:NSMakePoint(NSMinX(r)+11, NSMinY(r)+4)
		controlPoint1:NSMakePoint(NSMinX(r)+5, NSMaxY(r)-2)
		controlPoint2:NSMakePoint(NSMinX(r)+7, NSMinY(r)+4)];
	[p curveToPoint:NSMakePoint(NSMinX(r)+16, NSMinY(r))
		controlPoint1:NSMakePoint(NSMinX(r)+12, NSMinY(r)+1)
		controlPoint2:NSMakePoint(NSMinX(r)+13, NSMinY(r))];
	[p lineToPoint:NSMakePoint(NSMaxX(r)-16, NSMinY(r))];
	[p curveToPoint:NSMakePoint(NSMaxX(r)-11, NSMinY(r)+4)
		controlPoint1:NSMakePoint(NSMaxX(r)-13, NSMinY(r))
		controlPoint2:NSMakePoint(NSMaxX(r)-12, NSMinY(r)+1)];
	[p curveToPoint:NSMakePoint(NSMaxX(r), NSMaxY(r))
		controlPoint1:NSMakePoint(NSMaxX(r)-7, NSMinY(r)+4)
		controlPoint2:NSMakePoint(NSMaxX(r)-5, NSMaxY(r)-2)];
	[p closePath];
	return p;
}

@implementation VoxTabButton
- (BOOL)isFlipped { return YES; }
- (void)otherMouseDown:(NSEvent *)event {
	if (event.buttonNumber == 2 && !self.smallButton)
		[NSApp sendAction:@selector(closeTab:) to:self.target from:self];
}
- (void)drawRect:(NSRect)dirty {
	NSRect r = NSInsetRect(self.bounds, .5, .5);
	NSBezierPath *p = vox_tab_path(r);
	if (self.smallButton) {
		p = [NSBezierPath bezierPath];
		[p moveToPoint:NSMakePoint(NSMinX(r)+4, NSMinY(r))];
		[p lineToPoint:NSMakePoint(NSMaxX(r)-8, NSMinY(r))];
		[p lineToPoint:NSMakePoint(NSMaxX(r)-1, NSMaxY(r))];
		[p lineToPoint:NSMakePoint(NSMinX(r), NSMaxY(r))];
		[p closePath];
	}
	[(self.selectedTab ? [NSColor colorWithWhite:.97 alpha:1] : [NSColor colorWithWhite:.83 alpha:1]) setFill];
	[p fill];
	[[NSColor colorWithWhite:.68 alpha:1] setStroke]; [p stroke];
	if (self.selectedTab) {
		[[NSColor colorWithWhite:.97 alpha:1] setFill];
		NSRectFill(NSMakeRect(1, self.bounds.size.height-1, self.bounds.size.width-2, 1));
	}
	NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
	style.lineBreakMode = NSLineBreakByTruncatingTail;
	style.alignment = self.smallButton ? NSTextAlignmentCenter : NSTextAlignmentLeft;
	NSDictionary *attrs = @{NSFontAttributeName:[NSFont systemFontOfSize:self.smallButton ? 14 : 12],
		NSForegroundColorAttributeName:[NSColor colorWithWhite:.22 alpha:1], NSParagraphStyleAttributeName:style};
	NSRect text = NSMakeRect(self.smallButton ? 4 : 28, self.smallButton ? 1 : 6,
		self.bounds.size.width-(self.smallButton ? 8 : 56), 18);
	[self.title drawInRect:text withAttributes:attrs];
	if (!self.smallButton && self.bounds.size.width > 80) {
		[[NSColor colorWithWhite:.50 alpha:1] setStroke];
		NSBezierPath *icon = [NSBezierPath bezierPathWithRect:NSMakeRect(14, 9, 9, 11)];
		[icon stroke];
	}
}
@end

@interface VoxCloseTabButton : NSButton
@end
@implementation VoxCloseTabButton
- (void)drawRect:(NSRect)dirty {
	if (self.highlighted) {
		[[NSColor colorWithWhite:.75 alpha:1] setFill];
		[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(self.bounds, 1, 1)] fill];
	}
	[[NSColor colorWithWhite:.4 alpha:1] setStroke];
	NSBezierPath *p = [NSBezierPath bezierPath]; p.lineWidth = 1.2;
	[p moveToPoint:NSMakePoint(6, 6)]; [p lineToPoint:NSMakePoint(12, 12)];
	[p moveToPoint:NSMakePoint(12, 6)]; [p lineToPoint:NSMakePoint(6, 12)]; [p stroke];
}
@end

@interface VoxBrowserTabStrip : NSView
@property void *owner;
@property VoxTabAction callback;
- (void)selectTab:(NSButton *)sender;
- (void)closeTab:(NSButton *)sender;
- (void)newTab:(NSButton *)sender;
@end
@implementation VoxBrowserTabStrip
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
	[[NSColor colorWithWhite:.86 alpha:1] setFill]; NSRectFill(self.bounds);
	[[NSColor colorWithWhite:.68 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, self.bounds.size.height-1, self.bounds.size.width, 1));
}
- (void)selectTab:(NSButton *)sender { self.callback(self.owner, 0, (int)sender.tag); }
- (void)closeTab:(NSButton *)sender { self.callback(self.owner, 1, (int)sender.tag); }
- (void)newTab:(NSButton *)sender { self.callback(self.owner, 2, 0); }
- (void)scrollWheel:(NSEvent *)event {
	CGFloat delta = fabs(event.scrollingDeltaX) > fabs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY;
	if (fabs(delta) > .5) self.callback(self.owner, delta > 0 ? 3 : 4, 0);
}
@end

static VoxBrowserTabStrip *vox_browser_tab_strip;
static void native_browser_tabs_remove(void) {
	[vox_browser_tab_strip removeFromSuperview]; vox_browser_tab_strip = nil;
}
static void native_browser_tabs_update(void *toolbar_pointer, void *owner, VoxTabAction callback,
	int count, int selected, int first, int end, double width) {
	NSView *toolbar = (__bridge NSView *)toolbar_pointer;
	if (!toolbar) return;
	if (!vox_browser_tab_strip || vox_browser_tab_strip.superview != toolbar) {
		native_browser_tabs_remove();
		vox_browser_tab_strip = [[VoxBrowserTabStrip alloc] initWithFrame:NSZeroRect];
		[toolbar addSubview:vox_browser_tab_strip];
	}
	VoxBrowserTabStrip *strip = vox_browser_tab_strip;
	strip.owner = owner; strip.callback = callback;
	strip.frame = NSMakeRect(0, toolbar.isFlipped ? 0 : toolbar.bounds.size.height-32, toolbar.bounds.size.width, 32);
	for (NSView *child in strip.subviews.copy) [child removeFromSuperview];
	for (int i = first; i < end; ++i) {
		VoxTabButton *button = [[VoxTabButton alloc] initWithFrame:NSMakeRect(8+(i-first)*width, 5, width+8, 28)];
		button.title = @"New Tab";
		button.selectedTab = i == selected; button.bordered = NO;
		button.target = strip; button.action = @selector(selectTab:); button.tag = i;
		button.toolTip = button.title; button.accessibilityLabel = button.title;
		button.accessibilityValue = @(i == selected);
		[strip addSubview:button positioned:button.selectedTab ? NSWindowAbove : NSWindowBelow relativeTo:nil];
		VoxCloseTabButton *close = [[VoxCloseTabButton alloc] initWithFrame:NSMakeRect(width-24, 5, 18, 18)];
		close.bordered = NO; close.title = @""; close.target = strip; close.action = @selector(closeTab:);
		close.tag = i; close.toolTip = @"Close tab"; close.accessibilityLabel = [@"Close " stringByAppendingString:button.title];
		[button addSubview:close];
	}
	VoxTabButton *add = [[VoxTabButton alloc] initWithFrame:NSMakeRect(20+(end-first)*width, 10, 32, 20)];
	add.smallButton = YES; add.title = @"+"; add.bordered = NO;
	add.target = strip; add.action = @selector(newTab:); add.toolTip = @"New tab (⌘T)"; add.accessibilityLabel = @"New tab";
	[strip addSubview:add]; strip.needsDisplay = YES;
}

static void native_browser_tab_title(int index, const unsigned char *bytes, int length) {
	NSString *title = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] ?: @"New Tab";
	for (NSView *view in vox_browser_tab_strip.subviews) {
		if (![view isKindOfClass:VoxTabButton.class]) continue;
		VoxTabButton *button = (VoxTabButton *)view;
		if (button.smallButton || button.tag != index) continue;
		button.title = title; button.toolTip = title; button.accessibilityLabel = title;
		NSButton *close = (NSButton *)button.subviews.firstObject;
		close.accessibilityLabel = [@"Close " stringByAppendingString:title];
		button.needsDisplay = YES;
	}
}
