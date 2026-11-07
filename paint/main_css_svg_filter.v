module main

import layout
import math

fn chromium_svg_filter_recording_supported(commands []layout.PaintCommand, start int) bool {
	if start < 0 || start >= commands.len || commands[start].kind != 'begin_css_filter_layer' {
		return false
	}
	filter := commands[start].visual_layer().filter or { return false }
	if filter.nodes.len != 0 || filter.operations.len != 1 || filter.operations[0].kind != 'drop-shadow' {
		return false
	}
	matrix := normalized_paint_transform(commands[start].transform)
	for value in matrix { if math.is_nan(value) || math.is_inf(value, 0) { return false } }
	x := matrix[0] * matrix[0] + matrix[1] * matrix[1]
	y := matrix[2] * matrix[2] + matrix[3] * matrix[3]
	if !(x > 0) || math.abs(x - y) > 1e-9 * math.max(x, y)
		|| math.abs(matrix[0] * matrix[2] + matrix[1] * matrix[3]) > 1e-9 * x {
		return false
	}
	mut paths := 0
	for index := start + 1; index < commands.len && index <= start + 256; index++ {
		command := unsafe { &commands[index] }
		if command.kind == 'end_css_filter_layer' { return paths > 0 }
		if command.kind != 'draw_svg_path' || command.svg_data == unsafe { nil }
			|| command.opacity != 1 || command.group_opacity != 1 || command.color == ''
			|| command.stroke_color != '' || command.clip_outs.len != 0
			|| normalized_paint_transform(command.transform) != matrix
			|| !chromium_shared_recording_clips_supported(command) {
			return false
		}
		data := command.svg_data
		if data.path_data.len == 0 || data.fill_pattern != none || data.stroke_pattern != none
			|| data.svg_gradient_data != none {
			return false
		}
		paths++
	}
	return false
}

fn (mut app BrowserApp) record_native_svg_css_filter(command &layout.PaintCommand, page_x f32, page_y f32) {
	$if macos {
		scope := command.visual_layer().scope_id
		if app.document == unsafe { nil } || !layout.css_filter_scope_is_svg_viewport(app.document, scope) {
			return
		}
		for index, candidate in app.paint_commands {
			if candidate.kind != 'begin_css_filter_layer' || candidate.visual_layer().scope_id != scope {
				continue
			}
			if !chromium_svg_filter_recording_supported(app.paint_commands, index) { return }
			matrix := normalized_paint_transform(command.transform)
			geometry := layout.css_svg_filter_geometry(app.document, scope) or { return }
			e := matrix[4] + matrix[0] * geometry.origin_x + matrix[2] * geometry.origin_y
			f := matrix[5] + matrix[1] * geometry.origin_x + matrix[3] * geometry.origin_y
			// Transfer SkScalar edges directly: rounding the width first can
			// change the far edge when the viewBox has fractional letterboxing.
			C.native_record_css_svg_filter_input(f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(e) + page_x, f32(f) + page_y, f32(geometry.bounds.x), f32(geometry.bounds.y), f32(geometry.bounds.x + geometry.bounds.width), f32(geometry.bounds.y + geometry.bounds.height), page_x, page_y)
			return
		}
	}
}
