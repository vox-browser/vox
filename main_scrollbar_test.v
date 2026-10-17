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

fn test_browser_scrolls_viewport_overflow_beyond_a_constrained_root() {
	for root_style in ['html{height:100%}', 'html,body{height:100%}',
		'html{height:100%}#content{position:absolute;top:0}'] {
		mut owner := page.Page.create(1)!
		owner.set_enable_autoscroll(false)
		mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}#content{height:1200px;width:100%;background:lightblue}${root_style}</style><div id="content"></div>', dom.URL{
			value: 'https://scrollbar.example.test/constrained-root'
		}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
		mut app := BrowserApp{
			document:   document
			page_model: owner
		}
		window_height := 200 + app.chrome_height()
		app.relayout(320, window_height)
		assert app.root_box.border_box().height == 200
		assert app.content_height == 1200
		assert app.maximum_scroll(window_height) == 1000
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
		assert app.scroll_y == 42
		assert document.viewport_rect().y == 42
		scrolled := scrollbar_test_vertical_thumb(app.paint_commands)
		assert math.abs(scrolled.y - initial.y - 42 * initial.scrollbar_thumb_travel_ratio) < 0.001

		app.set_scroll_y(1e6, window_height)
		assert app.scroll_y == 1000
		app.relayout(320, 300 + app.chrome_height())
		assert app.content_height == 1200
		assert app.scroll_y == 900
		assert document.viewport_rect().y == 900

		mut content := document.get_element_by_id('content') or { panic('missing content') }
		content.set_attribute_value('style', 'height:400px')
		document.update_layout(.event_handler_handle_mouse_wheel)
		app.adopt_current_document_geometry()
		assert app.content_height == 400
		assert app.scroll_y == 100
		assert document.viewport_rect().y == 100
	}
}

fn test_browser_scroll_range_excludes_clipped_and_fixed_descendants() {
	for content_style in ['position:fixed', 'position:absolute'] {
		mut owner := page.Page.create(1)!
		mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0;height:100%}#clip{position:relative;height:100px;overflow:hidden}#content{height:1200px;width:100%;${content_style}}</style><div id="clip"><div id="content"></div></div>', dom.URL{
			value: 'https://scrollbar.example.test/clipped-root'
		}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
		mut app := BrowserApp{
			document:   document
			page_model: owner
		}
		window_height := 200 + app.chrome_height()
		app.relayout(320, window_height)
		assert app.content_height == 200
		assert app.maximum_scroll(window_height) == 0
		app.scroll_by(42, window_height)
		assert app.scroll_y == 0
	}
}
