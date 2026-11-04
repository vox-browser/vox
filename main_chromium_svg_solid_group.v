module main

import layout
import painting
import math

// Keep coverage between adjacent solid SVG paths, including translucent
// strokes such as the native textarea grip, until their shared MSAA resolve.
// The surrounding command stream retains ownership of masks and effects.
fn chromium_svg_solid_path_supported(command &layout.PaintCommand) bool {
	return chromium_svg_solid_path_supported_with_clips(command,false)
}

// Whole compositor recordings retain each native rounded clip. Scalar SVG
// batches carry only their intersected rectangular viewport.
fn chromium_svg_compositor_path_supported(command &layout.PaintCommand) bool {
	return chromium_shared_recording_clips_supported(command)
		&& chromium_svg_solid_path_supported_with_clips(command,true)
}

fn chromium_svg_solid_path_supported_with_clips(command &layout.PaintCommand,
	rounded_clips bool) bool {
	return chromium_svg_simple_path_supported(command, rounded_clips, false)
}

// A complete picture uses Skia's stroked-path bounds. It can retain round
// caps, curves and joins which the compact scalar batch cannot enclose.
fn chromium_svg_picture_path_supported(command &layout.PaintCommand) bool {
	return chromium_svg_simple_path_supported(command, false, true)
}

