#pragma once
#include <Cocoa/Cocoa.h>

typedef void (*VoxTabAction)(void *, int, int, int);
@interface VoxBrowserTabStrip : NSView
@property void *owner;
@property VoxTabAction callback;
@property int tabCount;
@property int firstTab;
@property int endTab;
@property int requestedFirstTab;
@property int requestedEndTab;
@property double tabWidth;
@property BOOL trackingTab;
@property BOOL draggingTab;
@property int draggedTab;
@property int dropTab;
@property CGFloat dragOffset;
@property NSPoint dragPoint;
- (void)selectTab:(NSButton *)sender;
- (void)closeTab:(NSButton *)sender;
- (void)newTab:(NSButton *)sender;
- (void)trackTab:(NSButton *)sender event:(NSEvent *)event;
- (void)layoutDraggedTab;
@end

@interface VoxTabButton : NSButton
@property BOOL selectedTab;
@property BOOL smallButton;
@property(strong) NSImage *siteIcon;
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
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (void)mouseDown:(NSEvent *)event {
	if (self.smallButton) [super mouseDown:event];
	else [(VoxBrowserTabStrip *)self.target trackTab:self event:event];
}
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
	NSDictionary *attrs = @{NSFontAttributeName:[NSFont systemFontOfSize:11],
		NSForegroundColorAttributeName:[NSColor colorWithWhite:.22 alpha:1], NSParagraphStyleAttributeName:style};
	NSRect text = NSMakeRect(self.smallButton ? 4 : 30, 3,
		self.bounds.size.width-(self.smallButton ? 8 : 56), 18);
	[self.title drawInRect:text withAttributes:attrs];
	if (!self.smallButton && self.siteIcon) {
		NSSize size = self.siteIcon.size;
		CGFloat scale = MIN(16 / MAX(1, size.width), 16 / MAX(1, size.height));
		NSRect icon = NSMakeRect(12 + (16 - size.width * scale) / 2,
			4 + (16 - size.height * scale) / 2, size.width * scale, size.height * scale);
		[self.siteIcon drawInRect:icon fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
			fraction:1 respectFlipped:YES hints:nil];
	} else if (!self.smallButton && [self.title isEqualToString:@"Apps"]) {
		NSArray<NSColor *> *colors = @[[NSColor colorWithSRGBRed:.91 green:.33 blue:.28 alpha:1],
			[NSColor colorWithSRGBRed:.96 green:.72 blue:.22 alpha:1], [NSColor colorWithSRGBRed:.28 green:.66 blue:.45 alpha:1]];
		for (int row=0; row<3; ++row) for (int col=0; col<3; ++col) {
			[colors[(row+col)%3] setFill]; NSRectFill(NSMakeRect(14+col*4, 7+row*4, 3, 3));
		}
	} else if (!self.smallButton && self.bounds.size.width > 80) {
		[[NSColor colorWithWhite:.50 alpha:1] setStroke];
		NSBezierPath *icon = [NSBezierPath bezierPathWithRect:NSMakeRect(14, 7, 9, 11)];
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
	[p moveToPoint:NSMakePoint(5, 5)]; [p lineToPoint:NSMakePoint(10, 10)];
	[p moveToPoint:NSMakePoint(10, 5)]; [p lineToPoint:NSMakePoint(5, 10)]; [p stroke];
}
@end

@interface VoxBrowserWindowButton : NSButton
@property int windowAction;
@end
@implementation VoxBrowserWindowButton
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
	NSColor *colors[] = {[NSColor colorWithSRGBRed:1 green:.37 blue:.34 alpha:1],
		[NSColor colorWithSRGBRed:1 green:.74 blue:.18 alpha:1],
		[NSColor colorWithSRGBRed:.16 green:.78 blue:.25 alpha:1]};
	[colors[self.windowAction] setFill];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1,1,10,10)] fill];
	if (self.highlighted) {
		[[NSColor colorWithWhite:0 alpha:.2] setFill];
		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1,1,10,10)] fill];
	}
}
@end

