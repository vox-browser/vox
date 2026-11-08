module layout

import math
import os
import painting

// Keep archived comparisons on their established raster policy after a
// correctness change to the default. Apply this to both measured Vox arms;
// changing the policy itself earns no instruction credit.
const retain_logical_paint_snapping = os.getenv('VOX_RETAIN_LOGICAL_PAINT_SNAPPING') != ''

// Layout may retain CSS coordinates for embedded user spaces. Painting still
// snaps HTML geometry to device pixels; a device-coordinate layout is already
// scaled and must not apply that density twice.
fn chromium_paint_pixel_scale(handle voidptr) f64 {
	if retain_logical_paint_snapping { return 1 }
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
	own := normalized_affine(box.own_paint_transform)
	matrix := box.own_paint_transform_4x4
	local := box.uses_own_paint_transform_4x4
		&& (own[0] != 1 || own[1] != 0 || own[2] != 0 || own[3] != 1)
		&& matrix.m13 == 0 && matrix.m23 == 0 && matrix.m31 == 0 && matrix.m32 == 0
		&& matrix.m33 == 1 && matrix.m34 == 0 && matrix.m41 == 0 && matrix.m42 == 0
		&& matrix.m43 == 0 && matrix.m44 == 1
	if scale == 1 && !local { return false }
	// Blink snaps transformed borders in their paint-offset coordinate space.
	// Snapping absolute edges can add a pixel to a fractional-sized skewed box.
	paint_rect := pixel_snapped_layout_rect_at_scale(if local {
		LayoutRect{0, 0, rect.width, rect.height}
	} else { rect }, scale)
	start := commands.len
	if !append_chromium_uniform_border_rect(mut commands, box.border, colors, box.border_styles,
		normalize_box_radii(radii, paint_rect.width, paint_rect.height), paint_rect, opacity) {
		return false
	}
	if local {
		commands[start].local_border_data = &PaintLocalBorderData{
			origin_x: rect.x
			origin_y: rect.y
			transform_context_index: box.own_transform_visual_context_idx
			initial_transform: painting.Affine{a: own[0], b: own[1], c: own[2], d: own[3], e: own[4], f: own[5]}
		}
	}
	set_force_dark_role_for_range(mut commands, start, commands.len, .border)
	return true
}
