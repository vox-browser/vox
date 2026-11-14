module main

import layout
import math

// Filter input follows the recorded author clip beyond the visible window.
// The native readback is smaller, but must not change the raster tile's blur
// grid. Complex clips keep the existing conservative native boundary.
fn chromium_recorded_filter_clip(command &layout.PaintCommand) ?[4]f32 {
	mut bounds := [math.inf(-1), math.inf(-1), math.inf(1), math.inf(1)]!
	if command.clip_list != unsafe { nil } && command.clip_list.items.len > 0 {
		for clip in command.clip_list.items {
			m := normalized_paint_transform(clip.transform)
			if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
				|| clip.path_components.len > 0 || m[1] != 0 || m[2] != 0 {
				return none
			}
			for value in m { if !math.is_finite(value) { return none } }
			r := clip.rect
			for value in [r.x, r.y, r.width, r.height] {
				if !math.is_finite(value) { return none }
			}
			if r.width < 0 || r.height < 0 { return none }
			x0, x1 := r.x * m[0] + m[4], (r.x + r.width) * m[0] + m[4]
			y0, y1 := r.y * m[3] + m[5], (r.y + r.height) * m[3] + m[5]
			bounds[0] = math.max(bounds[0], math.min(x0, x1))
			bounds[1] = math.max(bounds[1], math.min(y0, y1))
			bounds[2] = math.min(bounds[2], math.max(x0, x1))
			bounds[3] = math.min(bounds[3], math.max(y0, y1))
		}
	} else if command.has_clip {
		if command.clip_width < 0 || command.clip_height < 0 { return none }
		bounds = [command.clip_x, command.clip_y, command.clip_x + command.clip_width,
			command.clip_y + command.clip_height]!
	} else {
		return none
	}
	mut result := [4]f32{}
	for i, value in bounds {
		if !math.is_finite(value) { return none }
		result[i] = f32(value)
		if !math.is_finite(result[i]) { return none }
	}
	return result
}
