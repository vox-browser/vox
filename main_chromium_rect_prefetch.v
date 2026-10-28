module main

import layout

#include "native_graphite_bridge.h"

@[typedef]
struct C.VoxGraphiteShape {
	matrix          [9]f32
	rect            [12]f32
	thickness       f32
	red             u8
	green           u8
	blue            u8
	alpha           u8
	fill            int
	anti_alias      int
	force_msaa      int
	clip_outs       &f32
	clip_out_count  int
	has_underlay    int
	underlay_rect   [12]f32
	underlay_rgba   [4]u8
	has_float_color int
	float_color     [4]f32
	border_widths   [4]f32
}

fn C.native_prefetch_plain_rects(&C.VoxGraphiteShape, int, f32, f32, f32, f32)
fn C.native_plain_rect_prefetch_enabled() int

fn chromium_rect_prefetch_leaf(command &layout.PaintCommand) bool {
	return command.kind == 'fill_rect' && command.antialiased_rect
		&& !command.disable_antialias && !command.outer_shadow && !command.underlays_next
		&& command.scrollbar_axis == '' && command.radius == 0
		&& command.width > 0 && command.width <= 1024 && command.height > 0 && command.height <= 3
		&& command.opacity == 1 && command.group_opacity == 1 && command.clip_outs.len == 0
		&& command.recording_clip == none
}

// Look ahead only through text and simple rectangles in the same raster layer.
// Nothing is reordered or skipped: the cache rechecks each real background.
fn chromium_rect_prefetch_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || (layers.len != 0 && layers.len != commands.len)
		|| !chromium_rect_prefetch_leaf(&commands[start]) {
		return start
	}
	mut end := start
	mut count := 0
	for end < commands.len && end - start < 48 && count < 16 {
		command := &commands[end]
		if (layers.len != 0 && layers[end] != layers[start])
			|| command.opacity != 1 || command.group_opacity != 1
			|| (command.kind != 'draw_text' && !chromium_rect_prefetch_leaf(command)) {
			break
		}
		if command.kind == 'fill_rect' { count++ }
		end++
	}
	return if count >= 2 { end } else { start }
}

fn (mut app BrowserApp) prefetch_chromium_rects(start int, page_y f32) int {
	$if macos {
		if C.native_plain_rect_prefetch_enabled() == 0 || !app.ctx.native_rendering
			|| app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium || app.paint_effect_depth != 0
			|| app.rounded_rect_underlay != none || app.paint_commands[start].kind != 'fill_rect' {
			return start
		}
		end := chromium_rect_prefetch_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
		if end == start { return start }
		mut shapes := []C.VoxGraphiteShape{cap: 16}
		for index in start .. end {
			command := &app.paint_commands[index]
			if command.kind != 'fill_rect' { continue }
			matrix := normalized_paint_transform(command.transform)
			color := app.paint_colors.color(command.color, command.opacity)
			if color.a != 255 { return end }
			mut shape := C.VoxGraphiteShape{
				matrix:     [f32(matrix[0]), f32(matrix[2]), f32(matrix[4]), f32(matrix[1]),
					f32(matrix[3]), f32(matrix[5]), f32(0), f32(0), f32(1)]!
				rect:       [f32(command.x), f32(command.y), f32(command.width), f32(command.height),
					f32(0), f32(0), f32(0), f32(0), f32(0), f32(0), f32(0), f32(0)]!
				red:        color.r
				green:      color.g
				blue:       color.b
				alpha:      color.a
				fill:       1
				anti_alias: 1
			}
			data := command.srgb_color_data
			if data != unsafe { nil } && data.serialized == command.color {
				shape.has_float_color = 1
				shape.float_color = [f32(data.components[0]), f32(data.components[1]),
					f32(data.components[2]), f32(data.components[3])]!
			}
			shapes << shape
		}
		if C.native_rect_prefetch_scratch_enabled() != 0 {
			app.prefetch_chromium_rect_scratch(shapes, start, end, page_y)
		} else {
			C.native_prefetch_plain_rects(shapes.data, shapes.len, 0, page_y,
				f32(app.ctx.width), f32(app.ctx.height))
		}
		return end
	}
	return start
}
