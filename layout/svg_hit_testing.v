module layout

import css
import math
import painting
import skia

// The paint payload can omit transparent paints and use compact ellipse
// commands. Retain the original geometry and specified paint presence for hits.
pub struct SVGPathHitData {
	pointer_events css.PointerEvents
	has_fill       bool
	has_stroke     bool
	path           skia.Path
	text_cells     ?painting.Rect
}

fn svg_pointer_events_require_visibility(mode css.PointerEvents) bool {
	return mode in [.auto_, .visible_painted, .visible_fill, .visible_stroke, .visible]
}

fn svg_pointer_event_areas(data &SVGPathHitData) u8 {
	return match data.pointer_events {
		.auto_, .visible_painted, .painted {
			(if data.has_fill { u8(1) } else { u8(0) }) | (if data.has_stroke {
				u8(2)
			} else {
				u8(0)
			})
		}
		.visible_fill, .fill { u8(1) }
		.visible_stroke, .stroke { u8(2) }
		.visible, .all { u8(3) }
		.bounding_box, .none_ { u8(0) }
	}
}

fn (box &BlockBox) has_svg_hit_geometry() bool {
	return box.has_svg_path() && box.svg_data.hit_test != unsafe { nil }
}

fn (box &BlockBox) visible_for_pointer_events() bool {
	if !box.pointer_events_enabled { return false }
	if box.has_svg_hit_geometry() {
		return box.visible || !svg_pointer_events_require_visibility(box.svg_data.hit_test.pointer_events)
	}
	return box.visible
}

fn (box &BlockBox) svg_contains_hit_test_point(point painting.Point) bool {
	if !box.has_svg_hit_geometry() {
		return box.svg_path_bounding_box_contains_hit_test_point(point)
	}
	matrix := normalized_affine(box.svg_path().path_transform)
	determinant := matrix[0] * matrix[3] - matrix[1] * matrix[2]
	if determinant == 0 { return false }
	x, y := point.x - matrix[4], point.y - matrix[5]
	local := painting.Point{(matrix[3] * x - matrix[2] * y) / determinant, (-matrix[1] * x + matrix[0] * y) / determinant}
	data := box.svg_data.hit_test
	if data.pointer_events == .bounding_box {
		return box.svg_data.bounding_box.contains(local)
	}
	areas := svg_pointer_event_areas(data)
	if areas == 0 { return false }
	// Text's fill and stroke both cover character cells, including whitespace
	// and the unpainted parts of glyphs, rather than the glyph outlines.
	if cells := data.text_cells { return cells.contains(local) }
	style := box.svg_path()
	query_point := if style.non_scaling_stroke { point } else { local }
	return skia.path_hit_test(skia.PathHitTest{
		path:        data.path
		x:           f32(query_point.x)
		y:           f32(query_point.y)
		areas:       areas
		width:       f32(box.svg_data.stroke_width)
		cap:         style.stroke_linecap
		join:        match style.stroke_linejoin {
			0 { 2 }
			1 { 0 }
			else { 1 }
		}
		miter:       f32(style.stroke_miterlimit)
		dashes:      style.stroke_dasharray.map(f32(it))
		dash_offset: f32(style.stroke_dashoffset)
		non_scaling: style.non_scaling_stroke
		transform:   [f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]),
			f32(matrix[5])]!
	})
}

fn svg_transformed_hit_bounds(rect painting.Rect, matrix [6]f64) painting.Rect {
	mut left, top := math.inf(1), math.inf(1)
	mut right, bottom := math.inf(-1), math.inf(-1)
	for point in [painting.Point{rect.x, rect.y}, painting.Point{rect.x + rect.width, rect.y},
		painting.Point{rect.x, rect.y + rect.height},
		painting.Point{rect.x + rect.width, rect.y + rect.height}] {
		x := matrix[0] * point.x + matrix[2] * point.y + matrix[4]
		y := matrix[1] * point.x + matrix[3] * point.y + matrix[5]
		left, top = math.min(left, x), math.min(top, y)
		right, bottom = math.max(right, x), math.max(bottom, y)
	}
	return painting.Rect{left, top, right - left, bottom - top}
}

fn svg_inflated_hit_bounds(rect painting.Rect, amount f64) painting.Rect {
	return painting.Rect{rect.x - amount, rect.y - amount, rect.width + 2 * amount, rect.height + 2 * amount}
}

// Culling needs hit bounds, which can extend beyond painted bounds when a
// stroke is none or a text cell extends beyond its glyph. Miter/cap inflation
// is conservative; the exact query above decides whether the point hits.
fn (box &BlockBox) svg_hit_test_bounds() painting.Rect {
	data := box.svg_data.hit_test
	matrix := normalized_affine(box.svg_path().path_transform)
	if data.pointer_events == .bounding_box {
		return svg_transformed_hit_bounds(box.svg_data.bounding_box, matrix)
	}
	if cells := data.text_cells { return svg_transformed_hit_bounds(cells, matrix) }
	mut bounds := box.svg_data.bounding_box
	stroke := if svg_pointer_event_areas(data) & 2 != 0 {
		math.max(0, box.svg_data.stroke_width) * math.max(2, box.svg_path().stroke_miterlimit) / 2
	} else {
		f64(0)
	}
	if box.svg_path().non_scaling_stroke {
		return svg_inflated_hit_bounds(svg_transformed_hit_bounds(bounds, matrix), stroke)
	}
	bounds = svg_inflated_hit_bounds(bounds, stroke)
	return svg_transformed_hit_bounds(bounds, matrix)
}
