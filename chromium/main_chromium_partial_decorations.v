module main

import css
import layout
import math
import os

const partial_decoration_trace = os.getenv('VOX_PARTIAL_DECORATION_TRACE') != ''

// A child header can cover the same rounded edge as its parent's background
// and partial border. Resolve these consecutive decorations in one pass so
// the border's multisample coverage survives until the header is drawn.
fn chromium_partial_decoration_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index + 2 >= commands.len || layers.len != commands.len { return index }
	background := unsafe { &commands[index] }
	border := unsafe { &commands[index + 1] }
	header := unsafe { &commands[index + 2] }
	if background.kind != 'fill_rounded_rect' || border.kind != 'paint_partial_rounded_border'
		|| header.kind != 'fill_rounded_rect' || border.points.len != 4
		|| !background.shares_paint_box_with(border) { return index }
	matrix := normalized_paint_transform(background.transform)
	owner := layers[index]
	if owner < 0 { return index }
	for i in index .. index + 3 {
		command := unsafe { &commands[i] }
		if layers[i] != owner || command.opacity != 1 || command.outer_shadow || command.blur != 0
			|| command.underlays_next || command.clip_outs.len > 0
			|| normalized_paint_transform(command.transform) != matrix
			|| !chromium_shared_recording_clips_supported(command) { return index }
		for value in [command.x, command.y, command.width, command.height] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		if command.width <= 0 || command.height <= 0 { return index }
		color := css.parse_color_string(command.color) or { return index }
		if color.a != 255 { return index }
	}
	for value in matrix {
		if math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	for value in border.points {
		if value < 0 || math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	top, right, bottom, left := border.points[0] / 2, border.points[1] / 2,
		border.points[2] / 2, border.points[3] / 2
	if [background.x, background.y, background.width, background.height] !=
		[border.x + left, border.y + top, border.width - left - right, border.height - top - bottom]
		|| [header.x, header.y, header.width] != [border.x, border.y, border.width]
		|| header.height > border.height { return index }
	outer := border.corner_radii
	back := background.corner_radii
	for i, radius in [outer.top_left, outer.top_right, outer.bottom_right, outer.bottom_left] {
		expected := layout.CornerRadius{
			x: math.max(0.0, radius.x - if i in [0, 3] { left } else { right })
			y: math.max(0.0, radius.y - if i < 2 { top } else { bottom })
		}
		if expected != [back.top_left, back.top_right, back.bottom_right, back.bottom_left][i] { return index }
	}
	if header.corner_radii.top_left != outer.top_left || header.corner_radii.top_right != outer.top_right
		|| header.corner_radii.bottom_left != layout.CornerRadius{}
		|| header.corner_radii.bottom_right != layout.CornerRadius{} { return index }
	return index + 3
}

// Moving a positioned header earlier is safe only if every crossed leaf has
// conservatively bounded ink outside the header. Effects and unknown bounds
// keep ordinary paint order. Foreign raster layers then keep their own replay.
fn chromium_partial_gap_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	if command.kind.starts_with('begin_') || command.kind.starts_with('end_')
		|| command.blur != 0 || command.outer_shadow { return none }
	if command.kind == 'draw_svg_path' {
		if !chromium_svg_compositor_path_supported(command) { return none }
		// Square CSS border paths have bounded ink even though they do not
		// trigger MSAA. Paint coverage, rather than tile eligibility, decides
		// whether a later header may cross this leaf.
		return layout.paint_svg_path_native_ink_bounds(command)
	}
	if command.kind in ['paint_uniform_border', 'paint_partial_rounded_border'] {
		mut outset := math.max(command.stroke_width, 0.0)
		for value in command.points {
			if math.is_nan(value) || math.is_inf(value, 0) { return none }
			outset = math.max(outset, value)
		}
		proxy := layout.PaintCommand{...*command, kind:'fill_rect',
			x:command.x-outset, y:command.y-outset,
			width:command.width+outset*2, height:command.height+outset*2}
		return layout.paint_leaf_native_ink_bounds(&proxy)
	}
	return layout.paint_leaf_native_ink_bounds(command)
}

fn chromium_disjoint_partial_header_index(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index+2 >= commands.len || layers.len != commands.len
		|| layers[index] < 0 || layers[index+1] != layers[index]
		|| commands[index].kind != 'fill_rounded_rect'
		|| commands[index+1].kind != 'paint_partial_rounded_border' { return -1 }
	owner := layers[index]
	for scan in index+2 .. math.min(commands.len,index+256) {
		if layers[scan] != owner || commands[scan].kind != 'fill_rounded_rect' { continue }
		triple := [commands[index],commands[index+1],commands[scan]]
		if chromium_partial_decoration_end(triple,[owner,owner,owner],0) != 3 { continue }
		header := layout.paint_leaf_native_ink_bounds(&commands[scan]) or { return -1 }
		mut disjoint := true
		for gap in index+2 .. scan {
			if layers[gap] < 0 { continue }
			ink := chromium_partial_gap_ink(&commands[gap]) or {
				if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE unknown gap=${gap} kind=${commands[gap].kind}') }
				disjoint = false
				break
			}
			// Account for native antialiasing and tile-border ownership on both leaves.
			if ink.x < header.x+header.width+4 && ink.x+ink.width > header.x-4
				&& ink.y < header.y+header.height+4 && ink.y+ink.height > header.y-4 {
				if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE overlapping gap=${gap} header=${scan}') }
				disjoint = false
				break
			}
		}
		if disjoint {
			if partial_decoration_trace { eprintln('VOX_PARTIAL_DECORATION_TRACE early header=${scan} start=${index} owner=${owner}') }
			return scan
		}
	}
	return -1
}

fn (mut app BrowserApp) draw_chromium_disjoint_partial_header(index int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.viewport_width <= 4 || app.viewport_height <= 4 { return -1 }
		header := chromium_disjoint_partial_header_index(app.paint_commands,
			app.chromium_raster_plan.command_layers,index)
		if header <= index+2 { return -1 }
		// A GPU leaf resolves its coverage separately. This decoration group
		// needs the shared recording and its current backdrop instead.
		C.native_gpu_canvas_cpu_access()
		app.flush_rounded_rect_underlay(0,page_y,window_height)
		grouped := C.native_begin_deferred_inset_decorations(2,page_y+2,
			f32(app.viewport_width-4),f32(app.viewport_height-4),
			f32(app.ctx.width),f32(app.ctx.height),page_y,f32(app.scroll_y)) != 0
		// An existing parent/compositor picture can retain these draws itself.
		// Otherwise the same disjoint reordering remains a valid leaf fallback.
		for i in [index,index+1,header] { app.draw_command(app.paint_commands[i],0,page_y,window_height) }
		app.flush_rounded_rect_underlay(0,page_y,window_height)
		// A failed deferred transaction restores its prefix. Let the main loop
		// replay the original order, including the header at its original index.
		if grouped && C.native_end_deferred_inset_decorations() == 0 { return -1 }
		return header
	}
	return -1
}
