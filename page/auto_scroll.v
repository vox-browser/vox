// Copyright (c) 2026, Jelle Raaijmakers <jelle@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Page/AutoScrollHandler.{h,cpp}.
module page

import dom
import math

const auto_scroll_interval_seconds = 0.016
const auto_scroll_edge_threshold = 7.0
const viewport_edge_inset = 25.0
const distance_to_speed_factor = 100.0
const max_auto_scroll_speed = 5000.0

pub fn effective_auto_scroll_edge(scrollport PixelRect, viewport PixelRect) PixelRect {
	effective := fn (distance f64) f64 {
		return auto_scroll_edge_threshold + math.max(0.0, viewport_edge_inset - distance)
	}
	return scrollport.shrunken(effective(scrollport.y - viewport.y),
		effective(viewport.right() - scrollport.right()),
		effective(viewport.bottom() - scrollport.bottom()), effective(scrollport.x - viewport.x))
}

pub fn auto_scroll_speed(mouse PixelPoint, edge PixelRect) PixelPoint {
	axis_speed := fn (position f64, start f64, end f64) f64 {
		if position < start {
			return -math.min((start - position) * distance_to_speed_factor, max_auto_scroll_speed)
		}
		if position > end {
			return math.min((position - end) * distance_to_speed_factor, max_auto_scroll_speed)
		}
		return 0
	}
	return PixelPoint{
		x: axis_speed(mouse.x, edge.x, edge.right())
		y: axis_speed(mouse.y, edge.y, edge.bottom())
	}
}

// Returns the committed layout node which owns an element's auto-scroll
// scrollport. The document scrolling element is represented by the viewport
// node, not by the element's own layout node.
pub fn AutoScrollHandler.auto_scroll_layout_node(element &dom.Element) ?&dom.LayoutNode {
	mut layout_node := element.as_node().unsafe_layout_node()
	if scrolling_element := element.document().scrolling_element() {
		if voidptr(scrolling_element) == voidptr(element) {
			viewport := element.document().unsafe_layout_node() or { return none }
			layout_node = viewport.root_layout_node()
		}
	}
	committed := layout_node or { return none }
	if committed.paintables().len == 0 {
		return none
	}
	return committed
}

@[heap]
pub struct AutoScrollHandler {
mut:
	active_          bool
	mouse_position_  PixelPoint
	fractional_delta PixelPoint
}

pub fn (handler &AutoScrollHandler) is_active() bool {
	return handler.active_
}

pub fn (mut handler AutoScrollHandler) process(mouse PixelPoint, scrollport PixelRect, viewport PixelRect, is_text_control bool) PixelPoint {
	handler.mouse_position_ = mouse
	edge := effective_auto_scroll_edge(scrollport, viewport)
	if edge.contains(mouse) {
		handler.deactivate()
		return mouse
	}
	handler.active_ = true
	return if is_text_control { constrain_point(mouse, scrollport) } else { mouse }
}

pub fn (mut handler AutoScrollHandler) deactivate() {
	handler.active_ = false
	handler.fractional_delta = PixelPoint{}
}

// perform_tick returns the whole-pixel scroll delta and selection position.
// The caller reports whether selection/paintability still exists; native timer
// scheduling remains an embedder responsibility.
pub fn (mut handler AutoScrollHandler) perform_tick(scrollport PixelRect, viewport PixelRect, selecting bool, paintable bool, is_text_control bool) ?ScrollTick {
	if !handler.active_ {
		return none
	}
	if !selecting || !paintable {
		handler.deactivate()
		return none
	}
	edge := effective_auto_scroll_edge(scrollport, viewport)
	if edge.contains(handler.mouse_position_) {
		handler.deactivate()
		return none
	}
	speed := auto_scroll_speed(handler.mouse_position_, edge)
	handler.fractional_delta = PixelPoint{
		x: handler.fractional_delta.x + speed.x * auto_scroll_interval_seconds
		y: handler.fractional_delta.y + speed.y * auto_scroll_interval_seconds
	}
	dx := int(handler.fractional_delta.x)
	dy := int(handler.fractional_delta.y)
	handler.fractional_delta = PixelPoint{
		x: handler.fractional_delta.x - dx
		y: handler.fractional_delta.y - dy
	}
	return ScrollTick{
		delta_x:            dx
		delta_y:            dy
		selection_position: if is_text_control {
			constrain_point(handler.mouse_position_, scrollport)
		} else {
			handler.mouse_position_
		}
	}
}

pub struct ScrollTick {
pub:
	delta_x            int
	delta_y            int
	selection_position PixelPoint
}