@implementation VoxBrowserTabStrip
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)dirty {
	[[NSColor colorWithWhite:.86 alpha:1] setFill]; NSRectFill(self.bounds);
	[[NSColor colorWithWhite:.68 alpha:1] setFill];
	NSRectFill(NSMakeRect(0, self.bounds.size.height-1, self.bounds.size.width, 1));
}
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (void)mouseDown:(NSEvent *)event {
	if (event.clickCount == 2) [self.window zoom:self];
	else [self.window performWindowDragWithEvent:event];
}
- (void)selectTab:(NSButton *)sender { self.callback(self.owner, 0, (int)sender.tag, 0); }
- (void)closeTab:(NSButton *)sender { self.callback(self.owner, 1, (int)sender.tag, 0); }
- (void)newTab:(NSButton *)sender { self.callback(self.owner, 2, 0, 0); }
- (void)layoutDraggedTab {
	VoxTabButton *dragged = nil;
	for (NSView *view in self.subviews) {
		if (![view isKindOfClass:VoxTabButton.class] || ((VoxTabButton *)view).smallButton) continue;
		VoxTabButton *button = (VoxTabButton *)view;
		NSInteger slot = button.tag;
		if (self.draggingTab) {
			if (slot == self.draggedTab) dragged = button;
			else if (self.draggedTab < slot && slot <= self.dropTab) slot--;
			else if (self.dropTab <= slot && slot < self.draggedTab) slot++;
		}
		NSRect frame = button.frame;
		frame.origin.x = 62 + (slot - self.firstTab) * self.tabWidth;
		if (button == dragged)
			frame.origin.x = MAX(62, MIN(self.dragPoint.x - self.dragOffset,
				62 + (self.endTab - self.firstTab - 1) * self.tabWidth));
		button.frame = frame;
		button.alphaValue = button == dragged && self.dragPoint.y >= self.bounds.size.height + 24 ? .55 : 1;
	}
	if (dragged) [self addSubview:dragged positioned:NSWindowAbove relativeTo:nil];
}
- (void)trackTab:(NSButton *)sender event:(NSEvent *)event {
	NSPoint start = [self convertPoint:event.locationInWindow fromView:nil];
	self.draggedTab = self.dropTab = (int)sender.tag;
	self.dragOffset = start.x - sender.frame.origin.x;
	self.dragPoint = start;
	self.trackingTab = YES;
	self.draggingTab = NO;
	// Selecting can rebuild every button. Track on the strip, which survives
	// chrome refreshes, rather than retaining the removed NSButton as the drag UI.
	[self selectTab:sender];
	for (;;) {
		NSEvent *next = [NSApp nextEventMatchingMask:NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp
			untilDate:NSDate.distantFuture inMode:NSEventTrackingRunLoopMode dequeue:YES];
		NSPoint point = [self convertPoint:next.locationInWindow fromView:nil];
		if (self.trackingTab) {
			self.dragPoint = point;
			self.draggingTab |= fabs(point.x - start.x) >= 4 || fabs(point.y - start.y) >= 4;
			self.dropTab = MAX(self.firstTab, MIN(self.endTab - 1,
				self.firstTab + (int)floor((point.x - 62) / self.tabWidth)));
			[self layoutDraggedTab];
		}
		if (next.type != NSEventTypeLeftMouseUp) continue;
		BOOL move = self.trackingTab && self.draggingTab && point.y >= 0 && point.y < self.bounds.size.height;
		BOOL detach = self.trackingTab && self.draggingTab && point.y >= self.bounds.size.height + 24;
		BOOL refreshRange = self.trackingTab && (self.firstTab != self.requestedFirstTab || self.endTab != self.requestedEndTab);
		int from = self.draggedTab, to = self.dropTab;
		self.trackingTab = self.draggingTab = NO;
		[self layoutDraggedTab];
		if (detach) self.callback(self.owner, 6, from, 0);
		else if (move && from != to) self.callback(self.owner, 5, from, to);
		else if (refreshRange) self.callback(self.owner, 5, from, from);
		break;
	}
}
- (void)scrollWheel:(NSEvent *)event {
	CGFloat delta = fabs(event.scrollingDeltaX) > fabs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY;
	if (fabs(delta) > .5) self.callback(self.owner, delta > 0 ? 3 : 4, 0, 0);
}
@end

