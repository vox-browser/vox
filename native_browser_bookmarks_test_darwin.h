#pragma once
#include "native_address_bar_test_darwin.h"

// Inspect controls created by UI2, with no bookmark implementation classes.
static int native_test_bookmark_bar_geometry(void *control, int width, int top) {
	NSView *bar = (__bridge NSView *)control;
	return bar && bar.superview && NSEqualRects(bar.frame, NSMakeRect(0, top, width, 28));
}

static int native_test_bookmark_has_favicon(void *control) {
	NSImage *image = [(__bridge NSButton *)control image];
	return image && !image.isTemplate && image.size.width > 0 && image.size.height > 0;
}

static void native_test_bookmark_capture(void *control, const char *path) {
	NSView *view = (__bridge NSView *)control;
	NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
	[view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
	[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
		writeToFile:[NSString stringWithUTF8String:path] atomically:YES];
}
