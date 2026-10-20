module dom

import math

// DOM viewport coordinates remain CSS pixels. Layout may use a larger
// coordinate space before the viewport's paint transform maps it back.
pub fn (d &Document) layout_coordinate_scale() f64 {
	return if d.layout_coordinate_scale_ > 0 { d.layout_coordinate_scale_ } else { 1.0 }
}

pub fn (mut d Document) set_layout_coordinate_scale(value f64) {
	scale := if value <= 0 || math.is_nan(value) || math.is_inf(value, 0) { 1.0 } else { value }
	if d.layout_coordinate_scale() == scale { return }
	d.layout_coordinate_scale_ = scale
	d.set_needs_full_layout_tree_update(true)
	d.request_frame()
}

pub fn (d &Document) layout_viewport_rect() Rect {
	rect := d.viewport_rect()
	scale := d.layout_coordinate_scale()
	return Rect{rect.x * scale, rect.y * scale, rect.width * scale, rect.height * scale}
}
