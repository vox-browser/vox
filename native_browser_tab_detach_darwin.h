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
static void native_position_detached_tab(double x, double y) {
	if (getenv("VOX_TEST_WINDOW")) return;
	NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
	if (!window) return;
	NSPoint topLeft = NSMakePoint(x - 100, y + 48);
	for (NSScreen *screen in NSScreen.screens) {
		if (!NSPointInRect(NSMakePoint(x, y), screen.frame)) continue;
		NSRect visible = screen.visibleFrame;
		topLeft.x = MAX(NSMinX(visible), MIN(topLeft.x, NSMaxX(visible) - window.frame.size.width));
		topLeft.y = MIN(NSMaxY(visible), MAX(topLeft.y, NSMinY(visible) + window.frame.size.height));
		break;
	}
	[window setFrameTopLeftPoint:topLeft];
	[window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}
