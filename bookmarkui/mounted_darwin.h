#pragma once
#include "../native/include/native_browser_bookmarks_test_darwin.h"

static int bookmark_test_icon_size(void *control) {
	NSButton *button = (__bridge NSButton *)control;
	NSImage *image = button.image;
	NSRect drawn = [button.cell imageRectForBounds:button.bounds];
	return image && !image.isTemplate && NSEqualSizes(image.size, NSMakeSize(16, 16))
		&& button.imageScaling == NSImageScaleProportionallyDown
		&& drawn.size.width > 0 && drawn.size.width <= 16
		&& drawn.size.height > 0 && drawn.size.height <= 16;
}
