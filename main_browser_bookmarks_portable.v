module main

$if !vox_ui2 ? {
	import gg
	import math
	import bookmarkui
	import ui2

	fn (mut app BrowserApp) portable_bookmark_range(width int) (int, int) {
		items := app.browser_bar_bookmarks()
		capacity := math.max(1, (width - 44) / 164)
		if app.bookmark_bar_first >= items.len { app.bookmark_bar_first = 0 }
		return app.bookmark_bar_first, math.min(items.len, app.bookmark_bar_first + capacity)
	}

	fn (mut app BrowserApp) draw_portable_bookmarks(width int) {
		$if linux || ui2_custom_rendering ? {
			chrome := app.browser_chrome_state(width, app.ctx.height)
			state := app.browser_bookmark_ui_state(chrome)
			mut images := map[string]int{}
			for i, item in state.items {
				if item.icon != '' { images[item.icon] = chrome.bookmark_favicons[i] }
			}
			ui2.draw_embedded_elements(app.ctx, bookmarkui.elements(state), images, portable_bookmark_event)
			return
		}
		if !app.bookmark_bar_visible() { return }
		items := app.browser_bar_bookmarks()
		top := int(app.bookmark_bar_top())
		if items.len == 0 {
			app.ctx.draw_text(12, top + 7, 'Save your favorite pages here with Ctrl+D',
				color: gg.rgb(85, 85, 85)
				size:  12
			)
			return
		}
		first, end := app.portable_bookmark_range(width)
		icons := app.cached_browser_bookmark_favicons()
		for index in first .. end {
			x := 12 + (index - first) * 164
			if index < icons.len && icons[index] >= 0 {
				image := app.ctx.get_cached_image_by_idx(icons[index])
				scale := f32(16) / f32(math.max(image.width, image.height))
				w := f32(image.width) * scale
				h := f32(image.height) * scale
				$if macos {
					if app.ctx.native_rendering {
						C.native_draw_image_part(image, f32(x) + (16 - w) / 2, f32(top + 5) + (16 - h) / 2,
							w, h, 0, 0, f32(image.width), f32(image.height), f32(app.ctx.height), 1)
					} else { app.ctx.draw_image_by_id(f32(x), f32(top + 5), w, h, icons[index]) }
				} $else { app.ctx.draw_image_by_id(f32(x), f32(top + 5), w, h, icons[index]) }
			} else {
				app.ctx.draw_circle_empty(f32(x + 8), f32(top + 13), 6, gg.rgb(110, 110, 110))
				app.ctx.draw_line(x + 2, top + 13, x + 14, top + 13, gg.rgb(110, 110, 110))
			}
			title := address_for_display(items[index].title, 0, false, 17)
			app.ctx.draw_text(x + 22, top + 7, title,
				color: gg.rgb(55, 55, 55)
				size:  12
			)
		}
		if first > 0 || end < items.len {
			app.ctx.draw_text(width - 28, top + 5, '»', color: gg.rgb(55, 55, 55), size: 15)
		}
	}

	fn portable_bookmark_event(action string) {
		if address_bar_owner.app == unsafe { nil } { return }
		mut app := address_bar_owner.app.active_browser_tab()
		app.activate_browser_chrome(action)
		request_browser_frame()
	}

	fn (mut app BrowserApp) handle_portable_bookmark_event(event &gg.Event) bool {
		$if linux || ui2_custom_rendering ? {
			mut owner := unsafe { address_bar_owner }
			owner.app = app
			if ui2.embedded_elements_event(event) {
				if event.typ == .mouse_down { app.suppress_next_click_for_chrome = true }
				request_browser_frame()
				return true
			}
		}
		return false
	}

	fn (mut app BrowserApp) handle_portable_bookmark_click(x f32, y f32) bool {
		$if linux || ui2_custom_rendering ? { return false }
		if !app.bookmark_bar_visible() || y < app.bookmark_bar_top() || y >= app.page_top() {
			return false
		}
		items := app.browser_bar_bookmarks()
		width := browser_window_size().width
		first, end := app.portable_bookmark_range(width)
		if x >= width - 34 {
			app.bookmark_bar_first = if end < items.len { end } else { 0 }
			request_browser_frame()
		} else if x >= 8 {
			index := first + int(x - 8) / 164
			if index < end { app.activate_browser_bookmarks('bookmark-open:${index}') }
		}
		return true
	}
}
