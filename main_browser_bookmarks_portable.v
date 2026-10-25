module main

$if !vox_ui2 ? {
	import gg
	import math

	fn (mut app BrowserApp) portable_bookmark_range(width int) (int, int) {
		capacity := math.max(1, (width - 44) / 164)
		if app.bookmark_bar_first >= app.bookmarks.items.len { app.bookmark_bar_first = 0 }
		return app.bookmark_bar_first, math.min(app.bookmarks.items.len, app.bookmark_bar_first + capacity)
	}

	fn (mut app BrowserApp) draw_portable_bookmarks(width int) {
		if !app.bookmark_bar_visible() { return }
		top := int(app.bookmark_bar_top())
		if app.bookmarks.items.len == 0 {
			app.ctx.draw_text(12, top + 7, 'Save your favorite pages here with Ctrl+D',
				color: gg.rgb(85, 85, 85)
				size:  12
			)
			return
		}
		first, end := app.portable_bookmark_range(width)
		for index in first .. end {
			title := address_for_display(app.bookmarks.items[index].title, 0, false, 20)
			app.ctx.draw_text(12 + (index - first) * 164, top + 7, title,
				color: gg.rgb(55, 55, 55)
				size:  12
			)
		}
		if first > 0 || end < app.bookmarks.items.len {
			app.ctx.draw_text(width - 28, top + 5, '»', color: gg.rgb(55, 55, 55), size: 15)
		}
	}

	fn (mut app BrowserApp) handle_portable_bookmark_click(x f32, y f32) bool {
		if !app.bookmark_bar_visible() || y < app.bookmark_bar_top() || y >= app.page_top() {
			return false
		}
		width := browser_window_size().width
		first, end := app.portable_bookmark_range(width)
		if x >= width - 34 {
			app.bookmark_bar_first = if end < app.bookmarks.items.len { end } else { 0 }
			request_browser_frame()
		} else if x >= 8 {
			index := first + int(x - 8) / 164
			if index < end { app.activate_browser_bookmarks('bookmark-open:${index}') }
		}
		return true
	}
}
