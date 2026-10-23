module main

import gg

$if macos {
	$if !vox_ui2 ? {
		#include "native_portable_tabs_paint_test_darwin.h"
		fn C.native_test_portable_tabs_begin(width int, height int) int
		fn C.native_test_portable_tabs_pixel(x int, y int) u32
		fn C.native_test_portable_tabs_end()

		fn test_portable_tabs_paint_into_native_context_without_sokol() {
			assert C.native_test_portable_tabs_begin(800, 120) == 1
			defer { C.native_test_portable_tabs_end() }
			mut app := &BrowserApp{
				ctx: gg.new_context(native_rendering: true, width: 800, height: 120)
			}
			assert !app.ctx.has_started
			assert app.ctx.pipeline == unsafe { nil }
			app.draw_portable_browser_tabs(800)
			assert C.native_test_portable_tabs_pixel(5, 10) == u32(0xdbdbdbff)
			assert C.native_test_portable_tabs_pixel(190, 8) == u32(0xf7f7f7ff)
			assert C.native_test_portable_tabs_pixel(190, 2) == u32(0xdbdbdbff)
			assert C.native_test_portable_tabs_pixel(10, 60) == 0
			assert app.ctx.pipeline == unsafe { nil }
			assert app.ctx.ft == unsafe { nil }
		}

		fn test_portable_native_tab_fills_follow_selected_tab() {
			assert C.native_test_portable_tabs_begin(800, 120) == 1
			defer { C.native_test_portable_tabs_end() }
			mut app := &BrowserApp{
				ctx: gg.new_context(native_rendering: true, width: 800, height: 120)
			}
			app.initialize_browser_tabs()
			app.tabs.pages << &BrowserApp{ctx: app.ctx}
			app.draw_portable_browser_tabs(800)
			assert C.native_test_portable_tabs_pixel(190, 8) == u32(0xf7f7f7ff)
			assert C.native_test_portable_tabs_pixel(374, 8) == u32(0xd2d2d2ff)
			app.tabs.selected = 1
			app.draw_portable_browser_tabs(800)
			assert C.native_test_portable_tabs_pixel(190, 8) == u32(0xd2d2d2ff)
			assert C.native_test_portable_tabs_pixel(374, 8) == u32(0xf7f7f7ff)
			assert C.native_test_portable_tabs_pixel(5, 10) == u32(0xdbdbdbff)
			assert C.native_test_portable_tabs_pixel(10, 60) == 0
			assert app.ctx.pipeline == unsafe { nil }
			assert app.ctx.ft == unsafe { nil }
		}
	}
}
