module main

import dom
import gg
import layout
import math
import page
import time

fn scrollbar_test_vertical_thumb(commands []layout.PaintCommand) layout.PaintCommand {
	thumbs := commands.filter(it.kind == 'fill_rounded_rect' && it.scrollbar_axis == 'vertical')
	assert thumbs.len == 1
	return thumbs[0]
}

fn test_browser_scrollbar_follows_wheel_and_clamped_scroll_across_native_frames() {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}#content{height:1200px;background:lightblue}</style><div id="content"></div>', dom.URL{
		value: 'https://scrollbar.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut app := BrowserApp{
		document:   document
		page_model: owner
	}
	window_height := 200 + app.chrome_height()
	app.relayout(320, window_height)
	initial := scrollbar_test_vertical_thumb(app.paint_commands)
	app.handle_event(&gg.Event{
		typ:      .mouse_scroll
		mouse_x:  50
		mouse_y:  app.page_top() + 50
		scroll_y: -1
	})
	assert app.scroll_y == 42
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	scrolled := scrollbar_test_vertical_thumb(app.paint_commands)
	assert math.abs(scrolled.y - initial.y - 42 * initial.scrollbar_thumb_travel_ratio) < 0.001
	assert scrolled.transform == initial.transform
	assert scrolled.height == initial.height

	for requested in [1e6, -1e6] {
		app.scroll_by(requested, window_height)
		app.begin_frame_preparation()
		app.finish_frame_preparation()
		thumb := scrollbar_test_vertical_thumb(app.paint_commands)
		expected_scroll := if requested > 0 { app.maximum_scroll(window_height) } else { 0.0 }
		assert app.scroll_y == expected_scroll
		assert document.viewport_rect().y == expected_scroll
		assert math.abs(thumb.y - initial.y - expected_scroll * initial.scrollbar_thumb_travel_ratio) < 0.001
	}
}
