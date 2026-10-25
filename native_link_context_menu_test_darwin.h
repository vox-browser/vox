#pragma once
#include "native_link_context_menu_darwin.h"
#import <objc/runtime.h>

static IMP vox_link_test_original_popup;
static int vox_link_test_menu_count;
static int vox_link_test_choose_action;
static NSPoint vox_link_test_menu_point;
static NSArray<NSPasteboardItem *> *vox_link_test_saved_clipboard;

// Exercise the real menu's target/action without entering a modal tracking
// loop. This also lets the V test route real GG right-button events to it.
static BOOL vox_link_test_popup(id menu, SEL command, NSMenuItem *item, NSPoint point, NSView *view) {
	(void)command; (void)item; (void)view;
	vox_link_test_menu_count++;
	vox_link_test_menu_point = point;
	NSMenuItem *open = [(NSMenu *)menu itemAtIndex:0];
	NSMenuItem *copy = [(NSMenu *)menu itemAtIndex:1];
	NSCAssert([open.title isEqualToString:@"Open Link in New Tab"] && open.enabled, @"missing tab action");
	NSCAssert([copy.title isEqualToString:@"Copy Link URL"] && copy.enabled, @"missing copy action");
	NSMenuItem *selected = vox_link_test_choose_action == 2 ? open : copy;
	if (vox_link_test_choose_action) [NSApp sendAction:selected.action to:selected.target from:selected];
	return vox_link_test_choose_action != 0;
}

static void *vox_link_test_begin(void) {
	[NSApplication sharedApplication];
	Method inherited = class_getInstanceMethod(NSMenu.class, @selector(popUpMenuPositioningItem:atLocation:inView:));
	class_addMethod(VoxLinkContextMenu.class, @selector(popUpMenuPositioningItem:atLocation:inView:),
		method_getImplementation(inherited), method_getTypeEncoding(inherited));
	Method method = class_getInstanceMethod(VoxLinkContextMenu.class, @selector(popUpMenuPositioningItem:atLocation:inView:));
	vox_link_test_original_popup = method_setImplementation(method, (IMP)vox_link_test_popup);
	vox_link_test_menu_count = 0;
	vox_link_test_choose_action = 1;
	NSPasteboard *board = [NSPasteboard generalPasteboard];
	NSMutableArray *saved = [[NSMutableArray alloc] init];
	for (NSPasteboardItem *item in board.pasteboardItems) {
		NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
		for (NSPasteboardType type in item.types) {
			NSData *data = [item dataForType:type];
			if (data) [copy setData:data forType:type];
		}
		[saved addObject:copy];
#if !__has_feature(objc_arc)
		[copy release];
#endif
	}
	vox_link_test_saved_clipboard = saved;
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
		styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
	return (__bridge_retained void *)window;
}

static void vox_link_test_end(void *handle) {
	Method method = class_getInstanceMethod(VoxLinkContextMenu.class, @selector(popUpMenuPositioningItem:atLocation:inView:));
	method_setImplementation(method, vox_link_test_original_popup);
	NSPasteboard *board = [NSPasteboard generalPasteboard];
	[board clearContents];
	if (vox_link_test_saved_clipboard.count) [board writeObjects:vox_link_test_saved_clipboard];
#if !__has_feature(objc_arc)
	[vox_link_test_saved_clipboard release];
#endif
	vox_link_test_saved_clipboard = nil;
	[(__bridge NSWindow *)handle close];
	CFRelease(handle);
}

static int vox_link_test_count(void) { return vox_link_test_menu_count; }
static void vox_link_test_cancel(void) { vox_link_test_choose_action = 0; }
static void vox_link_test_open_in_new_tab(void) { vox_link_test_choose_action = 2; }
static int vox_link_test_clipboard_matches(const unsigned char *bytes, int length) {
	NSString *expected = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
	BOOL matches = [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] isEqualToString:expected];
#if !__has_feature(objc_arc)
	[expected release];
#endif
	return matches;
}
static int vox_link_test_position_matches(void *handle, double x, double y) {
	NSView *view = [(__bridge NSWindow *)handle contentView];
	return NSEqualPoints(vox_link_test_menu_point,
		NSMakePoint(x, view.isFlipped ? y : NSMaxY(view.bounds) - y));
}
