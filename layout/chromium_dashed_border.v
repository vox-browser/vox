module layout

import math
import painting

// Blink StyledStrokeData::DashEffectFromStrokeStyle for an open dashed side.
// Match its float arithmetic and its preference for starting/ending on a dash.
fn chromium_border_dash_intervals(length f32, thickness f32) []f64 {
	dash := thickness * if thickness >= 3 { f32(2) } else { f32(3) }
	gap := thickness * if thickness >= 3 { f32(1) } else { f32(2) }
	if thickness <= 0 || length <= dash * 2 { return []f64{} }
	if length <= dash * 2 + gap {
		multiplier := length / (dash * 2 + gap)
		return [f64(dash * multiplier), f64(gap * multiplier)]
	}
	minimum := f32(math.floor(f64((length + gap) / (dash + gap))))
	maximum := minimum + 1
	min_gap := (length - minimum * dash) / (minimum - 1)
	max_gap := (length - maximum * dash) / (maximum - 1)
	selected := if max_gap <= 0 || math.abs(min_gap - gap) < math.abs(max_gap - gap) { min_gap } else { max_gap }
	return [f64(dash), f64(selected)]
}

// A single square side needs no corner miter clips. Keep dashed strokes on
// Skia's path renderer, rather than the portable line player's dash policy.
fn append_chromium_dashed_border(mut commands []PaintCommand, border BoxEdges,
	colors BoxColors, styles BoxBorderStyles, radii BoxRadii, rect painting.IntRect,
	opacity f64) bool {
	if !box_radii_are_zero(radii) || rect.width <= 0 || rect.height <= 0 { return false }
	widths := [border.top, border.right, border.bottom, border.left]
	side_styles := [styles.top, styles.right, styles.bottom, styles.left]
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]
	mut edge := -1
	for index, width in widths {
		if width <= 0 { continue }
		if edge >= 0 || side_styles[index] != .dashed || width != math.floor(width) { return false }
		edge = index
	}
	if edge < 0 { return false }
	thickness := widths[edge]
	if thickness >= math.min(rect.width, rect.height) { return false }
	from := match edge {
		0 { painting.Point{rect.x, f64(rect.y) + thickness / 2} }
		1 { painting.Point{f64(rect.right()) - thickness / 2, rect.y} }
		2 { painting.Point{rect.x, f64(rect.bottom()) - thickness / 2} }
		else { painting.Point{f64(rect.x) + thickness / 2, rect.y} }
	}
	to := if edge in [0, 2] { painting.Point{rect.right(), from.y} } else { painting.Point{from.x, rect.bottom()} }
	length := if edge in [0, 2] { rect.width } else { rect.height }
	path := painting.ClipPathVisualData{segments: [
		painting.ClipPathSegment{kind: .move_to, point: from},
		painting.ClipPathSegment{kind: .line_to, point: to},
	]}
	commands << PaintCommand{
		kind: 'draw_svg_path'
		x: rect.x
		y: rect.y
		width: rect.width
		height: rect.height
		stroke_color: side_colors[edge].serialize()
		stroke_width: thickness
		opacity: opacity
		svg_data: &PaintSVGPathData{
			path: 'M${from.x} ${from.y}L${to.x} ${to.y}'
			path_data: compatibility_pack_clip_path_segments(path)
			stroke_dasharray: chromium_border_dash_intervals(f32(length), f32(thickness))
		}
	}
	return true
}
