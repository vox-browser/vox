module layout

// Blink snaps the border box, then preserves the shadow's floating-point
// offset, blur, spread and corner radii. Keep the portable integer path for
// ordinary logical-grid painting and for inset shadows.
fn paintable_box_paint_box_shadow_for_node(mut commands []PaintCommand, shadows []BoxShadow,
	border BoxEdges, colors BoxColors, styles BoxBorderStyles, radii BoxRadii,
	border_rect LayoutRect, padding_rect LayoutRect, opacity f64, handle voidptr) {
	if shadows.len == 0 { return }
	scale := chromium_paint_pixel_scale(handle)
	if scale == 1 || handle == unsafe { nil } {
		paintable_box_paint_box_shadow(mut commands, shadows, border, colors, styles,
			radii, border_rect, padding_rect, opacity)
		return
	}
	document := unsafe { &Node(handle) }.document()
	if document.font_rendering_policy() != .chromium || document.display_device_pixel_ratio() == 1 {
		paintable_box_paint_box_shadow(mut commands, shadows, border, colors, styles,
			radii, border_rect, padding_rect, opacity)
		return
	}
	base := pixel_snapped_layout_rect_at_scale(border_rect, scale)
	for index := shadows.len - 1; index >= 0; index-- {
		shadow := shadows[index]
		if shadow.inset {
			paintable_box_paint_box_shadow(mut commands, [shadow], border, colors, styles,
				radii, border_rect, padding_rect, opacity)
			continue
		}
		spread := shadow.spread
		rect := LayoutRect{base.x + shadow.offset_x - spread, base.y + shadow.offset_y - spread, base.width + 2 * spread, base.height + 2 * spread}
		if rect.width <= 0 || rect.height <= 0 { continue }
		commands << PaintCommand{
			kind:                'paint_outer_box_shadow'
			x:                   rect.x
			y:                   rect.y
			width:               rect.width
			height:              rect.height
			blur:                shadow.blur
			color:               shadow.color.serialize()
			srgb_color_data:     shadow.srgb_color_data
			opacity:             opacity
			force_dark_role:     .background
			force_dark_role_set: true
			corner_radii:        chromium_shadow_spread_radii(radii, spread, rect)
			box_shadow_data:     &PaintBoxShadowData{
				content_rect:  base
				content_radii: radii
				clip_radii:    radii
			}
		}
	}
}

fn chromium_shadow_spread_radii(radii BoxRadii, spread f64, rect LayoutRect) BoxRadii {
	return effective_box_radii(BoxRadii{
		top_left:     chromium_shadow_spread_corner(radii.top_left, spread)
		top_right:    chromium_shadow_spread_corner(radii.top_right, spread)
		bottom_right: chromium_shadow_spread_corner(radii.bottom_right, spread)
		bottom_left:  chromium_shadow_spread_corner(radii.bottom_left, spread)
	}, 0, rect.width, rect.height)
}

fn chromium_shadow_spread_corner(radius CornerRadius, spread f64) CornerRadius {
	return CornerRadius{chromium_shadow_spread_radius(radius.x, spread), chromium_shadow_spread_radius(radius.y, spread)}
}

fn chromium_shadow_spread_radius(radius f64, spread f64) f64 {
	if radius == 0 { return 0 }
	if spread > 0 && radius < spread {
		ratio := radius / spread - 1
		return radius + spread * (1 + ratio * ratio * ratio)
	}
	return non_negative(radius + spread)
}
