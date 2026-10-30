module layout

import css
import math

// Preserve computed color precision for opaque solid sides that share one
// color. Invisible sides need no matching color; a border-bottom is common.
fn chromium_border_srgb_color(handle voidptr, widths BoxEdges, colors BoxColors,
	styles BoxBorderStyles) &PaintSRGBColor {
	if handle == unsafe { nil } { return unsafe { nil } }
	node := unsafe { &Node(handle) }
	if node.document().font_rendering_policy() != .chromium { return unsafe { nil } }
	computed := unsafe { &css.ComputedProperties(node.computed_values()) }
	properties := [css.PropertyID.border_top_color, .border_right_color, .border_bottom_color,
		.border_left_color]!
	sizes := [widths.top, widths.right, widths.bottom, widths.left]!
	side_colors := [colors.top, colors.right, colors.bottom, colors.left]!
	side_styles := [styles.top, styles.right, styles.bottom, styles.left]!
	mut chosen := unsafe { &PaintSRGBColor(nil) }
	mut fractional := false
	for index, size in sizes {
		if size <= 0 || side_styles[index] in [.none, .hidden] { continue }
		if side_styles[index] != .solid || side_colors[index].a != 255 { return unsafe { nil } }
		value := computed.typed_property_value(properties[index]) or { return unsafe { nil } }
		components := value.srgb_paint_components() or { return unsafe { nil } }
		if components[3] != 1 { return unsafe { nil } }
		serialized := side_colors[index].serialize()
		if chosen != unsafe { nil } {
			if chosen.components != components || chosen.serialized != serialized {
				return unsafe { nil }
			}
		} else {
			chosen = &PaintSRGBColor{serialized, components}
		}
		bytes := [side_colors[index].r, side_colors[index].g, side_colors[index].b]!
		for channel in 0 .. 3 {
			fractional = fractional || math.abs(components[channel] * 255 - f64(bytes[channel])) > 1e-6
		}
	}
	return if fractional { chosen } else { unsafe { nil } }
}

fn retain_chromium_border_color(mut commands []PaintCommand, start int, handle voidptr,
	widths BoxEdges, colors BoxColors, styles BoxBorderStyles, radii BoxRadii) {
	if start >= commands.len { return }
	color := chromium_border_srgb_color(handle, widths, colors, styles)
	if color == unsafe { nil } { return }
	for index in start .. commands.len {
		command := commands[index]
		if command.color != color.serialized { continue }
		if command.kind == 'draw_svg_path' && box_radii_are_zero(radii) {
			// A single square side is exactly a rectangle. Keep its float color
			// on the rectangle player instead of quantizing a generic SVG path.
			sizes := [widths.top, widths.right, widths.bottom, widths.left]!
			if sizes.filter(it > 0).len != 1 { continue }
			mut x := command.x
			mut y := command.y
			mut width := command.width
			mut height := command.height
			if widths.top > 0 { height = math.round(widths.top) }
			if widths.right > 0 {
				width = math.round(widths.right)
				x += command.width - width
			}
			if widths.bottom > 0 {
				height = math.round(widths.bottom)
				y += command.height - height
			}
			if widths.left > 0 { width = math.round(widths.left) }
			commands[index] = PaintCommand{
				...command
				kind:             'fill_rect'
				x:                x
				y:                y
				width:            width
				height:           height
				svg_data:         unsafe { nil }
				srgb_color_data:  color
				antialiased_rect: true
			}
		} else if command.kind == 'paint_uniform_border'
			|| rounded_single_border_mode(command.kind) != 0 || command.kind in [
			'fill_rect',
			'fill_rounded_rect',
		] {
			commands[index].srgb_color_data = color
		}
	}
}
