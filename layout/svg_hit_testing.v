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
	bounding_box   ?painting.Rect
	is_image       bool
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
	return box.svg_data != unsafe { nil } && box.svg_data.hit_test != unsafe { nil }
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
	if data.pointer_events == .bounding_box || data.is_image {
		if data.pointer_events == .none_ { return false }
		return svg_hit_bounding_box_contains(data.bounding_box or { box.svg_data.bounding_box }, local)
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
	if data.pointer_events == .bounding_box || data.is_image {
		return svg_transformed_hit_bounds(data.bounding_box or { box.svg_data.bounding_box }, matrix)
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

// SVG bounding-box regions include their boundary. Keep this rule local to
// SVG rather than changing the half-open rectangles used by HTML layout.
fn svg_hit_bounding_box_contains(bounds painting.Rect, point painting.Point) bool {
	return bounds.width > 0 && bounds.height > 0 && point.x >= bounds.x
		&& point.x <= bounds.x + bounds.width && point.y >= bounds.y
		&& point.y <= bounds.y + bounds.height
}

// Containers have no filled path of their own. Their bounding-box region is
// the union of descendant object boxes in the container's SVG user space,
// including the gaps between shapes, independent of CSS border-box geometry.
fn svg_container_bounding_box_for_hit_testing(node &Node, state &LayoutState) ?painting.Rect {
	if node.is_svg_text_box() { return svg_text_bounding_box_for_hit_testing(node, state) }
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	mut bounds := ?painting.Rect(none)
	if path := used.computed_svg_path() {
		if rect := svg_path_bounds(path) {
			bounds = painting.Rect{rect.x, rect.y, rect.width, rect.height}
		}
	} else if node.is_svg_image_box() {
		bounds = painting.Rect{used.offset.x().to_double(), used.offset.y().to_double(),
			used.content_width().to_double(), used.content_height().to_double()}
	}
	for child in node.children() {
		if !child.is_svg_graphics_box() || child.is_svg_mask_box() || child.is_svg_clip_box()
			|| child.is_svg_pattern_box() { continue }
		child_bounds := svg_container_bounding_box_for_hit_testing(child, state) or { continue }
		child_styled := child.as_node_with_style() or { continue }
		child_used := state.try_get(child_styled) or { continue }
		transform := child_used.svg_local_transform()
		mapped := svg_transformed_hit_bounds(child_bounds,
			[transform.a, transform.b, transform.c, transform.d, transform.e, transform.f]!)
		bounds = if current := bounds {
			x, y := math.min(current.x, mapped.x), math.min(current.y, mapped.y)
			painting.Rect{x, y, math.max(current.x + current.width, mapped.x + mapped.width) - x,
				math.max(current.y + current.height, mapped.y + mapped.height) - y}
		} else { mapped }
	}
	return bounds
}

// A text element's object box contains its descendant text runs, including
// the space between separately positioned lines. Painting keeps its own path
// bounds; only pointer-events:bounding-box uses this aggregate snapshot.
fn svg_text_bounding_box_for_hit_testing(node &Node, state &LayoutState) ?painting.Rect {
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	mut bounds := ?painting.Rect(none)
	if origin := used.svg_text_paint_origin() {
		cells := origin.character_cells
		if cells.width > 0 && cells.height > 0 {
			bounds = painting.Rect{cells.x, cells.y, cells.width, cells.height}
		}
	} else if path := used.computed_svg_path() {
		if rect := svg_path_bounds(path) {
			bounds = painting.Rect{rect.x, rect.y, rect.width, rect.height}
		}
	}
	for child in node.children() {
		if !child.is_svg_text_box() && !child.is_svg_text_path_box() { continue }
		child_bounds := svg_text_bounding_box_for_hit_testing(child, state) or { continue }
		child_styled := child.as_node_with_style() or { continue }
		child_used := state.try_get(child_styled) or { continue }
		transform := child_used.svg_local_transform()
		mapped := svg_transformed_hit_bounds(child_bounds,
			[transform.a, transform.b, transform.c, transform.d, transform.e, transform.f]!)
		bounds = if current := bounds {
			x, y := math.min(current.x, mapped.x), math.min(current.y, mapped.y)
			painting.Rect{x, y, math.max(current.x + current.width, mapped.x + mapped.width) - x,
				math.max(current.y + current.height, mapped.y + mapped.height) - y}
		} else { mapped }
	}
	return bounds
}
