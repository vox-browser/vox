#pragma once
#include <Cocoa/Cocoa.h>
#include <objc/runtime.h>
#include <stdlib.h>

// UI2 owns the whole content area. Its Sokol host does not need a native title
// bar, but still needs the capabilities normally supplied by a titled window.
// Adapt only Sokol's window subclass; ordinary AppKit/UI2 windows are untouched.
typedef id (*VoxChromeWindowInitializer)(id __attribute__((ns_consumed)), SEL,
    NSRect, NSWindowStyleMask, NSBackingStoreType, BOOL) __attribute__((ns_returns_retained));
static VoxChromeWindowInitializer vox_chrome_original_window_init;
static void (*vox_chrome_original_perform_close)(id, SEL, id);

static BOOL vox_chrome_host_accepts_focus(id window, SEL selector) {
    (void)window; (void)selector;
    return YES;
}

static void vox_chrome_host_perform_close(id self, SEL selector, id sender) {
    NSWindow *window = self;
    if (window.styleMask & NSWindowStyleMaskTitled) {
        vox_chrome_original_perform_close(self, selector, sender);
        return;
    }
    // AppKit's performClose checks its standard button. This host has no title
    // bar/button, so deliver the same close request to the existing delegate.
    if (!(window.styleMask & NSWindowStyleMaskClosable)) return;
    id<NSWindowDelegate> delegate = window.delegate;
    if (![delegate respondsToSelector:@selector(windowShouldClose:)] || [delegate windowShouldClose:window])
        [window close];
}

static id vox_chrome_initialize_window_host(id __attribute__((ns_consumed)) self,
    SEL selector, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing,
    BOOL defer) __attribute__((ns_returns_retained));
static id vox_chrome_initialize_window_host(id __attribute__((ns_consumed)) self,
    SEL selector, NSRect rect, NSWindowStyleMask style, NSBackingStoreType backing, BOOL defer) {
    if (!(style & NSWindowStyleMaskTitled)) {
        style |= NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
            | NSWindowStyleMaskResizable | NSWindowStyleMaskFullSizeContentView;
    }
    NSWindow *window = vox_chrome_original_window_init(self, selector, rect, style, backing, defer);
    if (window && !(style & NSWindowStyleMaskTitled))
        window.collectionBehavior |= NSWindowCollectionBehaviorFullScreenPrimary;
    return window;
}

static BOOL native_browser_chrome_configure_window_host(void) {
    if (getenv("VOX_TITLED_BROWSER_HOST")) return NO;
    if (vox_chrome_original_window_init) return YES;
    Class host = objc_lookUpClass("_sapp_macos_window");
    if (!host) return NO;
    SEL initialize = @selector(initWithContentRect:styleMask:backing:defer:);
    Method method = class_getInstanceMethod(host, initialize);
    // Preserve an unfamiliar backend's focus policy rather than replacing it.
    Class parent = class_getSuperclass(host);
    for (NSString *name in @[@"canBecomeKeyWindow", @"canBecomeMainWindow"]) {
        SEL focus = NSSelectorFromString(name);
        if (class_getMethodImplementation(host, focus) != class_getMethodImplementation(parent, focus)) return NO;
    }
    if (!method) return NO;
    vox_chrome_original_window_init = (void *)method_getImplementation(method);
    Method close = class_getInstanceMethod(host, @selector(performClose:));
    vox_chrome_original_perform_close = (void *)method_getImplementation(close);
    class_addMethod(host, @selector(performClose:), (IMP)vox_chrome_host_perform_close, method_getTypeEncoding(close));
    class_addMethod(host, @selector(canBecomeKeyWindow), (IMP)vox_chrome_host_accepts_focus,
        method_getTypeEncoding(class_getInstanceMethod(parent, @selector(canBecomeKeyWindow))));
    class_addMethod(host, @selector(canBecomeMainWindow), (IMP)vox_chrome_host_accepts_focus,
        method_getTypeEncoding(class_getInstanceMethod(parent, @selector(canBecomeMainWindow))));
    class_replaceMethod(host, initialize, (IMP)vox_chrome_initialize_window_host, method_getTypeEncoding(method));
    return YES;
}

// Keep the normal close delegate and window capabilities while UI2 owns its
// top row. The titled fallback also hides its unused native title bar.
#if __has_feature(objc_arc)
static __weak NSWindow *vox_chrome_styled_window;
#else
static NSWindow *vox_chrome_styled_window;
#endif
static NSWindowStyleMask vox_chrome_original_mask;
static NSWindowTitleVisibility vox_chrome_original_title_visibility;
static BOOL vox_chrome_original_transparent_titlebar;
static BOOL vox_chrome_original_buttons_hidden[3];
static NSTitlebarSeparatorStyle vox_chrome_original_separator;

static void native_browser_chrome_restore_window(void) {
	NSWindow *window = vox_chrome_styled_window;
	if (window) {
		window.styleMask = vox_chrome_original_mask;
		window.titleVisibility = vox_chrome_original_title_visibility;
		window.titlebarAppearsTransparent = vox_chrome_original_transparent_titlebar;
		window.titlebarSeparatorStyle = vox_chrome_original_separator;
		for (int i = 0; i < 3; ++i) [window standardWindowButton:(NSWindowButton)i].hidden = vox_chrome_original_buttons_hidden[i];
	}
	vox_chrome_styled_window = nil;
}

static void native_browser_chrome_prepare_window(void *parent_pointer) {
	NSWindow *window = [(__bridge NSView *)parent_pointer window];
	if (!window || window == vox_chrome_styled_window) return;
	native_browser_chrome_restore_window();
	vox_chrome_styled_window = window;
	vox_chrome_original_mask = window.styleMask;
	vox_chrome_original_title_visibility = window.titleVisibility;
	vox_chrome_original_transparent_titlebar = window.titlebarAppearsTransparent;
	vox_chrome_original_separator = window.titlebarSeparatorStyle;
	for (int i = 0; i < 3; ++i) vox_chrome_original_buttons_hidden[i] = [window standardWindowButton:(NSWindowButton)i].hidden;
	window.titleVisibility = NSWindowTitleHidden;
	window.titlebarAppearsTransparent = YES;
	window.styleMask |= NSWindowStyleMaskFullSizeContentView;
	window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
	// FullSizeContentView removes the title-bar height from the outer frame,
	// preserving the content size requested by Sokol and screenshot clients.
	for (int i = 0; i < 3; ++i) [window standardWindowButton:(NSWindowButton)i].hidden = YES;
}
