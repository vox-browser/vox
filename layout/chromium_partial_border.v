module layout

import css
import math
import painting

// A transformed CSS box records its border in box-local coordinates. Blink's
// paint-offset translation rounds the box origin and discards the remaining
// fraction at a non-translation transform. Keep the origin separate from the
// retained transform so compositor updates can repeat that operation.
pub struct PaintLocalBorderData {
pub:
	origin_x f64
	origin_y f64
	transform_context_index int
	initial_transform painting.Affine
}

fn chromium_local_border_transform(data &PaintLocalBorderData, full [6]f64,
	own_value [6]f64) [6]f64 {
	own := normalized_affine(own_value)
	mut x := data.origin_x
	mut y := data.origin_y
	if own[0] != 1 || own[1] != 0 || own[2] != 0 || own[3] != 1 {
		determinant := own[0] * own[3] - own[1] * own[2]
		if determinant != 0 {
			// An axis untouched by a scale/translation keeps its subpixel
			// accumulation (CanPropagateSubpixelAccumulation). Rotation or skew
			// discards it on both axes.
			dx := if own[1] == 0 && own[2] == 0 && own[0] == 1 { 0.0 } else { math.round(x) - x }
			dy := if own[1] == 0 && own[2] == 0 && own[3] == 1 { 0.0 } else { math.round(y) - y }
			// The rounded paint offset belongs outside this box's transform,
			// but inside its ancestors' transforms and scrolling.
			x += (own[3] * dx - own[2] * dy) / determinant
			y += (own[0] * dy - own[1] * dx) / determinant
		}
	}
	return multiply_affine(full, translated_affine(x, y))
}

fn chromium_border_replay_transform(command &PaintCommand, full [6]f64,
	tree &painting.AccumulatedVisualContextTree) [6]f64 {
	data := command.local_border_data
	if data == unsafe { nil } { return full }
	initial := data.initial_transform
	mut own := [initial.a, initial.b, initial.c, initial.d, initial.e, initial.f]!
	if data.transform_context_index > 0 && data.transform_context_index < tree.nodes.len {
		node := tree.node_at(data.transform_context_index)
		if node.data is painting.TransformVisualData {
			own = css.project_plane_to_affine_transform(node.data.matrix_including_origin_4x4()) or { own }
		}
	}
	return chromium_local_border_transform(data, full, own)
}

// BoxBorderPainter::DrawSolidBoxSide uses antialiased rectangles when adjacent
// opaque edges have the same color and need no miter clip. A path around the
// joined edges has different corner coverage under rotation.
fn append_chromium_partial_border(mut commands []PaintCommand, box &BlockBox,
	colors BoxColors, radii BoxRadii, rect LayoutRect, opacity f64) bool {
	// Portable players flatten opacity instead of isolating the complete box.
	// Keep their translucent corners on the joined-path fallback.
	if opacity != 1 || !box.snaps_background_rect || box.own_paint_transform == [6]f64{}
		|| rect.width <= 0 || rect.height <= 0
		|| rect.width != math.floor(rect.width) || rect.height != math.floor(rect.height) {
		return false
	}
	own := box.own_paint_transform
	if own[0] == 1 && own[1] == 0 && own[2] == 0 && own[3] == 1 { return false }
	if box.uses_own_paint_transform_4x4 {
		matrix := box.own_paint_transform_4x4
		if matrix.m13 != 0 || matrix.m23 != 0 || matrix.m31 != 0 || matrix.m32 != 0
			|| matrix.m33 != 1 || matrix.m34 != 0 || matrix.m41 != 0 || matrix.m42 != 0
			|| matrix.m43 != 0 || matrix.m44 != 1 {
			return false
		}
	}
	for radius in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
		if radius.x != 0 || radius.y != 0 { return false }
	}
	widths := [box.border.top, box.border.right, box.border.bottom, box.border.left]
	styles := [box.border_styles.top, box.border_styles.right, box.border_styles.bottom, box.border_styles.left]
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]
	mut color := css.Color{}
	mut count := 0
	for index, width in widths {
		if width <= 0 { continue }
		if styles[index] != .solid || side_colors[index].a != 255
			|| width != math.floor(width) || width >= math.min(rect.width, rect.height) {
			return false
		}
		if count > 0 && side_colors[index] != color { return false }
		color = side_colors[index]
		count++
	}
	if count == 0 || count == 4 { return false }
	data := &PaintLocalBorderData{
		origin_x: rect.x
		origin_y: rect.y
		transform_context_index: box.own_transform_visual_context_idx
		initial_transform: painting.Affine{a: own[0], b: own[1], c: own[2], d: own[3], e: own[4], f: own[5]}
	}
	w := math.round(rect.width)
	h := math.round(rect.height)
	for index, width in widths {
		if width <= 0 { continue }
		side := match index {
			0 { LayoutRect{0, 0, w, width} }
			1 { LayoutRect{w - width, 0, width, h} }
			2 { LayoutRect{0, h - width, w, width} }
			else { LayoutRect{0, 0, width, h} }
		}
		commands << PaintCommand{
			kind: 'fill_rect'
			x: side.x
			y: side.y
			width: side.width
			height: side.height
			color: color.serialize()
			opacity: opacity
			antialiased_rect: true
			local_border_data: data
			force_dark_role: .border
			force_dark_role_set: true
		}
	}
	return true
}
