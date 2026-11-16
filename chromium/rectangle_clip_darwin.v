module main

import layout
import math
import os

const document_gpu_rectangle_clip = os.getenv('VOX_DIAGNOSTIC_GPU_RECTANGLE_CLIP') == '1'

fn C.native_set_shape_intersect_clip(&f32)

// A containing rectangular ancestor can be simplified by Graphite's clip
// stack. Reapplying it in Quartz after readback removes the shape's AA fringe.
fn chromium_rectangle_clip_index(command &layout.PaintCommand) int {
	if command.kind != 'fill_rect' || !command.antialiased_rect || command.disable_antialias
		|| command.radius != 0 || command.underlays_next || !command.has_clip
		|| command.clip_list == unsafe { nil } || command.recording_clip != none
		|| command.width <= 0 || command.height <= 0 { return -1 }
	matrix := normalized_paint_transform(command.transform)
	if matrix.any(!math.is_finite(it)) { return -1 }
	for value in [command.x, command.y, command.width, command.height,
		command.x + command.width, command.y + command.height] {
		if !math.is_finite(value) { return -1 }
	}
	for index := command.clip_list.items.len - 1; index >= 0; index-- {
		clip := command.clip_list.items[index]
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| normalized_paint_transform(clip.transform) != matrix { continue }
		r := clip.corner_radii
		if [r.top_left.x, r.top_left.y, r.top_right.x, r.top_right.y,
			r.bottom_left.x, r.bottom_left.y, r.bottom_right.x, r.bottom_right.y].any(it != 0) { continue }
		c := clip.rect
		if [c.x, c.y, c.width, c.height, c.x + c.width, c.y + c.height].any(!math.is_finite(it))
			|| c.width <= 0 || c.height <= 0 { continue }
		if c.x <= command.x && c.y <= command.y
			&& c.x + c.width >= command.x + command.width
			&& c.y + c.height >= command.y + command.height { return index }
	}
	return -1
}

fn (app &BrowserApp) document_rectangle_clip_index(command &layout.PaintCommand) int {
	if !document_gpu_rectangle_clip || !app.ctx.native_rendering || app.page_zoom != 1
		|| app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| app.rounded_rect_underlay != none || document_geometry_grid.origin_x != 0
		|| document_geometry_grid.origin_y != 0 { return -1 }
	return chromium_rectangle_clip_index(command)
}
