// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/MiddleButtonScrollHandler.{h,cpp}.
module page

import math

const middle_button_dead_zone_radius = 15.0
const middle_button_speed_factor = 5.0
const middle_button_scroll_interval_seconds = 0.016

@[heap]
pub struct MiddleButtonScrollHandler {
pub:
	container InputTarget
	origin    PixelPoint
mut:
	mouse_position_         PixelPoint
	fractional_delta_       PixelPoint
	moved_beyond_dead_zone_ bool
	layout_is_up_to_date_   bool
	has_document_paintable_ bool
	repaint_request_count_  int
	closed_                 bool
}

pub fn MiddleButtonScrollHandler.create(container InputTarget, origin PixelPoint) &MiddleButtonScrollHandler {
	return &MiddleButtonScrollHandler{
		container: container
		origin: origin
		mouse_position_: origin
		layout_is_up_to_date_: container.layout_is_up_to_date
		has_document_paintable_: container.has_document_paintable
		repaint_request_count_: if container.has_document_paintable { 1 } else { 0 }
	}
}

pub fn (mut handler MiddleButtonScrollHandler) set_document_layout_state(layout_is_up_to_date bool, has_paintable bool) {
	handler.layout_is_up_to_date_ = layout_is_up_to_date
	handler.has_document_paintable_ = has_paintable
}

// C++ performs this in ~MiddleButtonScrollHandler. EventHandler calls close
// before releasing its optional handler so navigation can invalidate layout
// without making the teardown repaint query assert.
pub fn (mut handler MiddleButtonScrollHandler) close() {
	if handler.closed_ {
		return
	}
	handler.closed_ = true
	if !handler.layout_is_up_to_date_ {
		return
	}
	if handler.has_document_paintable_ {
		handler.repaint_request_count_++
	}
}

pub fn (handler &MiddleButtonScrollHandler) repaint_request_count() int {
	return handler.repaint_request_count_
}

pub fn find_middle_button_scrollable_ancestor(targets []InputTarget) ?InputTarget {
	for target in targets {
		if target.has_scrollable_box {
			return target
		}
	}
	return none
}

pub fn (mut handler MiddleButtonScrollHandler) update_mouse_position(position PixelPoint) {
	handler.mouse_position_ = position
}

pub fn (handler &MiddleButtonScrollHandler) mouse_has_moved_beyond_dead_zone() bool {
	return handler.moved_beyond_dead_zone_
}

pub fn (mut handler MiddleButtonScrollHandler) perform_tick() ?ScrollTick {
	distance_x := handler.mouse_position_.x - handler.origin.x
	distance_y := handler.mouse_position_.y - handler.origin.y
	if math.hypot(distance_x, distance_y) < middle_button_dead_zone_radius {
		return none
	}
	handler.moved_beyond_dead_zone_ = true
	if !handler.container.has_scrollable_box {
		return none
	}
	speed_x := math.max(-max_auto_scroll_speed, math.min(distance_x * middle_button_speed_factor, max_auto_scroll_speed))
	speed_y := math.max(-max_auto_scroll_speed, math.min(distance_y * middle_button_speed_factor, max_auto_scroll_speed))
	handler.fractional_delta_ = PixelPoint{
		x: handler.fractional_delta_.x + speed_x * middle_button_scroll_interval_seconds
		y: handler.fractional_delta_.y + speed_y * middle_button_scroll_interval_seconds
	}
	delta_x := int(handler.fractional_delta_.x)
	delta_y := int(handler.fractional_delta_.y)
	handler.fractional_delta_ = PixelPoint{
		x: handler.fractional_delta_.x - delta_x
		y: handler.fractional_delta_.y - delta_y
	}
	return ScrollTick{
		delta_x: delta_x
		delta_y: delta_y
		selection_position: handler.mouse_position_
	}
}
