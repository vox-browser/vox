#pragma once
#include "native_address_bar_darwin.h"
#include "native_browser_chrome_darwin.h"

@interface VoxAddressBarTestView : NSView
@end
@implementation VoxAddressBarTestView
- (BOOL)acceptsFirstResponder { return YES; }
@end

static void *native_test_address_window(void) {
	[NSApplication sharedApplication];
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
		styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
	window.contentView = [[VoxAddressBarTestView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
	return (__bridge_retained void *)window;
}

static void *native_test_address_parent(void *window) {
	return (__bridge void *)[(__bridge NSWindow *)window contentView];
}

static void native_test_address_close(void *window) {
	[(__bridge NSWindow *)window close];
	CFRelease(window);
}

static NSString *native_test_address_string(const unsigned char *bytes, int length) {
	return [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
}

static void native_test_address_insert(void *field, const unsigned char *bytes, int length) {
	NSTextView *editor = (NSTextView *)[(__bridge NSTextField *)field currentEditor];
	[editor insertText:native_test_address_string(bytes, length) replacementRange:editor.selectedRange];
}

static void native_test_address_submit(void *field) {
	[[(__bridge NSTextField *)field currentEditor] doCommandBySelector:@selector(insertNewline:)];
}

static void native_test_address_shortcut(void *field, void *owner, VoxAddressShortcut callback,
	unsigned short key, int shift) {
	NSWindow *window = [(__bridge NSTextField *)field window];
	NSEventModifierFlags modifiers = key == 53 ? 0 : NSEventModifierFlagCommand;
	if (shift) modifiers |= NSEventModifierFlagShift;
	NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
		modifierFlags:modifiers timestamp:0 windowNumber:window.windowNumber context:nil
		characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:key];
	native_address_bar_filter_key((__bridge NSTextField *)field, owner, callback, event);
}

static int native_test_address_geometry(void *field, int width) {
	NSRect frame = [(__bridge NSTextField *)field frame];
	return frame.origin.x == 184 && frame.origin.y == 12 && frame.size.width == width
		&& frame.size.height == 34;
}

static void native_test_chrome_click(void *control) {
	[(__bridge NSButton *)control performClick:nil];
}

static int native_test_chrome_enabled(void *control) {
	return [(__bridge NSButton *)control isEnabled];
}

static int native_test_chrome_button(void *control) {
	return [(__bridge id)control isKindOfClass:NSButton.class]
		&& [(__bridge NSButton *)control isBordered];
}

static int native_test_chrome_geometry(void *toolbar, void *status, int width, int height) {
	NSRect top = [(__bridge NSView *)toolbar frame];
	NSRect bottom = [(__bridge NSView *)status frame];
	return NSEqualRects(top, NSMakeRect(0, height - 88, width, 88))
		&& NSEqualRects(bottom, NSMakeRect(0, 0, width, 24));
}

static void native_test_chrome_resize(void *window, int width, int height) {
	[(__bridge NSWindow *)window setContentSize:NSMakeSize(width, height)];
}

static int native_test_chrome_document_hit(void *window, void *toolbar, void *status) {
	NSView *root = [(__bridge NSWindow *)window contentView];
	NSView *hit = [root hitTest:NSMakePoint(50, 100)];
	return hit == root && [root.subviews containsObject:(__bridge NSView *)toolbar]
		&& [root.subviews containsObject:(__bridge NSView *)status];
}

static int native_test_chrome_unmounted(void *window) {
	return [(__bridge NSWindow *)window contentView].subviews.count == 0
		&& vox_chrome_memory_timer == nil && vox_chrome_memory_close_observer == nil;
}

static unsigned long native_test_address_selection(void *field) {
	return [(NSTextView *)[(__bridge NSTextField *)field currentEditor] selectedRange].length;
}

static void native_test_address_backspace(void *field) {
	[[(__bridge NSTextField *)field currentEditor] deleteBackward:nil];
}

static NSArray<NSPasteboardItem *> *native_test_address_saved_clipboard;

static void native_test_address_clipboard_begin(void) {
	NSPasteboard *board = [NSPasteboard generalPasteboard];
	NSMutableArray *saved = [NSMutableArray array];
	for (NSPasteboardItem *item in board.pasteboardItems) {
		NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
		for (NSPasteboardType type in item.types) {
			NSData *data = [item dataForType:type];
			if (data != nil) [copy setData:data forType:type];
		}
		[saved addObject:copy];
	}
	native_test_address_saved_clipboard = saved;
	[board clearContents];
	[board setString:@"https://ui2-address-bar.invalid/pasted" forType:NSPasteboardTypeString];
}

static int native_test_address_clipboard_matches(void) {
	return [[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString]
		isEqualToString:@"https://ui2-address-bar.invalid/pasted"];
}

static void native_test_address_clipboard_end(void) {
	NSPasteboard *board = [NSPasteboard generalPasteboard];
	[board clearContents];
	if (native_test_address_saved_clipboard.count) [board writeObjects:native_test_address_saved_clipboard];
	native_test_address_saved_clipboard = nil;
}
