module main

import dom
import gg
import page
import time

fn test_overlay_scrollbar_idle_visibility_and_fade() {
	mut bars := BrowserOverlayScrollbars{
		enabled: true
	}
	assert bars.opacity_at(1_000_000_000) == 0
	bars.activity(1_000_000_000)
	assert bars.opacity_at(1_600_000_000) == 1
	assert bars.opacity_at(1_750_000_000) == 0.5
	assert bars.opacity_at(1_900_000_000) == 0
	bars.activity(2_000_000_000)
	assert bars.opacity_at(2_100_000_000) == 1
}

fn test_overlay_scrollbar_hover_and_drag_preserve_visibility_until_release() {
	mut bars := BrowserOverlayScrollbars{
		enabled: true
	}
	bars.hovered = true
	assert bars.opacity_at(3_000_000_000) == 1
	bars.dragging = true
	bars.hovered = false
	assert bars.opacity_at(4_000_000_000) == 1
	bars.dragging = false
	bars.activity(4_000_000_000)
	assert bars.opacity_at(4_750_000_000) == 0.5
	assert bars.opacity_at(5_000_000_000) == 0
}

fn test_persistent_scrollbars_ignore_overlay_idle_state() {
	bars := BrowserOverlayScrollbars{}
	assert bars.opacity_at(0) == 1
	assert bars.opacity_at(5_000_000_000) == 1
}

fn test_leaving_an_idle_document_does_not_reveal_its_overlay_scrollbars() {
	mut app := BrowserApp{}
	app.overlay_scrollbars.enabled = true
	app.handle_event(&gg.Event{ typ: .mouse_leave })
	assert !app.overlay_scrollbars.active
	assert app.overlay_scrollbars.opacity_at(time.sys_mono_now()) == 0
	// Leaving a visible hovered thumb retains the normal hold/fade interval.
	app.overlay_scrollbars.hovered = true
	app.handle_event(&gg.Event{ typ: .mouse_leave })
	assert !app.overlay_scrollbars.hovered
	assert app.overlay_scrollbars.opacity_at(time.sys_mono_now()) == 1
	assert app.overlay_scrollbars.opacity_at(app.overlay_scrollbars.last_activity_ns + 900_000_000) == 0
}

fn test_overlay_scrollbar_input_reveals_and_releases_the_live_thumb() {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><style>html,body{margin:0}div{height:1200px}</style><div></div>', dom.URL{
		value: 'https://old.reddit.com/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	// The native callbacks retain this owner's address, as in the browser.
	mut app := &BrowserApp{
		document:   document
		page_model: owner
	}
	app.install_chrome_widget_input_bridge()
	app.relayout(320, 200 + app.chrome_height())
	app.overlay_scrollbars.enabled = true
	assert app.overlay_scrollbars.opacity_at(time.sys_mono_now()) == 0
	app.handle_event(&gg.Event{
		typ:      .mouse_scroll
		mouse_x:  50
		mouse_y:  app.page_top() + 50
		scroll_y: -1
	})
	assert app.scroll_y == 42
	assert app.overlay_scrollbars.opacity_at(time.sys_mono_now()) == 1
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	thumbs := app.paint_commands.filter(it.kind == 'fill_rounded_rect'
		&& it.scrollbar_axis == 'vertical')
	assert thumbs.len == 1
	thumb := thumbs[0]
	// Use the live retained transform: the root scroll frame is carried there.
	x := thumb.x + thumb.width / 2 + thumb.transform[4]
	y := thumb.y + thumb.height / 2 + thumb.transform[5]
	app.handle_event(&gg.Event{ typ: .mouse_move, mouse_x: f32(x), mouse_y: app.page_top() + f32(y) })
	assert app.overlay_scrollbars.hovered
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: f32(x), mouse_y:
		app.page_top() + f32(y) })
	assert app.overlay_scrollbars.dragging
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: 10, mouse_y:
		app.page_top() + 100 })
	assert !app.overlay_scrollbars.dragging
	app.handle_event(&gg.Event{ typ: .mouse_leave })
	assert !app.overlay_scrollbars.hovered
	assert app.overlay_scrollbars.opacity_at(app.overlay_scrollbars.last_activity_ns + 900_000_000) == 0
}

fn test_overlay_scrollbar_activity_keeps_one_pending_fade_wake() {
	$if macos {
		mut app := BrowserApp{ ctx: &gg.Context{ native_rendering: true } }
		app.overlay_scrollbars.enabled = true
		app.overlay_scrollbar_activity()
		first := app.overlay_scrollbars.wake_deadline_ns
		assert first > app.overlay_scrollbars.last_activity_ns
		// Every wheel refreshes activity; the pending wake still covers it.
		for _ in 0 .. 5 {
			app.overlay_scrollbar_activity()
		}
		assert app.overlay_scrollbars.wake_deadline_ns == first
		// After the wake fires, the remaining hold is scheduled once more.
		now := first + 1
		app.schedule_overlay_scrollbar_wake(now, 250_000_000)
		assert app.overlay_scrollbars.wake_deadline_ns == now + 250_000_000
		app.schedule_overlay_scrollbar_wake(now + 10, 600_000_000)
		assert app.overlay_scrollbars.wake_deadline_ns == now + 250_000_000
	}
}

fn test_capture_scrollbars_are_hidden_with_both_system_preferences() {
	for enabled in [false, true] {
		mut bars := BrowserOverlayScrollbars{enabled: enabled}
		bars.activity(1_000_000_000)
		bars.hovered = true
		bars.dragging = true
		assert bars.capture_opacity_at(1_100_000_000, true) == 0
		assert bars.capture_opacity_at(1_100_000_000, false) == 1
		bars.hovered = false
		bars.dragging = false
		assert bars.capture_opacity_at(1_750_000_000, true) == 0
		assert bars.capture_opacity_at(1_750_000_000, false) == if enabled { f64(.5) } else { f64(1) }
	}
}
