#pragma once
#include "native_address_bar_test_darwin.h"
#include "native_browser_bookmarks_darwin.h"

static int native_test_bookmark_bar_geometry(int width, int top) {
	return vox_bookmark_bar != nil && vox_bookmark_bar.superview != nil
		&& NSEqualRects(vox_bookmark_bar.frame, NSMakeRect(0, top, width, 28));
}

static void native_test_bookmark_click(int index) {
	for (NSView *view in vox_bookmark_bar.subviews.copy) {
		if ([view isKindOfClass:NSButton.class] && ((NSButton *)view).tag == index) {
			[(NSButton *)view performClick:nil]; return;
		}
	}
}

static int native_test_bookmark_overflow_count(void) {
	return (int)vox_bookmark_bar.overflow.numberOfItems;
}

static int native_test_bookmark_remove_overflow(int index) {
	for (NSMenuItem *item in vox_bookmark_bar.overflow.itemArray) {
		if (item.tag != index) continue;
		for (NSMenuItem *action in item.submenu.itemArray) {
			if (action.action == @selector(removeBookmark:)) {
				[vox_bookmark_bar removeBookmark:action]; return 1;
			}
		}
	}
	return 0;
}
