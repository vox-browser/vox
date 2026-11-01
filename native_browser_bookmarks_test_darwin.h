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

static NSImage *native_test_bookmark_icon(int index) {
	for (NSView *view in vox_bookmark_bar.subviews) {
		if ([view isKindOfClass:NSButton.class] && ((NSButton *)view).tag == index
			&& ((NSButton *)view).action == @selector(openBookmark:)) return ((NSButton *)view).image;
	}
	for (NSMenuItem *item in vox_bookmark_bar.overflow.itemArray) if (item.tag == index) return item.image;
	return nil;
}

static int native_test_bookmark_has_favicon(int index) {
	NSImage *image = native_test_bookmark_icon(index);
	return image && !image.isTemplate && NSEqualSizes(image.size, NSMakeSize(16, 16));
}

static void *native_test_bookmark_button(int index) {
	for (NSView *view in vox_bookmark_bar.subviews)
		if ([view isKindOfClass:NSButton.class] && view.tag == index) return (__bridge void *)view;
	return NULL;
}

static void native_test_bookmark_capture(const char *path) {
	NSView *view = vox_bookmark_bar;
	NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
		writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
