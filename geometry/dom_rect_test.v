module geometry

import math

fn test_domrectinit_defaults() {
	init := DOMRectInit{}
	assert init.x == 0.0
	assert init.y == 0.0
	assert init.width == 0.0
	assert init.height == 0.0
}

fn test_readonly_construct_and_getters() {
	rect := DOMRectReadOnly.construct(10.0, 20.0, 30.0, 40.0)
	assert rect.x() == 10.0
	assert rect.y() == 20.0
	assert rect.width() == 30.0
	assert rect.height() == 40.0
}

fn test_readonly_create_empty() {
	rect := DOMRectReadOnly.create()
	assert rect.x() == 0.0
	assert rect.y() == 0.0
	assert rect.width() == 0.0
	assert rect.height() == 0.0
}

fn test_edges_positive_dimensions() {
	rect := DOMRectReadOnly.construct(10.0, 20.0, 30.0, 40.0)
	assert rect.left() == 10.0
	assert rect.top() == 20.0
	assert rect.right() == 40.0 // x + width
	assert rect.bottom() == 60.0 // y + height
}

fn test_edges_negative_dimensions() {
	// Negative width/height flip which corner is the top-left; edges use min/max accordingly.
	rect := DOMRectReadOnly.construct(10.0, 20.0, -30.0, -40.0)
	assert rect.left() == -20.0 // min(10, 10 + -30)
	assert rect.right() == 10.0 // max(10, -20)
	assert rect.top() == -20.0 // min(20, 20 + -40)
	assert rect.bottom() == 20.0 // max(20, -20)
}

fn test_edges_nan_inputs() {
	// A NaN coordinate propagates to the derived edges that depend on it.
	nan := math.nan()
	rect := DOMRectReadOnly.construct(nan, 20.0, 30.0, nan)
	assert math.is_nan(rect.left()) // depends on x
	assert math.is_nan(rect.right()) // depends on x
	assert math.is_nan(rect.top()) // depends on height
	assert math.is_nan(rect.bottom()) // depends on height
	// The y-only edges are unaffected here since y and width are finite... but top/bottom use height.
	assert rect.y() == 20.0
}

fn test_edges_preserve_first_argument_negative_zero_on_ties() {
	rect := DOMRectReadOnly.construct(-0.0, -0.0, 0.0, 0.0)
	assert math.signbit(rect.left())
	assert math.signbit(rect.right())
	assert math.signbit(rect.top())
	assert math.signbit(rect.bottom())
}

fn test_from_rect() {
	default_rect := DOMRectReadOnly.from_rect(DOMRectInit{})
	assert default_rect.x() == 0.0
	assert default_rect.width() == 0.0
	partial := DOMRectReadOnly.from_rect(DOMRectInit{ x: 5.0, width: 15.0 })
	assert partial.x() == 5.0
	assert partial.y() == 0.0
	assert partial.width() == 15.0
	assert partial.height() == 0.0
}

fn test_domrect_inherits_getters_and_edges() {
	rect := DOMRect.construct(1.0, 2.0, 3.0, 4.0)
	assert rect.x() == 1.0
	assert rect.height() == 4.0
	// The derived edges are inherited from DOMRectReadOnly.
	assert rect.right() == 4.0
	assert rect.bottom() == 6.0
}

fn test_domrect_setters() {
	mut rect := DOMRect.construct(0.0, 0.0, 0.0, 0.0)
	rect.set_x(5.0)
	rect.set_y(6.0)
	rect.set_width(7.0)
	rect.set_height(8.0)
	assert rect.x() == 5.0
	assert rect.y() == 6.0
	assert rect.width() == 7.0
	assert rect.height() == 8.0
	// Edges reflect the mutated values.
	assert rect.right() == 12.0
	assert rect.bottom() == 14.0
}

fn test_domrect_from_rect() {
	rect := DOMRect.from_rect(DOMRectInit{ x: 1.0, y: 2.0, width: 3.0, height: 4.0 })
	assert rect.x() == 1.0
	assert rect.y() == 2.0
	assert rect.width() == 3.0
	assert rect.height() == 4.0
}
