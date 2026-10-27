module main

import layout
import math

// A sprite tile can be much larger than its embedding background clip. Cull
// only against that clip, retaining effect inputs whose pixels can move into
// view during later filter/group composition.
fn background_image_clip_intersects_viewport(command &layout.PaintCommand, page_x f64,
	page_y f64, viewport_width f64, viewport_top f64, viewport_bottom f64,
	in_effect_group bool) bool {
	if in_effect_group || command.visual_layer_list != unsafe { nil } {
		return true
	}
	image_data := command.image()
	if image_data.image_clip_width <= 0 || image_data.image_clip_height <= 0 {
		return false
	}
	mut matrix := command.transform
	if matrix == [6]f64{} {
		matrix = [f64(1), 0, 0, 1, 0, 0]!
	}
	left := image_data.image_clip_x
	top := image_data.image_clip_y
	right := left + image_data.image_clip_width
	bottom := top + image_data.image_clip_height
	xs := [left, right, right, left]!
	ys := [top, top, bottom, bottom]!
	mut minimum_x := math.inf(1)
	mut minimum_y := math.inf(1)
	mut maximum_x := math.inf(-1)
	mut maximum_y := math.inf(-1)
	for index in 0 .. 4 {
		x := matrix[0] * xs[index] + matrix[2] * ys[index] + matrix[4] + page_x
		y := matrix[1] * xs[index] + matrix[3] * ys[index] + matrix[5] + page_y
		if !math.is_finite(x) || !math.is_finite(y) {
			return true
		}
		minimum_x = math.min(minimum_x, x)
		minimum_y = math.min(minimum_y, y)
		maximum_x = math.max(maximum_x, x)
		maximum_y = math.max(maximum_y, y)
	}
	// Preserve a conservative antialiasing fringe at the viewport boundary.
	return maximum_x >= -2 && minimum_x <= viewport_width + 2
		&& maximum_y >= viewport_top - 2 && minimum_y <= viewport_bottom + 2
}

fn background_clip_effect_depth_after_command(depth int, kind string) int {
	return match kind {
		'begin_skia_command_group', 'begin_css_filter_layer', 'begin_svg_mask_layer' { depth + 1 }
		'end_skia_command_group', 'end_css_filter_layer', 'end_svg_mask_layer' {
			if depth > 0 { depth - 1 } else { 0 }
		}
		else { depth }
	}
}

fn background_svg_mask_depth_after_command(depth int, kind string) int {
	return match kind {
		'begin_svg_mask_layer' { depth + 1 }
		'end_svg_mask_layer' { if depth > 0 { depth - 1 } else { 0 } }
		else { depth }
	}
}

fn rounded_svg_background_effects_supported(effect_depth int, mask_depth int) bool {
	return effect_depth == 0 || (effect_depth == 1 && mask_depth == 1)
}
