// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import dom
import page

fn wheel_input_target(hit dom.HitTestResult) ?page.InputTarget {
	node := if hit.node != unsafe { nil } {
		hit.node
	} else if hit.element != unsafe { nil } {
		hit.element.as_node()
	} else {
		return none
	}
	return page.InputTarget.from_node(node)
}

fn (mut app BrowserApp) scroll_element_at_viewport_point(point page.PixelPoint,
	delta_x f64, delta_y f64) bool {
	hit := app.hit_test_at_viewport_point(point.x, point.y) or { return false }
	target := wheel_input_target(hit) or { return false }
	node := target.node or { return false }
	mut current := node.layout_node()
	for current != none {
		layout_node := current or { break }
		if layout_node_is_document_viewport_scroller(app.document, layout_node) {
			current = layout_node.containing_block()
			continue
		}
		for paintable in layout_node.paintables() {
			if paintable.is_paintable_box() {
				mut box := unsafe { &dom.PaintableBox(paintable) }
				if box.handle_mousewheel(delta_x / app.page_zoom, delta_y / app.page_zoom) {
					return true
				}
			}
		}
		current = layout_node.containing_block()
	}
	return false
}

// Dispatch against the committed hit tree, then resolve default scrolling from
// a new tree after native callbacks and compact DOM mutations have completed.
fn (mut app BrowserApp) handle_wheel_at_viewport_point(client page.PixelPoint,
	screen page.PixelPoint, button u32, buttons u32, modifiers u32,
	delta_x f64, delta_y f64, async_default_action bool) page.EventResult {
	return app.handle_wheel_input(client, screen, button, buttons, modifiers,
		delta_x, delta_y, async_default_action, false)
}

fn (mut app BrowserApp) handle_wheel_input(client page.PixelPoint,
	screen page.PixelPoint, button u32, buttons u32, modifiers u32,
	delta_x f64, delta_y f64, async_default_action bool, horizontal_only bool) page.EventResult {
	if app.document == unsafe { nil } || app.page_model == unsafe { nil } || client.x < 0
		|| client.y < 0 || client.x >= f64(app.viewport_width)
		|| client.y >= f64(app.viewport_height) {
		return .dropped
	}
	mut document := unsafe { &dom.Document(app.document) }
	document.update_layout(.event_handler_handle_mouse_wheel)
	hit := app.hit_test_at_viewport_point(client.x, client.y) or { return .dropped }
	target := wheel_input_target(hit) or { return .dropped }
	mut handler := app.page_model.event_handler
	handler.set_document_state(document.is_fully_active(), document.layout_node() != none)
	result := handler.handle_mousewheel_with_parameters(target,
		page.PixelPoint{client.x / app.page_zoom, client.y / app.page_zoom}, screen, button, buttons,
		modifiers, delta_x / app.page_zoom, delta_y / app.page_zoom, .precise, .changed, async_default_action)
	// Callback wrappers mark the compact document dirty; apply those operations
	// even when the callback cancels the wheel's default action.
	app.poll_javascript_tasks()
	if result != .accepted || async_default_action {
		return result
	}
	if app.document == unsafe { nil } || !app.document.is_fully_active() {
		return .dropped
	}
	document = unsafe { &dom.Document(app.document) }
	document.update_layout(.event_handler_handle_mouse_wheel)
	if document.layout_node() == none || document.paintable_box() == none {
		return .dropped
	}
	app.adopt_current_document_geometry()
	// Use this dispatch's deltas: a nested wheel callback may have replaced the
	// handler's last-wheel metadata before the outer default action resumes.
	x := if modifiers & dom.modifier_shift != 0 { delta_y } else { delta_x }
	// A native horizontal gesture locks the default action to that axis. DOM
	// listeners still receive both original deltas above and can cancel it.
	y := if horizontal_only {
		0.0
	} else if modifiers & dom.modifier_shift != 0 {
		delta_x
	} else {
		delta_y
	}
	if app.scroll_element_at_viewport_point(client, x, y) {
		return .handled
	}
	before := app.scroll_y
	app.scroll_by(y, app.viewport_height + app.chrome_height())
	return if app.scroll_y != before { .handled } else { .accepted }
}
