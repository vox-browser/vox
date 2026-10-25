module main

// Keep the menu's URL independent of hover state and the address field. The
// native menu owns a copy while AppKit runs its nested menu event loop.
fn (app &BrowserApp) show_link_context_menu(x f32, y f32) {
	$if macos {
		destination := app.link_at_point(x, y) or { return }
		C.native_browser_link_context_menu(C.native_browser_view(), destination.str,
			destination.len, f64(x), f64(y))
	}
}

$if macos {
	#include "native_link_context_menu_darwin.h"
	fn C.native_browser_view() voidptr
	fn C.native_browser_link_context_menu(view voidptr, url &u8, length int, x f64, y f64)
}
