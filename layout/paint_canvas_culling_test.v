module layout

import math

fn test_canvas_culling_keeps_visible_edges_and_a_native_raster_fringe() {
	for x in [f64(-13), 103] {
		command := PaintCommand{kind: 'fill_rect', x: x, y: 20, width: 10, height: 10}
		assert !paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	}
	for x in [f64(-14), 104] {
		command := PaintCommand{kind: 'fill_rect', x: x, y: 20, width: 10, height: 10}
		assert paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	}
	command := PaintCommand{kind: 'fill_rect', x: 20, y: 20, width: 10, height: 10}
	assert !paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	assert paint_leaf_is_outside_canvas(command, 0, 88, 100, 100)
}

fn test_canvas_culling_maps_transforms_and_preserves_stroke_extent() {
	command := PaintCommand{
		kind: 'fill_rect', x: 100, y: 200, width: 10, height: 20
		transform: [f64(0), 2, -2, 0, 420, -190]!
	}
	assert !paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	stroke := PaintCommand{kind: 'stroke_rounded_rect', x: 104, y: 20, width: 10, height: 10, stroke_width: 2}
	assert !paint_leaf_is_outside_canvas(stroke, 0, 0, 100, 100)
	assert paint_leaf_is_outside_canvas(PaintCommand{...stroke, x: 106}, 0, 0, 100, 100)
}

fn test_canvas_culling_retains_unknown_and_effect_inputs() {
	for kind in ['paint_outer_box_shadow', 'draw_text_shadow', 'draw_text', 'draw_svg_path', 'draw_nested_viewport'] {
		command := PaintCommand{kind: kind, x: 1000, y: 2000, width: 10, height: 20}
		assert !paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	}
	base := PaintCommand{kind: 'fill_rect', x: 1000, y: 2000, width: 10, height: 20}
	assert !paint_leaf_is_outside_canvas(PaintCommand{...base, blur: 2}, 0, 0, 100, 100)
	assert !paint_leaf_is_outside_canvas(PaintCommand{...base, outer_shadow: true}, 0, 0, 100, 100)
	assert !paint_leaf_is_outside_canvas(PaintCommand{...base, width: 0}, 0, 0, 100, 100)
	assert !paint_leaf_is_outside_canvas(PaintCommand{...base, x: math.nan()}, 0, 0, 100, 100)
	assert !paint_leaf_is_outside_canvas(base, 0, 0, math.inf(1), 100)
}

fn test_canvas_culling_retains_geometry_that_can_round_back_into_view() {
	// Both 1e12 operands round to the same float32 magnitude, so native ink
	// can start at zero even though the float64 bounds begin beyond the view.
	command := PaintCommand{
		kind: 'fill_rect', x: 1e12, y: 20, width: 20, height: 20
		transform: [f64(1), 0, 0, 1, -1e12 + 200, 0]!
	}
	assert !paint_leaf_is_outside_canvas(command, 0, 0, 100, 100)
	scaled := PaintCommand{
		kind: 'fill_rect', x: 1000, y: 20, width: 20, height: 20
		transform: [f64(10000), 0, 0, 1, 0, 0]!
	}
	assert !paint_leaf_is_outside_canvas(scaled, 0, 0, 100, 100)
}
