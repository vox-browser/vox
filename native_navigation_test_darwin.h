#pragma once
#import <Cocoa/Cocoa.h>

// Window-coordinate click replay needs a native viewport, even when the test
// dispatches input directly without entering AppKit's application run loop.
static void *vox_navigation_test_window(void) {
	[NSApplication sharedApplication];
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 312)
		styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.releasedWhenClosed = NO;
	return (__bridge_retained void *)window;
}

static void vox_navigation_test_close_window(void *handle) {
	NSWindow *window = (__bridge NSWindow *)handle;
	[window close];
	CFRelease(handle);
}
