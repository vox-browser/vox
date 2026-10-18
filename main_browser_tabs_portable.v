module main

import gg

$if !vox_ui2 ? {
	fn (mut app BrowserApp) draw_portable_browser_tabs(width int) {
		chrome := app.browser_chrome_state(width, 0)
		first, end := browser_visible_tabs(width, chrome.tab_titles.len, chrome.selected_tab)
		tab_width := browser_tab_width(width, end - first)
		draw_srgb_rect(app.ctx, 0, 0, f32(width), f32(tab_strip_height), gg.rgb(219, 219, 219))
		for i in first .. end {
			x := f32(8 + f64(i - first) * tab_width)
			fill := if i == chrome.selected_tab {
				gg.rgb(247, 247, 247)
			} else {
				gg.rgb(210, 210, 210)
			}
			app.ctx.draw_convex_poly([x, f32(32), x + 10, f32(7), x + f32(tab_width) - 10, f32(7),
				x + f32(tab_width), f32(32)], fill)
			title := address_for_display(chrome.tab_titles[i], 0, false, int((tab_width - 48) / 7))
			app.ctx.draw_text(int(x) + 18, 13, title, color: gg.rgb(55, 55, 55), size: 12)
			app.ctx.draw_text(int(x + f32(tab_width)) - 24, 12, '×',
				color: gg.rgb(95, 95, 95)
				size:  14
			)
		}
		x := f32(20 + f64(end - first) * tab_width)
		draw_rounded_fill(app.ctx, x, 10, 30, 19, 4, gg.rgb(204, 204, 204))
		app.ctx.draw_text(int(x) + 10, 11, '+', color: gg.rgb(80, 80, 80), size: 14)
	}

	fn (mut app BrowserApp) handle_portable_tab_click(x f32, y f32) bool {
		if y < 0 || y >= tab_strip_height { return false }
		width := browser_window_size().width
		chrome := app.browser_chrome_state(width, 0)
		first, end := browser_visible_tabs(width, chrome.tab_titles.len, chrome.selected_tab)
		tab_width := browser_tab_width(width, end - first)
		for i in first .. end {
			left := 8 + f64(i - first) * tab_width
			if x >= left && x < left + tab_width {
				action := if x >= left + tab_width - 30 {
					'tab-close:${i}'
				} else {
					'tab-select:${i}'
				}
				app.activate_tab_chrome(action)
				return true
			}
		}
		left := 20 + f64(end - first) * tab_width
		if x >= left && x < left + 32 { app.activate_tab_chrome('tab-new') }
		return true
	}
}
