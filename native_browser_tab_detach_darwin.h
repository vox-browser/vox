#pragma once
#include <Cocoa/Cocoa.h>

static bool native_open_tab_window(const char *executable, const char *session) {
	NSTask *task = [NSTask new];
	task.executableURL = [NSURL fileURLWithPath:[NSString stringWithUTF8String:executable]];
	task.arguments = @[@"--restore-tab", [NSString stringWithUTF8String:session]];
	BOOL launched = [task launchAndReturnError:NULL];
#if !__has_feature(objc_arc)
	[task release];
#endif
	return launched;
}
static double native_tab_drop_x(void) { return NSEvent.mouseLocation.x; }
static double native_tab_drop_y(void) { return NSEvent.mouseLocation.y; }
static void native_position_detached_frame(double x, double top) {
	NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
	[window setFrameTopLeftPoint:NSMakePoint(x,top)];
	[window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}
static void native_detached_window_size(double *width, double *height) {
	NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
	*width=window.frame.size.width; *height=window.frame.size.height;
}
