module main

import gg

// Linux retains GG navigation controls; bookmarks use UI2 in that same draw
// pass. Production macOS builds mount the native UI2 chrome instead.
$if !vox_ui2 ? {
	fn (mut app BrowserApp) draw_chrome_button(x f32, label string, enabled bool) {
		foreground := if enabled { gg.rgb(125, 125, 125) } else { gg.rgb(205, 205, 205) }
		app.ctx.draw_text(int(x) + 6, int(tab_strip_height + 5), label, color: foreground, size: 17)
	}

	fn (mut app BrowserApp) draw_portable_browser_chrome(window gg.Size) {
		// Draw chrome last so scrolled page content cannot paint over it.
		draw_srgb_rect(app.ctx, 0, 0, f32(window.width), app.page_top(), gg.rgb(247, 247, 247))
		app.draw_portable_browser_tabs(window.width)
		app.draw_chrome_button(5, '‹', app.history_index > 0)
		app.draw_chrome_button(27, '›', app.history_index + 1 < app.history.len)
		app.draw_chrome_button(49, '↻', app.history_index >= 0)
		app.draw_chrome_button(f32(window.width - 32), '◷', true)
		address_x := f32(78)
		address_width := f32(window.width - 118)
		app.resize_address_bar(window.width)
		if !app.native_address_bar {
			address_color := if app.address_active {
				gg.rgb(255, 255, 255)
			} else {
				gg.rgb(247, 247, 247)
			}
			draw_rounded_fill(app.ctx, address_x, f32(tab_strip_height + 3), address_width, 23, 2, address_color)
			if app.address_select {
				draw_rounded_fill(app.ctx, address_x + 5, f32(tab_strip_height + 5), address_width - 10, 19, 1, gg.rgb(219, 234, 254))
			}
			visible_address := address_for_display(app.address, app.address_cursor, app.address_active, int(address_width / 8.0) - 2)
			app.ctx.draw_text(int(address_x) + 22, int(tab_strip_height + 8), visible_address,
				color: gg.rgb(15, 23, 42)
				size:  12
			)
		}
		if app.chrome_debug {
			app.ctx.draw_text(14, int(tab_strip_height + toolbar_height + 8), app.status, color: gg.rgb(148, 163, 184), size: 12)
		}
		app.draw_portable_bookmarks(window.width)

		status_y := window.height - int(status_bar_height)
		draw_srgb_rect(app.ctx, 0, f32(status_y), f32(window.width), f32(status_bar_height), gg.rgb(230, 230, 230))
		footer := if app.hovered_link != '' {
			app.hovered_link
		} else if app.js_messages.len > 0 {
			// Console stacks can contain embedded newlines. The status bar is a
			// single-line chrome surface; allowing those newlines to paint upward
			// leaks browser diagnostics into document screenshots.
			'Console: ${app.js_messages.last().split_into_lines()[0]}'
		} else {
			app.source_label
		}
		app.ctx.draw_text(12, status_y + 4, footer, color: gg.rgb(85, 85, 85), size: 12)
		app.draw_memory_status(window.width, status_y)
	}
}
