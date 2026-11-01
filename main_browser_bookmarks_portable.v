module main

$if !vox_ui2 ? {
	import gg
	import math

	fn (mut app BrowserApp) portable_bookmark_range(width int) (int, int) {
		items := app.browser_bar_bookmarks()
		capacity := math.max(1, (width - 44) / 164)
		if app.bookmark_bar_first >= items.len { app.bookmark_bar_first = 0 }
		return app.bookmark_bar_first, math.min(items.len, app.bookmark_bar_first + capacity)
	}

	fn (mut app BrowserApp) draw_portable_bookmarks(width int) {
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
		for index in first .. end {
			title := address_for_display(items[index].title, 0, false, 20)
			app.ctx.draw_text(12 + (index - first) * 164, top + 7, title,
				color: gg.rgb(55, 55, 55)
				size:  12
			)
		}
		if first > 0 || end < items.len {
			app.ctx.draw_text(width - 28, top + 5, '»', color: gg.rgb(55, 55, 55), size: 15)
		}
	}

	fn (mut app BrowserApp) handle_portable_bookmark_click(x f32, y f32) bool {
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