static VoxBrowserTabStrip *vox_browser_tab_strip;
static void native_browser_tabs_remove(void) {
	vox_browser_tab_strip.trackingTab = vox_browser_tab_strip.draggingTab = NO;
	for (NSView *child in vox_browser_tab_strip.subviews) {
		if ([child isKindOfClass:VoxTabButton.class]) ((VoxTabButton *)child).siteIcon = nil;
	}
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
	strip.requestedFirstTab = first; strip.requestedEndTab = end;
	if (strip.trackingTab && strip.tabCount != count) strip.trackingTab = strip.draggingTab = NO;
	if (strip.trackingTab) { first = strip.firstTab; end = strip.endTab; }
	strip.tabCount = count; strip.firstTab = first; strip.endTab = end; strip.tabWidth = width;
	strip.frame = NSMakeRect(0, toolbar.isFlipped ? 0 : toolbar.bounds.size.height-29, toolbar.bounds.size.width, 29);
	for (NSView *child in strip.subviews.copy) {
		if ([child isKindOfClass:VoxTabButton.class]) ((VoxTabButton *)child).siteIcon = nil;
		[child removeFromSuperview];
	}
	for (int i = first; i < end; ++i) {
		VoxTabButton *button = [[VoxTabButton alloc] initWithFrame:NSMakeRect(62+(i-first)*width, 5, width+10, 24)];
		button.title = @"New Tab";
		button.selectedTab = i == selected; button.bordered = NO;
		button.target = strip; button.action = @selector(selectTab:); button.tag = i;
		button.toolTip = button.title; button.accessibilityLabel = button.title;
		button.accessibilityValue = @(i == selected);
		[strip addSubview:button positioned:button.selectedTab ? NSWindowAbove : NSWindowBelow relativeTo:nil];
		VoxCloseTabButton *close = [[VoxCloseTabButton alloc] initWithFrame:NSMakeRect(width-16, 3, 16, 16)];
		close.bordered = NO; close.title = @""; close.target = strip; close.action = @selector(closeTab:);
		close.tag = i; close.toolTip = @"Close tab"; close.accessibilityLabel = [@"Close " stringByAppendingString:button.title];
		[button addSubview:close];
	}
	VoxTabButton *add = [[VoxTabButton alloc] initWithFrame:NSMakeRect(74+(end-first)*width, 11, 28, 14)];
	add.smallButton = YES; add.title = @""; add.bordered = NO;
	add.target = strip; add.action = @selector(newTab:); add.toolTip = @"New tab (⌘T)"; add.accessibilityLabel = @"New tab";
	[strip addSubview:add];
	SEL actions[] = {@selector(performClose:), @selector(performMiniaturize:), @selector(zoom:)};
	NSArray<NSString *> *labels = @[@"Close window", @"Minimize window", @"Zoom window"];
	for (int i=0; i<3; ++i) {
		VoxBrowserWindowButton *control = [[VoxBrowserWindowButton alloc] initWithFrame:NSMakeRect(10+i*16,8,12,12)];
		control.windowAction = i; control.title = @""; control.bordered = NO;
		control.target = strip.window; control.action = actions[i];
		control.accessibilityLabel = labels[i]; control.toolTip = labels[i];
		[strip addSubview:control];
	}
	[strip layoutDraggedTab];
	strip.needsDisplay = YES;
}

static int native_browser_tabs_first(void) { return vox_browser_tab_strip.firstTab; }
static int native_browser_tabs_end(void) { return vox_browser_tab_strip.endTab; }

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

static void native_browser_tab_icon(int index, const unsigned char *bytes, int length) {
	NSImage *icon = length > 0 ? [[NSImage alloc] initWithData:[NSData dataWithBytes:bytes length:length]] : nil;
	for (NSView *view in vox_browser_tab_strip.subviews) {
		if (![view isKindOfClass:VoxTabButton.class]) continue;
		VoxTabButton *button = (VoxTabButton *)view;
		if (button.smallButton || button.tag != index) continue;
		button.siteIcon = icon;
		button.needsDisplay = YES;
	}
#if !__has_feature(objc_arc)
	[icon release];
#endif
}
