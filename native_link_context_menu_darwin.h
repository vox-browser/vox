#pragma once
#import <Cocoa/Cocoa.h>

@interface VoxLinkContextMenu : NSMenu
@property(nonatomic) NSInteger selectedAction;
- (void)openLinkInNewTab:(NSMenuItem *)sender;
- (void)copyLinkURL:(NSMenuItem *)sender;
@end

@implementation VoxLinkContextMenu
- (void)openLinkInNewTab:(NSMenuItem *)sender {
	(void)sender;
	self.selectedAction = 1;
}
- (void)copyLinkURL:(NSMenuItem *)sender {
	NSString *url = sender.representedObject;
	if (![url isKindOfClass:[NSString class]]) return;
	NSPasteboard *board = [NSPasteboard generalPasteboard];
	[board clearContents];
	[board setString:url forType:NSPasteboardTypeString];
}
@end

// Returned with ownership, including in the non-ARC browser build. Capturing an
// NSString here keeps DOM and arena-backed V strings out of menu callbacks.
static VoxLinkContextMenu *native_create_link_context_menu(const unsigned char *bytes, int length) {
	if (!bytes || length <= 0) return nil;
	NSString *url = [[NSString alloc] initWithBytes:bytes length:(NSUInteger)length encoding:NSUTF8StringEncoding];
	if (!url) return nil;
	VoxLinkContextMenu *menu = [[VoxLinkContextMenu alloc] initWithTitle:@"Link"];
	menu.autoenablesItems = NO;
	NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:@"Open Link in New Tab"
		action:@selector(openLinkInNewTab:) keyEquivalent:@""];
	open.target = menu;
	[menu addItem:open];
	NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:@"Copy Link URL"
		action:@selector(copyLinkURL:) keyEquivalent:@""];
	copy.target = menu;
	copy.representedObject = url;
	[menu addItem:copy];
#if !__has_feature(objc_arc)
	[open release];
	[copy release];
	[url release];
#endif
	return menu;
}

// Return the chosen tab action after menu tracking ends. V then uses its normal
// tab queue, outside AppKit's nested menu callbacks.
static int native_browser_link_context_menu(NSView *view, const unsigned char *bytes, int length,
	double x, double y) {
	if (!view.window) return 0;
	@autoreleasepool {
		VoxLinkContextMenu *menu = native_create_link_context_menu(bytes, length);
		if (!menu) return 0;
		NSPoint point = NSMakePoint(x, view.isFlipped ? y : NSMaxY(view.bounds) - y);
		[menu popUpMenuPositioningItem:nil atLocation:point inView:view];
		int action = (int)menu.selectedAction;
#if !__has_feature(objc_arc)
		[menu release];
#endif
		return action;
	}
}
