module main

import gg
import math

$if !vox_ui2 ? {
	fn (mut app BrowserApp) draw_portable_browser_tabs(width int) {
		app.initialize_browser_tabs()
		chrome := app.browser_chrome_state(width, 0)
		mut first, mut end := browser_visible_tabs(width, chrome.tab_titles.len, chrome.selected_tab)
		mut tab_width := browser_tab_width(width, end - first)
		if drag := app.tabs.drag {
			first = drag.first
			end = drag.end
			tab_width = drag.width
		}
		draw_srgb_rect(app.ctx, 0, 0, f32(width), f32(tab_strip_height), gg.rgb(219, 219, 219))
		for i in first .. end {
			mut slot := i
			if drag := app.tabs.drag {
				if drag.moving {
					from := app.browser_tab_index(drag.page)
					if i == from { continue }
					if from < i && i <= drag.target { slot-- }
					if drag.target <= i && i < from { slot++ }
				}
			}
			x := f32(tab_strip_leading_width + f64(slot - first) * tab_width)
			app.draw_portable_browser_tab(chrome.tab_titles[i], chrome.tab_favicons[i], x, tab_width, i == chrome.selected_tab)
		}
		if drag := app.tabs.drag {
			if drag.moving {
				mut dragged_page := drag.page
				x := math.clamp(drag.x - drag.offset, tab_strip_leading_width,
					tab_strip_leading_width + f64(end - first - 1) * tab_width)
				app.draw_portable_browser_tab(dragged_page.browser_tab_title(), dragged_page.browser_tab_favicon_id(), f32(x), tab_width, true)
			}
		}
		x := f32(tab_strip_leading_width + 12 + f64(end - first) * tab_width)
		draw_rounded_fill(app.ctx, x, 11, 28, 14, 2, gg.rgb(204, 204, 204))
	}

	fn (mut app BrowserApp) draw_portable_browser_tab(label string, favicon int, x f32, width f64, selected bool) {
		fill := if selected { gg.rgb(247, 247, 247) } else { gg.rgb(210, 210, 210) }
		draw_browser_polygon(app.ctx, [x, f32(tab_strip_height), x + 10, f32(5),
			x + f32(width) - 10, f32(5), x + f32(width), f32(tab_strip_height)], fill)
		if favicon >= 0 {
			image := app.ctx.get_cached_image_by_idx(favicon)
			scale := f32(16) / f32(math.max(image.width, image.height))
			w := f32(image.width) * scale
			h := f32(image.height) * scale
			$if macos {
				if app.ctx.native_rendering {
					C.native_draw_image_part(image, x + 12 + (16 - w) / 2, 9 + (16 - h) / 2,
						w, h, 0, 0, f32(image.width), f32(image.height), f32(app.ctx.height), 1)
				} else {
					app.ctx.draw_image_by_id(x + 12 + (16 - w) / 2, 9 + (16 - h) / 2, w, h, favicon)
				}
			} $else {
				app.ctx.draw_image_by_id(x + 12 + (16 - w) / 2, 9 + (16 - h) / 2, w, h, favicon)
			}
		}
		inset := if favicon >= 0 { 34 } else { 18 }
		title := address_for_display(label, 0, false, int((width - f64(inset) - 30) / 7))
		app.ctx.draw_text(int(x) + inset, 13, title, color: gg.rgb(55, 55, 55), size: 12)
		app.ctx.draw_text(int(x + f32(width)) - 24, 12, '×', color: gg.rgb(95, 95, 95), size: 14)
	}

	fn (mut app BrowserApp) handle_portable_tab_click(x f32, y f32) bool {
		if y < 0 || y >= tab_strip_height { return false }
		width := browser_window_size().width
		chrome := app.browser_chrome_state(width, 0)
		first, end := browser_visible_tabs(width, chrome.tab_titles.len, chrome.selected_tab)
		tab_width := browser_tab_width(width, end - first)
		for i in first .. end {
			left := tab_strip_leading_width + f64(i - first) * tab_width
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
		left := tab_strip_leading_width + 12 + f64(end - first) * tab_width
		if x >= left && x < left + 32 { app.activate_tab_chrome('tab-new') }
		return true
	}
}
