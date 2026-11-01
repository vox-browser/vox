module layout

import css
import painting

// Blink fills a single solid rounded side through its outer and inner rrect
// clips. A cubic path around the border has different GPU corner coverage.
fn append_chromium_single_rounded_border(mut commands []PaintCommand, border BoxEdges,
	colors BoxColors, styles BoxBorderStyles, radii BoxRadii, rect painting.IntRect,
	opacity f64) bool {
	if box_radii_are_zero(radii) { return false }
	widths := [border.top, border.right, border.bottom, border.left]
	side_styles := [styles.top, styles.right, styles.bottom, styles.left]
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]
	mut side := -1
	for index, width in widths {
		if width <= 0 { continue }
		if side_styles[index] != .solid { return false }
		if side_colors[index].a == 0 { continue }
		if side >= 0 || side_colors[index].a != 255 {
			return false
		}
		side = index
	}
	if side < 0 || widths.any(it * 2 >= rect.width || it * 2 >= rect.height) {
		return false
	}
	// Overlapping opposite corners require Blink's additional side clip paths.
	for radius in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
		if radius.x * 2 >= rect.width || radius.y * 2 >= rect.height { return false }
	}
	commands << PaintCommand{
		kind:         'paint_rounded_border_' + ['top', 'right', 'bottom', 'left'][side]
		x:            rect.x
		y:            rect.y
		width:        rect.width
		height:       rect.height
		corner_radii: radii
		stroke_width: widths[side]
		// The transparent sides still inset the inner rounded rectangle and
		// determine the visible side's antialiased corner miters.
		points:       widths
		color:        side_colors[side].serialize()
		opacity:      opacity
	}
	return true
}

pub fn rounded_single_border_mode(kind string) int {
	return match kind {
		'paint_rounded_border_top' { 2 }
		'paint_rounded_border_right' { 3 }
		'paint_rounded_border_bottom' { 4 }
		'paint_rounded_border_left' { 5 }
		else { 0 }
	}
}

// Retain shared antialias coverage between a rounded background and border.
// Single sides with transparent neighbors also need Blink's ClipLayer. Pair
// only consecutive solid fills with matching geometry and painting state.
fn chromium_pair_rounded_border_background(mut commands []PaintCommand, background_start int,
	border_start int, border_end int, inline_background bool) {
	if background_start < 0 || border_start <= background_start
		|| border_end != border_start + 1 || border_end > commands.len {
		return
	}
	border := commands[border_start]
	mut background_index := background_start
	if commands[background_index].kind == 'paint_outer_box_shadow' {
		color := css.parse_color_string(border.color) or { return }
		if border.kind != 'paint_uniform_border' || color.a == 0 || color.a == 255 { return }
		// Opaque backgrounds paint after the outer shadows. The range starts
		// before those shadows, rather than at the solid background itself.
		for background_index < border_start && background_index - background_start < 8
			&& commands[background_index].kind == 'paint_outer_box_shadow' {
			background_index++
		}
	}
	if border_start != background_index + 1 { return }
	background := commands[background_index]
	if (rounded_single_border_mode(border.kind) == 0 && border.kind != 'paint_uniform_border')
		|| background.kind != 'fill_rect'
		|| background.radius <= 0 || background.opacity != border.opacity
		|| background.clip_outs != border.clip_outs {
		return
	}
	// Opaque block borders inset their backgrounds to the stroke center.
	// Translucent block borders and inline backgrounds keep the outer box;
	// retain that extent so the native player can share their rounded clip.
	mut inset := 0.0
	if border.kind == 'paint_uniform_border' && background.x != border.x {
		inset = border.stroke_width / 2
		if inset <= 0 { return }
	}
	if [background.x + inset, background.y + inset,
		background.width - inset * 2, background.height - inset * 2] !=
		[border.x, border.y, border.width, border.height] { return }
	radius := non_negative(background.radius - inset)
	for corner in [border.corner_radii.top_left, border.corner_radii.top_right,
		border.corner_radii.bottom_right, border.corner_radii.bottom_left] {
		if corner.x != radius || corner.y != radius { return }
	}
	commands[background_index].underlays_next = true
}

// Portable players keep the ordinary translated border paths.
pub fn rounded_single_border_fallback(command PaintCommand) []PaintCommand {
	mode := rounded_single_border_mode(command.kind)
	if mode == 0 { return []PaintCommand{} }
	width := command.stroke_width
	widths := if command.points.len == 4 {
		command.points
	} else {
		[if mode == 2 { width } else { 0.0 }, if mode == 3 { width } else { 0.0 },
			if mode == 4 { width } else { 0.0 }, if mode == 5 { width } else { 0.0 }]
	}
	border := BoxEdges{
		top:    widths[0]
		right:  widths[1]
		bottom: widths[2]
		left:   widths[3]
	}
	color := css.parse_color_string(command.color) or { return []PaintCommand{} }
	colors := BoxColors{
		top:    if mode == 2 { color } else { css.Color{ a: 0 } }
		right:  if mode == 3 { color } else { css.Color{ a: 0 } }
		bottom: if mode == 4 { color } else { css.Color{ a: 0 } }
		left:   if mode == 5 { color } else { css.Color{ a: 0 } }
	}
	mut commands := []PaintCommand{}
	append_translated_border_commands(mut commands, border, colors,
		BoxBorderStyles{}, command.corner_radii, command.x, command.y, command.width,
		command.height, command.opacity, false)
	return commands.map(PaintCommand{
		...command
		kind:         it.kind
		x:            it.x
		y:            it.y
		width:        it.width
		height:       it.height
		color:        it.color
		svg_data:     it.svg_data
		points:       it.points
		stroke_width: it.stroke_width
	})
}
