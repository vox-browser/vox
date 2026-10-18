#pragma once
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
static void native_test_tabs_snapshot(void) {
	NSView *toolbar = vox_browser_tab_strip.superview;
	NSBitmapImageRep *bitmap = [toolbar bitmapImageRepForCachingDisplayInRect:toolbar.bounds];
	[toolbar cacheDisplayInRect:toolbar.bounds toBitmapImageRep:bitmap];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:@"/tmp/vox-tabs-chrome.png" atomically:YES];
}
