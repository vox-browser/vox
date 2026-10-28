// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Wheel-event routing and visual-viewport scroll decisions from EventHandler.
module page

import compositor
import dom

pub struct VisualViewportScrollState {
pub:
	layout_width  f64
	layout_height f64
	visual_width  f64
	visual_height f64
	offset_left   f64
	offset_top    f64
}

pub struct VisualViewportPanAxes {
pub:
	x bool
	y bool
}

pub fn (axes VisualViewportPanAxes) is_empty() bool {
	return !axes.x && !axes.y
}

pub fn visual_viewport_pan_axes_for_scroll_step(viewport VisualViewportScrollState, delta_x f64, delta_y f64) VisualViewportPanAxes {
	maximum_offset_left := viewport.layout_width - viewport.visual_width
	maximum_offset_top := viewport.layout_height - viewport.visual_height
	return VisualViewportPanAxes{
		x: (delta_x < 0 && viewport.offset_left > 0)
			|| (delta_x > 0 && viewport.offset_left < maximum_offset_left)
		y: (delta_y < 0 && viewport.offset_top > 0)
			|| (delta_y > 0 && viewport.offset_top < maximum_offset_top)
	}
}

pub struct ScrollBoxCandidate {
pub:
	id             string
	is_viewport    bool
	can_scroll_x   bool
	can_scroll_y   bool
}

pub fn scrolling_box_for_scroll_step(containing_block_chain []ScrollBoxCandidate, delta PixelPoint, viewport VisualViewportScrollState) ?ScrollBoxCandidate {
	for candidate in containing_block_chain {
		if (delta.x == 0 || !candidate.can_scroll_x) && (delta.y == 0 || !candidate.can_scroll_y) {
			continue
		}
		if candidate.is_viewport
			&& !visual_viewport_pan_axes_for_scroll_step(viewport, delta.x, delta.y).is_empty() {
			// The default action pans the visual viewport after the containing-block chain.
			return none
		}
		return candidate
	}
	return none
}

pub struct WheelEventData {
pub:
	target                   string
	visual_viewport_position PixelPoint
	screen_position          PixelPoint
	button                   u32
	buttons                  u32
	modifiers                u32
	delta_x                  f64
	delta_y                  f64
	cancelable               bool
}

pub fn set_page_cursor(mut model Page, cursor string) {
	if model.current_cursor() == cursor {
		return
	}
	mut client := model.client()
	client.page_did_request_cursor_change(cursor)
	model.set_current_cursor(cursor)
}

pub fn (handler &EventHandler) last_wheel_event() ?WheelEventData {
	return handler.last_wheel_event_
}

pub fn (mut handler EventHandler) dispatch_wheel_event(target InputTarget, visual_viewport_position PixelPoint, screen_position PixelPoint, button u32, buttons u32, modifiers u32, wheel_delta_x f64, wheel_delta_y f64, is_cancelable bool) EventResult {
	if !handler.active_document || !handler.paint_root_available || target.id == '' {
		return .dropped
	}
	handler.last_wheel_event_ = WheelEventData{
		target: target.id
		visual_viewport_position: visual_viewport_position
		screen_position: screen_position
		button: button
		buttons: buttons
		modifiers: modifiers
		delta_x: wheel_delta_x
		delta_y: wheel_delta_y
		cancelable: is_cancelable
	}
	handler.log('wheel', target)
	if hit_node := target.node {
		if !input_target_is_enabled(target) || !target.layout_is_up_to_date
			|| !target.has_document_paintable {
			return .dropped
		}
		hit_layout := target.layout_node() or { return .dropped }
		current_layout := hit_node.layout_node() or { return .dropped }
		if voidptr(hit_layout) != voidptr(current_layout) {
			return .dropped
		}
		mut node := unsafe { hit_node }
		for !node.is_element() {
			node = node.parent() or { return .dropped }
		}
		document := node.document()
		if !document.is_fully_active() || !document.layout_is_up_to_date()
			|| !handler.has_committed_root_box(document) {
			return .dropped
		}
		handler.pointed_document_ = document
		handler.platform_mouse_position_ = visual_viewport_position
		handler.platform_mouse_screen_ = screen_position
		mut coordinates := handler.coordinates_for_node(node)
		// Unboxed inline parents have no padding box. Retain the hit node as
		// the offset origin, as upstream does for a parent without a box.
		if paintable := node.unsafe_paintable() {
			if !paintable.is_paintable_box() {
				coordinates = handler.coordinates_for_node(hit_node)
			}
		} else {
			coordinates = handler.coordinates_for_node(hit_node)
		}
		wheel := dom.WheelEvent.create_from_platform_event(node_view(node), 'wheel',
			pixel_point(screen_position), pixel_point(coordinates.page),
			pixel_point(coordinates.client), pixel_point(coordinates.offset),
			wheel_delta_x, wheel_delta_y, i16(button), u16(buttons), modifiers)
		mut event := unsafe { &dom.Event(wheel) }
		event.set_cancelable(is_cancelable)
		return if dom.event_target_dispatch_event(unsafe { &dom.EventTarget(node) }, event) {
			.accepted
		} else {
			.cancelled
		}
	}
	// InputTarget without a DOM node is the standalone routing fixture.
	if is_cancelable && target.cancel_mouse {
		return .cancelled
	}
	return .accepted
}

