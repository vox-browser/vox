module main

import layout
import math
import os

const document_gpu_rectangle_clip = os.getenv('VOX_DIAGNOSTIC_GPU_RECTANGLE_CLIP') == '1'
const document_gpu_thin_rectangle_clip = os.getenv('VOX_DIAGNOSTIC_GPU_THIN_RECTANGLE_CLIP') == '1'

fn C.native_set_shape_intersect_clip(&f32)

// A containing rectangular ancestor can be simplified by Graphite's clip
// stack. Reapplying it in Quartz after readback removes the shape's AA fringe.
fn chromium_rectangle_clip_index(command &layout.PaintCommand) int {
	return chromium_rectangle_clip_index_with_thin_rectangles(command, document_gpu_thin_rectangle_clip)
}

fn chromium_rectangle_clip_index_with_thin_rectangles(command &layout.PaintCommand,
	allow_thin bool) int {
	if command.kind != 'fill_rect' || command.disable_antialias
		|| command.radius != 0 || command.underlays_next || !command.has_clip
		|| command.clip_list == unsafe { nil } || command.recording_clip != none
		|| command.width <= 0 || command.height <= 0 { return -1 }
	matrix := normalized_paint_transform(command.transform)
	if matrix.any(!math.is_finite(it)) { return -1 }
	for value in [command.x, command.y, command.width, command.height,
		command.x + command.width, command.y + command.height] {
		if !math.is_finite(value) { return -1 }
	}
	if !command.antialiased_rect {
		// The plain native fill conditions a shared fractional clip edge for
		// Quartz. GPU replay must retain the original rectangle and its AA.
		if !allow_thin || matrix[0] <= 0 || matrix[0] != matrix[3]
			|| matrix[1] != 0 || matrix[2] != 0
			|| (command.width * matrix[0] > 4 && command.height * matrix[3] > 4) { return -1 }
		edges := [command.x * matrix[0] + matrix[4], command.y * matrix[3] + matrix[5],
			(command.x + command.width) * matrix[0] + matrix[4],
			(command.y + command.height) * matrix[3] + matrix[5]]
		if edges.any(!math.is_finite(it)) || edges.all(it == math.floor(it)) { return -1 }
	}
	for index := command.clip_list.items.len - 1; index >= 0; index-- {
		if chromium_rectangle_clip_contains(command, index) { return index }
	}
	return -1
}

fn chromium_rectangle_clip_contains(command &layout.PaintCommand, index int) bool {
	if command.clip_list == unsafe { nil } || index < 0 || index >= command.clip_list.items.len { return false }
	clip := command.clip_list.items[index]
	if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
		|| normalized_paint_transform(clip.transform) != normalized_paint_transform(command.transform) { return false }
	r := clip.corner_radii
	if [r.top_left.x, r.top_left.y, r.top_right.x, r.top_right.y,
		r.bottom_left.x, r.bottom_left.y, r.bottom_right.x, r.bottom_right.y].any(it != 0) { return false }
	c := clip.rect
	if [c.x, c.y, c.width, c.height, c.x + c.width, c.y + c.height].any(!math.is_finite(it))
		|| c.width <= 0 || c.height <= 0 { return false }
	return c.x <= command.x && c.y <= command.y
		&& c.x + c.width >= command.x + command.width
		&& c.y + c.height >= command.y + command.height
}

// Every containing rectangle belongs to the same GPU clip stack. Leaving an
// outer ancestor in Quartz can still remove the fringe after the GPU resolve.
fn chromium_rectangle_clip_bounds(command &layout.PaintCommand, selected int) [4]f32 {
	c := command.clip_list.items[selected].rect
	mut bounds := [c.x, c.y, c.x + c.width, c.y + c.height]!
	for index in 0 .. command.clip_list.items.len {
		if !chromium_rectangle_clip_contains(command, index) { continue }
		r := command.clip_list.items[index].rect
		bounds[0] = math.max(bounds[0], r.x)
		bounds[1] = math.max(bounds[1], r.y)
		bounds[2] = math.min(bounds[2], r.x + r.width)
		bounds[3] = math.min(bounds[3], r.y + r.height)
	}
	return [f32(bounds[0]), f32(bounds[1]), f32(bounds[2]), f32(bounds[3])]!
}

fn (app &BrowserApp) document_rectangle_clip_index(command &layout.PaintCommand) int {
	if !document_gpu_rectangle_clip || !app.ctx.native_rendering || app.page_zoom != 1
		|| app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| app.rounded_rect_underlay != none || document_geometry_grid.origin_x != 0
		|| document_geometry_grid.origin_y != 0 { return -1 }
	return chromium_rectangle_clip_index(command)
}
