#pragma once
#include "native_select_picker_darwin.h"
#import <objc/runtime.h>

static IMP vox_select_test_original_popup;
static int vox_select_test_count_value;
static int vox_select_test_choice;
static NSArray<NSMenuItem *> *vox_select_test_items;
static NSPoint vox_select_test_point;
static double vox_select_test_width;

// Run the production menu's target/action without blocking in menu tracking.
static BOOL vox_select_test_popup(id menu, SEL command, NSMenuItem *item, NSPoint point, NSView *view) {
	(void)command; (void)item; (void)view;
	vox_select_test_count_value++;
	vox_select_test_point = point;
	vox_select_test_width = [menu minimumWidth];
#if !__has_feature(objc_arc)
	[vox_select_test_items release];
#endif
	vox_select_test_items = [[menu itemArray] copy];
	if (vox_select_test_choice < 0 || vox_select_test_choice >= (int)vox_select_test_items.count) return NO;
	NSMenuItem *selected = vox_select_test_items[vox_select_test_choice];
	if (!selected.enabled || !selected.action) return NO;
	return [NSApp sendAction:selected.action to:selected.target from:selected];
}

static void *vox_select_test_begin(void) {
	[NSApplication sharedApplication];
	SEL selector = @selector(popUpMenuPositioningItem:atLocation:inView:);
	Method inherited = class_getInstanceMethod(NSMenu.class, selector);
	class_addMethod(VoxSelectPicker.class, selector, method_getImplementation(inherited), method_getTypeEncoding(inherited));
	vox_select_test_original_popup = method_setImplementation(class_getInstanceMethod(VoxSelectPicker.class, selector), (IMP)vox_select_test_popup);
	vox_select_test_count_value = 0;
	vox_select_test_choice = -1;
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
		styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
#if __has_feature(objc_arc)
	return (__bridge_retained void *)window;
#else
	return window;
#endif
}

static void vox_select_test_end(void *handle) {
	method_setImplementation(class_getInstanceMethod(VoxSelectPicker.class,
		@selector(popUpMenuPositioningItem:atLocation:inView:)), vox_select_test_original_popup);
#if !__has_feature(objc_arc)
	[vox_select_test_items release];
#endif
	vox_select_test_items = nil;
	[(__bridge NSWindow *)handle close];
	CFRelease(handle);
}
static void vox_select_test_choose(int index) { vox_select_test_choice = index; }
static int vox_select_test_count(void) { return vox_select_test_count_value; }
static int vox_select_test_length(void) { return (int)vox_select_test_items.count; }
static int vox_select_test_item(int index, const unsigned char *label, int length, int enabled, int indent, int checked) {
	if (index < 0 || index >= (int)vox_select_test_items.count) return 0;
	NSMenuItem *item = vox_select_test_items[index];
	NSString *expected = [[NSString alloc] initWithBytes:label length:length encoding:NSUTF8StringEncoding];
	BOOL matches = [item.title isEqualToString:expected] && item.enabled == !!enabled &&
		item.indentationLevel == indent && (item.state == NSControlStateValueOn) == !!checked;
#if !__has_feature(objc_arc)
	[expected release];
#endif
	return matches;
}
static int vox_select_test_separator(int index) { return vox_select_test_items[index].separatorItem; }
static int vox_select_test_geometry(void *handle, double x, double y, double width) {
	NSView *view = [(__bridge NSWindow *)handle contentView];
	return NSEqualPoints(vox_select_test_point, NSMakePoint(x, view.isFlipped ? y : NSMaxY(view.bounds) - y)) &&
		fabs(vox_select_test_width - width) < 0.01;
}
