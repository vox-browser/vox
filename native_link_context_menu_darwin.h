#pragma once
#import <Cocoa/Cocoa.h>

@interface VoxLinkContextMenu : NSMenu
- (void)copyLinkURL:(NSMenuItem *)sender;
@end

@implementation VoxLinkContextMenu
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
	NSMenuItem *copy = [[NSMenuItem alloc] initWithTitle:@"Copy Link URL"
		action:@selector(copyLinkURL:) keyEquivalent:@""];
	copy.target = menu;
	copy.representedObject = url;
	[menu addItem:copy];
#if !__has_feature(objc_arc)
	[copy release];
	[url release];
#endif
	return menu;
}

static void native_browser_link_context_menu(NSView *view, const unsigned char *bytes, int length,
	double x, double y) {
	if (!view.window) return;
	@autoreleasepool {
		VoxLinkContextMenu *menu = native_create_link_context_menu(bytes, length);
		if (!menu) return;
		NSPoint point = NSMakePoint(x, view.isFlipped ? y : NSMaxY(view.bounds) - y);
		[menu popUpMenuPositioningItem:nil atLocation:point inView:view];
#if !__has_feature(objc_arc)
		[menu release];
#endif
	}
}
