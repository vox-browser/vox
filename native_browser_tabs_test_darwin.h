#pragma once
#include <objc/runtime.h>
#include "native_browser_tabs_darwin.h"
#include "native_address_bar_test_darwin.h"

static int native_test_tabs_count(void) {
	int count = 0;
	for (NSView *view in vox_browser_tab_strip.subviews) {
		if ([view isKindOfClass:VoxTabButton.class] && !((VoxTabButton *)view).smallButton) ++count;
	}
	return count;
}
static void native_test_tabs_click(int index, int close) {
	for (NSView *view in vox_browser_tab_strip.subviews.copy) {
		if (![view isKindOfClass:VoxTabButton.class]) continue;
		VoxTabButton *button = (VoxTabButton *)view;
		if (index == -1 && button.smallButton) { [button performClick:nil]; return; }
		if (!button.smallButton && button.tag == index) {
			if (close) [(NSButton *)button.subviews.firstObject performClick:nil];
			else [button performClick:nil];
			return;
		}
	}
}
static int native_test_tabs_geometry(void) {
	NSView *strip = vox_browser_tab_strip;
	if (!strip || strip.bounds.size.height != 29) return 0;
	for (NSView *view in strip.subviews) {
		if (NSMaxX(view.frame) > strip.bounds.size.width || NSMinX(view.frame) < 0) return 0;
	}
	return 1;
}
// Feed window-coordinate events directly: AppKit rewrites Quartz locations of
// posted synthetic mouse events when the fixture window is not on screen.
static NSArray<NSEvent *> *native_test_tab_drag_events;
static NSUInteger native_test_tab_drag_next;
static IMP native_test_tab_original_next_event;
static NSEvent *native_test_tab_next_event(id app, SEL selector, NSEventMask mask,
	NSDate *date, NSRunLoopMode mode, BOOL dequeue) {
	if (mask == (NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp)
		&& [mode isEqualToString:NSEventTrackingRunLoopMode]
		&& native_test_tab_drag_next < native_test_tab_drag_events.count) {
		NSEvent *event = native_test_tab_drag_events[native_test_tab_drag_next];
		if (dequeue) native_test_tab_drag_next++;
		return event;
	}
	return ((NSEvent *(*)(id, SEL, NSEventMask, NSDate *, NSRunLoopMode, BOOL))native_test_tab_original_next_event)
		(app, selector, mask, date, mode, dequeue);
}
static void native_test_tabs_drag(int index, double dx, double dy) {
	VoxBrowserTabStrip *strip = vox_browser_tab_strip;
	for (NSView *view in strip.subviews.copy) {
		if (![view isKindOfClass:VoxTabButton.class]) continue;
		VoxTabButton *button = (VoxTabButton *)view;
		if (button.smallButton || button.tag != index) continue;
		NSPoint start = [strip convertPoint:NSMakePoint(NSMinX(button.frame) + 35, 15) toView:nil];
		NSPoint end = NSMakePoint(start.x + dx, start.y - dy);
		NSEvent *(^event)(NSEventType, NSPoint) = ^NSEvent *(NSEventType type, NSPoint point) {
			return [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:0
				windowNumber:strip.window.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
		};
		native_test_tab_drag_events = @[event(NSEventTypeLeftMouseDragged, end), event(NSEventTypeLeftMouseUp, end)];
		native_test_tab_drag_next = 0;
		Method method = class_getInstanceMethod(NSApp.class,
			@selector(nextEventMatchingMask:untilDate:inMode:dequeue:));
		native_test_tab_original_next_event = method_setImplementation(method, (IMP)native_test_tab_next_event);
		@try {
			[button mouseDown:event(NSEventTypeLeftMouseDown, start)];
		} @finally {
			method_setImplementation(method, native_test_tab_original_next_event);
			native_test_tab_drag_events = nil;
		}
		return;
	}
}
static void native_test_tabs_snapshot(void) {
	NSView *toolbar = vox_browser_tab_strip.superview;
	NSBitmapImageRep *bitmap = [toolbar bitmapImageRepForCachingDisplayInRect:toolbar.bounds];
	[toolbar cacheDisplayInRect:toolbar.bounds toBitmapImageRep:bitmap];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"/tmp/vox-tabs-chrome.png" atomically:YES];
}
