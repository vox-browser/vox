module layout

import math
import os

const retain_unbounded_border_effects = os.getenv('VOX_RETAIN_UNBOUNDED_BORDER_EFFECTS') != ''
const effect_border_bounds_diagnostics = os.getenv('VOX_EFFECT_BORDER_BOUNDS_DIAGNOSTICS') != ''

fn effect_content_leaf_ink_bounds(command &PaintCommand) ?LayoutRect {
	if command.kind == 'paint_uniform_border' && !retain_unbounded_border_effects {
		return effect_uniform_border_ink_bounds(command)
	}
	return effect_leaf_ink_bounds(command)
}

fn effect_uniform_border_ink_bounds(command &PaintCommand) ?LayoutRect {
	if command.outer_shadow || command.blur != 0 || command.width <= 0
		|| command.height <= 0 || command.stroke_width < 0 {
		return none
	}
	for value in [command.x, command.y, command.width, command.height, command.stroke_width]! {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	radii := command.corner_radii
	for radius in [radii.top_left, radii.top_right, radii.bottom_left, radii.bottom_right]! {
		if math.is_nan(radius.x) || math.is_nan(radius.y) || math.is_inf(radius.x, 0)
			|| math.is_inf(radius.y, 0) || radius.x < 0 || radius.y < 0
			|| radius.x > command.width || radius.y > command.height {
			return none
		}
	}
	// Native and SVG strokes scale with the outline. The portable line player
	// keeps its width in screen space; enclose that stroke as well when a
	// transform shrinks or collapses the outline.
	outset := command.stroke_width + 1
	native := effect_map_ink_bounds(command, LayoutRect{command.x - outset, command.y - outset, command.width + 2 * outset, command.height + 2 * outset}, true) or { return none }
	center := compatibility_affine_map_rect(command.transform,
		LayoutRect{command.x, command.y, command.width, command.height})
	portable := LayoutRect{center.x - outset, center.y - outset, center.width + 2 * outset, center.height + 2 * outset}
	return rect_union(native, portable)
}

fn report_effect_border_bounds(ink LayoutRect) {
	eprintln('Vox effect border bounds: bounded uniform-border group ${ink.x},${ink.y} ${ink.width}x${ink.height}')
}
