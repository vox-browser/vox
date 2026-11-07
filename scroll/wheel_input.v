// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module main

import dom
import page
import os

const disable_wheel_hit_reuse = os.getenv('VOX_DISABLE_WHEEL_HIT_REUSE') != ''
const wheel_hit_reuse_diagnostics = os.getenv('VOX_WHEEL_HIT_REUSE_DIAGNOSTICS') != ''
const disable_deferred_wheel_coalescing = os.getenv('VOX_DISABLE_WHEEL_COALESCING') != ''
const disable_frame_aligned_wheels = os.getenv('VOX_DISABLE_FRAME_ALIGNED_WHEELS') != ''

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
	return app.scroll_element_for_wheel_target(target, delta_x, delta_y)
}

fn (app &BrowserApp) wheel_input_can_reuse_hit(target page.InputTarget) bool {
	if disable_wheel_hit_reuse { return false }
	if app.js_runtime != unsafe { nil } && app.js_runtime.has_pending_document_state() { return false }
	node := target.node or { return false }
	// Includes shadow hosts, Document and Window listeners. With no callback
	// and no compact-runtime task to apply, dispatch cannot alter the hit tree.
	return !node.has_inclusive_ancestor_with_event_listener('wheel')
}

fn wheel_input_target_layout_is_current(target page.InputTarget) bool {
	node := target.node or { return false }
	current := node.layout_node() or { return false }
	committed := target.layout_node() or { return false }
	return voidptr(current) == voidptr(committed)
}

fn (mut app BrowserApp) scroll_element_for_wheel_target(target page.InputTarget,
	delta_x f64, delta_y f64) bool {
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
// a fresh hit after callbacks; callback-free dispatch can retain its target.
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
	reuse_hit := app.wheel_input_can_reuse_hit(target)
	hit_document := voidptr(document)
	hit_runtime := voidptr(app.js_runtime)
	hit_revision := document.paint_content_revision()
	hit_viewport := document.viewport_rect()
	mut handler := app.page_model.event_handler
	handler.set_document_state(document.is_fully_active(), document.layout_node() != none)
	result := handler.handle_mousewheel_with_parameters(target,
		page.PixelPoint{client.x / app.page_zoom, client.y / app.page_zoom}, screen, button, buttons,
		modifiers, delta_x / app.page_zoom, delta_y / app.page_zoom, .precise, .changed, async_default_action)
	// Callback wrappers mark the compact document dirty; apply those operations
	// even when the callback cancels the wheel's default action.
	pending_script_task := app.js_runtime != unsafe { nil }
		&& app.js_runtime.has_pending_document_state()
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
	// Reject a replaced layout node even on the callback-free path.
	reuse_for_default := reuse_hit && !pending_script_task
		&& voidptr(app.js_runtime) == hit_runtime && voidptr(app.document) == hit_document
		&& (app.js_runtime == unsafe { nil } || !app.js_runtime.has_pending_document_state())
		&& document.paint_content_revision() == hit_revision
		&& document.viewport_rect() == hit_viewport
		&& wheel_input_target_layout_is_current(target)
	if wheel_hit_reuse_diagnostics {
		eprintln('VOX_WHEEL_HIT_REUSE reused=${reuse_for_default}')
	}
	element_scrolled := if reuse_for_default {
		app.scroll_element_for_wheel_target(target, x, y)
	} else {
		app.scroll_element_at_viewport_point(client, x, y)
	}
	if element_scrolled {
		return .handled
	}
	before := app.scroll_y
	app.scroll_by(y, app.viewport_height + app.chrome_height())
	return if app.scroll_y != before { .handled } else { .accepted }
}