pub fn (mut handler EventHandler) dispatch_synthetic_pinch_wheel_event(target ?InputTarget, visual_viewport_position PixelPoint, screen_position PixelPoint, modifiers u32, wheel_delta_y f64) EventResult {
	value := target or { return .dropped }
	return handler.dispatch_wheel_event(value, visual_viewport_position, screen_position, 0, 0,
		modifiers | dom.modifier_ctrl, 0, wheel_delta_y, true)
}

pub fn (mut handler EventHandler) handle_mousewheel_with_parameters(target ?InputTarget, visual_viewport_position PixelPoint, screen_position PixelPoint, button u32, buttons u32, modifiers u32, wheel_delta_x f64, wheel_delta_y f64, _ compositor.WheelDeltaPrecision, _ compositor.ScrollGesturePhase, async_scroll_performed_default_action bool) EventResult {
	handler.record_last_known_mouse_position(visual_viewport_position, screen_position, buttons,
		modifiers)
	if handler.should_ignore_device_input_event() || !handler.paint_root_available {
		return .dropped
	}
	value := target or { return .dropped }
	handler.last_known_mouse_target_ = value
	mut delta_x := wheel_delta_x
	mut delta_y := wheel_delta_y
	if modifiers & dom.modifier_shift != 0 {
		delta_x, delta_y = delta_y, delta_x
	}
	dispatch_result := handler.dispatch_wheel_event(value, visual_viewport_position, screen_position,
		button, buttons, modifiers, delta_x, delta_y, !async_scroll_performed_default_action)
	if dispatch_result == .cancelled {
		return if async_scroll_performed_default_action { .handled } else { .cancelled }
	}
	if dispatch_result != .accepted {
		return dispatch_result
	}
	if async_scroll_performed_default_action || value.has_scrollable_box {
		return .handled
	}
	return .accepted
}

pub fn (mut handler EventHandler) update_hover_after_scroll() {
	visual_position := handler.last_known_mouse_visual_position_ or { return }
	if handler.mousedown_target_ != '' {
		return
	}
	screen_position := handler.last_known_mouse_screen_position_ or { PixelPoint{} }
	handler.update_hover_after_scroll_at(handler.last_known_mouse_target_, visual_position,
		screen_position, 0, handler.last_known_mouse_buttons_, handler.last_known_mouse_modifiers_)
}

pub fn (mut handler EventHandler) update_hover_after_scroll_at(target ?InputTarget, _ PixelPoint, _ PixelPoint, _ u32, _ u32, _ u32) {
	if !handler.active_document || !handler.paint_root_available {
		return
	}
	value := target or {
		handler.update_hovered_chrome_widget('')
		handler.update_cursor('arrow')
		handler.log('hover-after-scroll-clear', none)
		return
	}
	handler.update_cursor(if value.is_link { 'pointer' } else { 'arrow' })
	handler.log('hover-after-scroll', value)
}
