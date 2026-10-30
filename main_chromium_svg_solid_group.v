module main

import layout
import painting

$if macos {
	import math
}

// Keep coverage between adjacent solid SVG paths, including translucent
// strokes such as the native textarea grip, until their shared MSAA resolve.
// The surrounding command stream retains ownership of masks and effects.
fn chromium_svg_solid_path_supported(command &layout.PaintCommand) bool {
	has_fill := command.color != ''
	has_stroke := command.stroke_color != '' && command.stroke_width > 0
	if command.kind != 'draw_svg_path' || command.opacity != 1 || command.group_opacity != 1
		|| has_fill == has_stroke || command.svg_data == unsafe { nil }
		|| command.clip_outs.len != 0 || command.recording_clip != none {
		return false
	}
	data := command.svg_data
	if data.path_data.len < layout.compatibility_clip_path_segment_stride
		|| data.stroke_dasharray.len != 0 || data.fill_pattern != none
		|| data.stroke_pattern != none || data.svg_gradient_data != none {
		return false
	}
	if has_stroke {
		// The scalar bounds below enclose transformed butt-ended line
		// segments. Curves, joins and non-scaling strokes keep their existing
		// replay path, which computes the complete stroked outline bounds.
		if data.non_scaling_stroke || data.stroke_linecap != 0 { return false }
		mut at_start := false
		stride := layout.compatibility_clip_path_segment_stride
		for offset := 0; offset + stride <= data.path_data.len; offset += stride {
			kind := int(data.path_data[offset])
			if kind == 0 {
				at_start = true
			} else if kind == 1 && at_start {
				at_start = false
			} else {
				return false
			}
		}
	}
	if command.has_clip && command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			matrix := normalized_paint_transform(clip.transform)
			if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
				|| clip.corner_radii != layout.BoxRadii{} || matrix[1] != 0 || matrix[2] != 0 {
				return false
			}
		}
	}
	return true
}

fn chromium_svg_solid_run_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || (layers.len != 0 && layers.len != commands.len)
		|| !chromium_svg_solid_path_supported(&commands[start]) {
		return start
	}
	first := &commands[start]
	mut end := start + 1
	for end < commands.len && end - start < 32768 {
		next := &commands[end]
		// Axis-aligned rectangular clips are fully represented by the scalar
		// intersection, even when nested viewport mapping copied their lists.
		if (layers.len != 0 && layers[end] != layers[start])
			|| !chromium_svg_solid_path_supported(next) || next.has_clip != first.has_clip
			|| next.clip_x != first.clip_x || next.clip_y != first.clip_y
			|| next.clip_width != first.clip_width || next.clip_height != first.clip_height {
			break
		}
		end++
	}
	// The leaf SVG bridge rounds paint opacity into its byte alpha. Use the
	// recording's float alpha for a single translucent paint as well.
	alpha := if first.color == '' { first.svg_data.stroke_opacity } else { first.svg_data.fill_opacity }
	return if end - start >= 2 || alpha != 1 { end } else { start }
}

fn (mut app BrowserApp) draw_chromium_svg_solid_group(commands []layout.PaintCommand,
	layers []int, start int, page_x f32, page_y f32) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return start
		}
		end := chromium_svg_solid_run_end(commands, layers, start)
		if end == start { return start }
		mut paths := []C.VoxGraphitePath{cap: end - start}
		mut left := math.inf(1)
		mut top := math.inf(1)
		mut right := math.inf(-1)
		mut bottom := math.inf(-1)
		for index in start .. end {
			command := &commands[index]
			data := command.svg_data
			bounds := chromium_msaa_trigger_rect(*command) or { return start }
			left = math.min(left, bounds.x)
			top = math.min(top, bounds.y)
			right = math.max(right, bounds.x + bounds.width)
			bottom = math.max(bottom, bounds.y + bounds.height)
			matrix := multiply_paint_transforms(command.transform, data.path_transform)
			stroke := command.color == ''
			color := if stroke {
				app.paint_colors.color_with_retained(command.stroke_color, 1,
					command.retained_svg_stroke_color())
			} else {
				app.paint_colors.color_with_retained(command.color, 1,
					command.retained_svg_fill_color())
			}
			paths << C.VoxGraphitePath{
				matrix:             [f32(matrix[0]), f32(matrix[2]), f32(matrix[4]), f32(matrix[1]),
					f32(matrix[3]), f32(matrix[5]), f32(0), f32(0), f32(1)]!
				segments:           data.path_data.data
				segment_count:      data.path_data.len / layout.compatibility_clip_path_segment_stride
				even_odd:           int(data.fill_even_odd)
				red:                color.r
				green:              color.g
				blue:               color.b
				alpha:              color.a
				stroke:             int(stroke)
				line_cap:           data.stroke_linecap
				line_join:          data.stroke_linejoin
				non_scaling_stroke: int(data.non_scaling_stroke)
				stroke_width:       f32(command.stroke_width * if data.non_scaling_stroke {
					app.document.layout_coordinate_scale()
				} else {
					1.0
				})
				miter_limit:        f32(data.stroke_miterlimit)
				has_float_alpha:    1
				opacity:            f32(f64(color.a) / 255 * if stroke {
					data.stroke_opacity
				} else {
					data.fill_opacity
				})
			}
		}
		first := &commands[start]
		if first.has_clip {
			left = math.max(left, first.clip_x)
			top = math.max(top, first.clip_y)
			right = math.min(right, first.clip_x + first.clip_width)
			bottom = math.min(bottom, first.clip_y + first.clip_height)
		}
		if right <= left || bottom <= top { return end }
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		identity := [f32(1), 0, 0, 1, 0, 0]!
		if C.native_draw_svg_path_batch(paths.data, paths.len, &identity[0], f32(left),
			f32(top), f32(right - left), f32(bottom - top), page_x, page_y, 0,
			f32(app.ctx.width), f32(app.ctx.height), unsafe { nil }) != 0 {
			return end
		}
	}
	return start
}

fn (mut app BrowserApp) draw_nested_svg_commands(commands []layout.PaintCommand,
	transform [6]f64, origin painting.IntPoint, opacity f64, page_x f32, page_y f32,
	window_height int) {
	mapped := commands.map(layout.paint_command_for_nested_viewport(it, transform, origin, opacity))
	mut end := 0
	for index, command in mapped {
		if index < end { continue }
		end = app.draw_chromium_svg_rectangular_mask(mapped, [], index, page_x, page_y)
		if end > index { continue }
		end = app.draw_chromium_svg_solid_group(mapped, [], index, page_x, page_y)
		if end > index { continue }
		app.draw_command(command, page_x, page_y, window_height)
	}
}
