#pragma once
#include <Cocoa/Cocoa.h>

// Keep the normal titled-window behavior (key focus, resizing, fullscreen and
// the close delegate), while the browser owns every pixel of its top row.
static __weak NSWindow *vox_chrome_styled_window;
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