fn chromium_svg_simple_path_supported(command &layout.PaintCommand,
	rounded_clips bool, allow_curved_strokes bool) bool {
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
	if has_stroke && data.non_scaling_stroke { return false }
	if has_stroke && !allow_curved_strokes {
		// The scalar bounds below enclose transformed butt-ended line
		// segments. Curves, joins and non-scaling strokes keep their existing
		// replay path, which computes the complete stroked outline bounds.
		if data.stroke_linecap != 0 { return false }
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
				|| (!rounded_clips && clip.corner_radii != layout.BoxRadii{})
				|| matrix[1] != 0 || matrix[2] != 0 {
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
	alpha := if first.color == '' {
		first.svg_data.stroke_opacity
	} else {
		first.svg_data.fill_opacity
	}
	return if end - start >= 2 || alpha != 1
		|| first.retained_svg_solid_alpha(first.color == '') != none {
		end
	} else {
		start
	}
}

fn chromium_svg_solid_paint_alpha(command &layout.PaintCommand, stroke bool, byte_alpha u8) f64 {
	return command.retained_svg_solid_alpha(stroke) or { f64(byte_alpha) / 255 }
}

fn (mut app BrowserApp) draw_chromium_svg_solid_group(commands []layout.PaintCommand,
	layers []int, start int, page_x f32, page_y f32) int {
	end := chromium_svg_solid_run_end(commands, layers, start)
	return app.draw_chromium_svg_solid_run(commands, start, end, page_x, page_y, 1)
}

// One paint can carry the scope's opacity without quantizing an intermediate image.
fn chromium_svg_folded_opacity(commands []layout.PaintCommand, layers []int, start int) ?f64 {
	end := chromium_svg_opacity_group_end(commands, start)
	if end == start || (layers.len != 0 && (layers.len != commands.len
		|| layers[start] != layers[start + 1] || layers[start] != layers[start + 2])) {
		return none
	}
	inner := &commands[start + 1]
	opening := &commands[start]
	if f32(inner.opacity) != f32(inner.group_opacity)
		|| !chromium_shared_recording_clips_supported(opening) {
		return none
	}
	matrix := multiply_paint_transforms(inner.transform, inner.svg_data.path_transform)
	if matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1 {
		return none
	}
	if opening.clip_outs.len != 0 || opening.recording_clip != none { return none }
	if opening.clip_list != unsafe { nil } {
		for clip in opening.clip_list.items {
			clip_matrix := normalized_paint_transform(clip.transform)
			if clip.corner_radii != layout.BoxRadii{} || clip_matrix[1] != 0 || clip_matrix[2] != 0 {
				return none
			}
		}
	}
	// Preserve the opening scope's ancestor bounds as well as the path clip.
	if opening.has_clip && (!inner.has_clip || opening.clip_x > inner.clip_x
		|| opening.clip_y > inner.clip_y || opening.clip_x + opening.clip_width < inner.clip_x + inner.clip_width
		|| opening.clip_y + opening.clip_height < inner.clip_y + inner.clip_height) {
		return none
	}
	return opening.visual_layer().opacity
}

fn (mut app BrowserApp) draw_chromium_svg_opacity_group(commands []layout.PaintCommand,
	layers []int, start int, page_x f32, page_y f32) int {
	opacity := chromium_svg_folded_opacity(commands, layers, start) or { return start }
	drawn := app.draw_chromium_svg_solid_run(commands, start + 1, start + 2,
		page_x, page_y, opacity)
	return if drawn == start + 2 { start + 3 } else { start }
}

fn chromium_svg_solid_run_viewport(commands []layout.PaintCommand, start int,
	end int) ?layout.LayoutRect {
	if start < 0 || end <= start || end > commands.len { return none }
	mut left := math.inf(1)
	mut top := math.inf(1)
	mut right := math.inf(-1)
	mut bottom := math.inf(-1)
	for index in start .. end {
		bounds := chromium_msaa_trigger_rect(&commands[index]) or { return none }
		left = math.min(left, bounds.x)
		top = math.min(top, bounds.y)
		right = math.max(right, bounds.x + bounds.width)
		bottom = math.max(bottom, bounds.y + bounds.height)
	}
	// The native batch uses a non-antialiased viewport clip. Enclose its
	// safety bounds in whole pixels so a downscaled SVG keeps edge samples.
	left = math.floor(left)
	top = math.floor(top)
	right = math.ceil(right)
	bottom = math.ceil(bottom)
	first := &commands[start]
	if first.has_clip {
		left = math.max(left, first.clip_x)
		top = math.max(top, first.clip_y)
		right = math.min(right, first.clip_x + first.clip_width)
		bottom = math.min(bottom, first.clip_y + first.clip_height)
	}
	if right <= left || bottom <= top { return layout.LayoutRect{} }
	return layout.LayoutRect{left, top, right - left, bottom - top}
}

fn (mut app BrowserApp) draw_chromium_svg_solid_run(commands []layout.PaintCommand,
	start int, end int, page_x f32, page_y f32, opacity f64) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return start
		}
		if end == start { return start }
		viewport := chromium_svg_solid_run_viewport(commands, start, end) or { return start }
		if viewport.width <= 0 || viewport.height <= 0 { return end }
		mut paths := []C.VoxGraphitePath{cap: end - start}
		for index in start .. end {
			command := &commands[index]
			data := command.svg_data
			matrix := multiply_paint_transforms(command.transform, data.path_transform)
			stroke := command.color == ''
			color := if stroke {
				app.paint_colors.color_with_retained(command.stroke_color, 1,
					command.retained_svg_stroke_color())
			} else {
				app.paint_colors.color_with_retained(command.color, 1,
					command.retained_svg_fill_color())
			}
			precise := command.retained_svg_solid_components(stroke)
			components := precise or {
				[f64(color.r) / 255, f64(color.g) / 255, f64(color.b) / 255, f64(color.a) / 255]!
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
				has_float_color:    int(precise != none)
				float_color:        [f32(components[0]), f32(components[1]), f32(components[2]),
					f32(components[3])]!
				opacity:            f32(chromium_svg_solid_paint_alpha(command, stroke, color.a) * if stroke {
					data.stroke_opacity
				} else {
					data.fill_opacity
				} * opacity)
			}
		}
		app.flush_rounded_rect_underlay(page_x, page_y, int(app.ctx.height))
		identity := [f32(1), 0, 0, 1, 0, 0]!
		if C.native_draw_svg_path_batch(paths.data, paths.len, &identity[0], f32(viewport.x),
			f32(viewport.y), f32(viewport.width), f32(viewport.height), page_x, page_y, 0,
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
		end = app.draw_chromium_svg_opacity_group(mapped, [], index, page_x, page_y)
		if end > index { continue }
		end = app.draw_chromium_svg_solid_group(mapped, [], index, page_x, page_y)
		if end > index { continue }
		app.draw_command(command, page_x, page_y, window_height)
	}
}

// Leaf replay uses the same retained solid paint as batched SVG recordings.
fn chromium_svg_precise_paint(command &layout.PaintCommand, stroke bool, opacity f64) ?[4]f32 {
	components := command.retained_svg_solid_components(stroke) or { return none }
	return [f32(components[0]), f32(components[1]), f32(components[2]), f32(components[3] * opacity)]!
}
