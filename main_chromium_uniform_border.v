module main

import layout
import css

fn chromium_uniform_border_uses_clip_layer(border &layout.PaintCommand,
	background &layout.PaintCommand) bool {
	if border.kind != 'paint_uniform_border' || !background.underlays_next { return false }
	if border.has_clip && (border.clip_width <= 0 || border.clip_height <= 0
		|| chromium_msaa_clip_list_has_empty_clip(border.clip_list)) { return false }
	color := css.parse_color_string(border.color) or { return false }
	return color.a < 255
		&& chromium_uniform_border_shares_outer_clip(border, background)
}

// Only a background filling the complete outer border box participates in
// Blink's rounded bleed-avoidance layer. Padding/content clips stay separate.
fn chromium_uniform_border_shares_outer_clip(border &layout.PaintCommand,
	background &layout.PaintCommand) bool {
	if border.kind != 'paint_uniform_border' || background.kind != 'fill_rect'
		|| border.stroke_width <= 0 || background.radius <= 0 {
		return false
	}
	half := border.stroke_width / 2
	if [background.x + half, background.y + half,
		background.width - half * 2, background.height - half * 2] !=
		[border.x, border.y, border.width, border.height] { return false }
	for corner in [border.corner_radii.top_left, border.corner_radii.top_right,
		border.corner_radii.bottom_right, border.corner_radii.bottom_left] {
		if corner.x != background.radius - half || corner.y != corner.x { return false }
	}
	return true
}
