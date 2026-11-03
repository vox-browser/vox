module layout

import math

// Layout may retain CSS coordinates for embedded user spaces. Painting still
// snaps HTML geometry to device pixels; a device-coordinate layout is already
// scaled and must not apply that density twice.
fn chromium_paint_pixel_scale(handle voidptr) f64 {
	if handle == unsafe { nil } { return 1 }
	node := unsafe { &Node(handle) }
	document := node.document()
	if document.font_rendering_policy() != .chromium { return 1 }
	scale := document.display_device_pixel_ratio() / document.layout_coordinate_scale()
	return if scale > 0 && !math.is_inf(scale, 0) && !math.is_nan(scale) { scale } else { 1.0 }
}

fn pixel_snapped_layout_rect_at_scale(rect LayoutRect, scale f64) LayoutRect {
	left := math.floor(rect.x * scale + 0.5) / scale
	top := math.floor(rect.y * scale + 0.5) / scale
	return LayoutRect{left, top, non_negative(math.floor((rect.x + rect.width) * scale + 0.5) / scale - left), non_negative(math.floor((rect.y + rect.height) * scale + 0.5) / scale - top)}
}

fn append_chromium_device_uniform_border(mut commands []PaintCommand, box &BlockBox,
	colors BoxColors, radii BoxRadii, rect LayoutRect, opacity f64) bool {
	if !box.snaps_background_rect { return false }
	scale := chromium_paint_pixel_scale(box.layout_handle)
	if scale == 1 { return false }
	start := commands.len
	if !append_chromium_uniform_border_rect(mut commands, box.border, colors, box.border_styles,
		radii, pixel_snapped_layout_rect_at_scale(rect, scale), opacity) {
		return false
	}
	set_force_dark_role_for_range(mut commands, start, commands.len, .border)
	return true
}
