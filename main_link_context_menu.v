module main

import platform

// Keep the menu's URL independent of hover state and the address field. The
// native menu owns a copy while AppKit runs its nested menu event loop.
fn (mut app BrowserApp) show_link_context_menu(x f32, y f32) {
	$if macos {
		// The destination is reused after AppKit's nested event loop returns.
		persistent := platform.enter_persistent()
		destination := app.link_at_point(x, y) or {
			platform.leave_persistent(persistent)
			return
		}
		platform.leave_persistent(persistent)
		defer {
			$if gcboehm ? {
				C.GC_reachable_here(destination.str)
			}
		}
		if C.native_browser_link_context_menu(C.native_browser_view(), destination.str,
			destination.len, f64(x), f64(y)) == 1 {
			app.activate_tab_chrome('tab-open-background:${destination}')
		}
	}
}

$if macos {
	#include "native_link_context_menu_darwin.h"
	fn C.native_browser_view() voidptr
	fn C.native_browser_link_context_menu(view voidptr, url &u8, length int, x f64, y f64) int
}
