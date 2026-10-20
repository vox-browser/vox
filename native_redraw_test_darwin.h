#ifndef VOX_NATIVE_REDRAW_TEST_DARWIN_H
#define VOX_NATIVE_REDRAW_TEST_DARWIN_H

// V can emit test headers before the native implementation's late include.
// These declarations refer to its existing translation-unit state and wake.
static NSView *native_cached_browser_view;
void native_wake_browser(void);

// Test-only doubles avoid opening a window or changing focus. The retained
// drawable still owns a window while AppKit exposes neither main nor key.
@interface VoxNativeRedrawTestView : NSObject
@property(nonatomic, assign) id owningWindow;
@property(nonatomic, copy) NSArray *children;
@property(nonatomic) NSUInteger redrawCount;
@end

@implementation VoxNativeRedrawTestView
- (BOOL)isHidden { return NO; }
- (NSRect)bounds { return NSMakeRect(0, 0, 320, 200); }
- (id)window { return self.owningWindow; }
- (NSArray *)subviews { return self.children ?: @[]; }
- (void)setNeedsDisplay:(BOOL)value { if (value) self.redrawCount++; }
@end

@interface VoxNativeRedrawTestWindow : NSObject
@property(nonatomic, assign) id drawableRoot;
@end

@implementation VoxNativeRedrawTestWindow
- (id)contentView { return self.drawableRoot; }
- (NSInteger)windowNumber { return 73; }
@end

@interface VoxNativeRedrawTestApplication : NSObject
@property(nonatomic) NSUInteger postedEvents;
@property(nonatomic) NSInteger postedWindowNumber;
@end

@implementation VoxNativeRedrawTestApplication
- (NSWindow *)mainWindow { return nil; }
- (NSWindow *)keyWindow { return nil; }
- (NSArray *)windows { return @[]; }
- (void)postEvent:(NSEvent *)event atStart:(BOOL)atStart {
	(void)atStart;
	self.postedEvents++;
	self.postedWindowNumber = event.windowNumber;
}
@end

static int native_test_async_redraw_without_active_window(void) {
	if (![NSThread isMainThread]) return -1;
	@autoreleasepool {
		NSApplication *saved_application = NSApp;
		NSView *saved_drawable = native_cached_browser_view;
		VoxNativeRedrawTestApplication *application = [[VoxNativeRedrawTestApplication alloc] init];
		VoxNativeRedrawTestWindow *window = [[VoxNativeRedrawTestWindow alloc] init];
		VoxNativeRedrawTestView *root = [[VoxNativeRedrawTestView alloc] init];
		VoxNativeRedrawTestView *drawable = [[VoxNativeRedrawTestView alloc] init];
		window.drawableRoot = root;
		root.children = @[drawable];
		root.owningWindow = window;
		drawable.owningWindow = window;
		NSApp = (NSApplication *)application;
		native_cached_browser_view = (NSView *)drawable;
		// Exercise the same main-queue wake that a background fetch posts after
		// placing its completed result in the browser's resource channel.
		native_wake_browser();
		for (unsigned i = 0; i < 1024; ++i) native_wake_browser();
		CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + 1.0;
		while (application.postedEvents == 0 && CFAbsoluteTimeGetCurrent() < deadline)
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
		int result = 0;
		if (root.redrawCount > 0) result |= 1;
		if (drawable.redrawCount > 0) result |= 2;
		// Other cases can leave legitimate native wakes on the main queue.
		if (application.postedEvents >= 1 && application.postedWindowNumber == 73)
			result |= 4;
		if (application.postedEvents == 1) result |= 8;
		native_wake_browser();
		while (application.postedEvents < 2 && CFAbsoluteTimeGetCurrent() < deadline)
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
		if (application.postedEvents == 2) result |= 16;
		NSApp = saved_application;
		native_cached_browser_view = saved_drawable;
#if !__has_feature(objc_arc)
		[drawable release];
		[root release];
		[window release];
		[application release];
#endif
		return result;
	}
}

#endif
