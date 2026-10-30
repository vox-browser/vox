module main

import layout
import math
import os

// Consecutive outer shadows and the border of one transparent box share
// coverage in Chromium's raster pass. Preserve that order in one picture.
fn chromium_outer_decoration_end(commands []layout.PaintCommand, layers []int, index int) int {
	if index < 0 || index >= commands.len || layers.len != commands.len
		|| layers[index] != 0 || commands[index].kind != 'paint_outer_box_shadow' {
		return index
	}
	mut end := index
	for end < commands.len && end < index + 8
		&& commands[end].kind == 'paint_outer_box_shadow' { end++ }
	if end >= commands.len || commands[end].kind != 'paint_uniform_border' { return index }
	first := unsafe { &commands[index] }
	matrix := normalized_paint_transform(first.transform)
	for value in matrix {
		if math.is_nan(value) || math.is_inf(value, 0) { return index }
	}
	for i in index .. end + 1 {
		command := unsafe { &commands[i] }
		if layers[i] != 0 || !command.shares_paint_box_with(first)
			|| command.opacity != 1 || command.outer_shadow || command.clip_outs.len > 0
			|| normalized_paint_transform(command.transform) != matrix
			|| !chromium_shared_recording_clips_supported(command)
			|| command.width <= 0 || command.height <= 0 { return index }
		for value in [command.x, command.y, command.width, command.height, command.blur] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		if command.blur < 0 || (i < end && command.box_shadow_data == unsafe { nil }) {
			return index
		}
	}
	return end + 1
}

// Adjacent boxes can overlap in the same multisampled root tile. Keep their
// shadow/border pairs in one pass too, so an intermediate resolve does not
// round the first box's edge before the next shadow blends over it.
fn chromium_outer_decoration_run_end(commands []layout.PaintCommand, layers []int, index int) int {
	return chromium_outer_decoration_visible_run_end(commands, layers, index,
		PaintCanvasCulling{}, 0, 0, 0)
}

fn chromium_outer_decoration_gap_is_culled(command &layout.PaintCommand,
	mut culling PaintCanvasCulling, page_y f64, width f64, height f64) bool {
	if culling.skip(command, 0, page_y, width, height) { return true }
	if !culling.enabled || culling.resource_depth != 0
		|| command.kind !in ['fill_rect', 'fill_rounded_rect', 'paint_uniform_border',
			'stroke_rounded_rect', 'draw_svg_path', 'draw_text']
		|| command.outer_shadow || command.blur != 0 { return false }
	// draw_command also rejects these ordinary leaves at the document's exact
	// vertical edges. Its limit excludes the status bar; the canvas cull has a
	// wider precision fringe and can therefore retain an already rejected leaf.
	points := transformed_rect_points(*command, 0, f32(page_y), 0)
	mut top := points[1]
	mut bottom := top
	for i := 1; i < points.len; i += 2 {
		if math.is_nan(points[i]) || math.is_inf(points[i], 0) { return false }
		top = math.min(top, points[i])
		bottom = math.max(bottom, points[i])
	}
	return bottom < f32(page_y) || top > f32(height)
}

fn chromium_outer_decoration_visible_run_end(commands []layout.PaintCommand, layers []int, index int,
	culling PaintCanvasCulling, page_y f64, width f64, height f64) int {
	mut end := chromium_outer_decoration_end(commands, layers, index)
	if end == index { return index }
	mut scan := end
	mut painted := end - index
	mut probe := culling
	// Paint phases can place offscreen siblings between two visible boxes.
	// Only skip what ordinary replay would cull, including complete clipped
	// effect groups. Resource inputs and visible state boundaries stop the run.
	for scan < commands.len && scan - index < 4096 && painted < 32 {
		if chromium_outer_decoration_gap_is_culled(unsafe { &commands[scan] }, mut probe,
			page_y, width, height) {
			scan++
			continue
		}
		next := chromium_outer_decoration_end(commands, layers, scan)
		if next == scan || painted + next - scan > 32 {
			if os.getenv('VOX_TRACE_OUTER_DECORATIONS') != '' {
				barrier := unsafe { &commands[scan] }
				eprintln('Outer decorations ${index}..${end}: barrier ${scan} ${barrier.kind}, layer=${layers[scan]}, opacity=${barrier.opacity}, clip=${barrier.has_clip} (${barrier.clip_x},${barrier.clip_y},${barrier.clip_width},${barrier.clip_height})')
				for j in scan .. math.min(scan + 5, commands.len) {
					leaf := unsafe { &commands[j] }
					eprintln('  ${j} ${leaf.kind} (${leaf.x},${leaf.y},${leaf.width},${leaf.height}) image=${leaf.image_paintable != none} nested=${leaf.nested_viewport_paintable != none}')
				}
			}
			break
		}
		painted += next - scan
		end = next
		scan = next
	}
	return end
}

fn (mut app BrowserApp) draw_chromium_outer_decorations(index int, page_y f32, window_height int,
	mut culling PaintCanvasCulling) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.viewport_width <= 4 || app.viewport_height <= 4 { return index }
		end := chromium_outer_decoration_visible_run_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, index, culling,
			page_y, app.ctx.width, window_height - app.status_height())
		if end == index { return index }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		// The recording includes the document viewport and its complete raster
		// tiles. Including browser chrome would give the first row a negative
		// document coordinate and select the differently sized fallback target.
		// The native constructor adds two guard pixels around this rectangle.
		if C.native_begin_inset_decorations(2, page_y + 2,
			f32(app.viewport_width - 4), f32(app.viewport_height - 4),
			f32(app.ctx.width), f32(app.ctx.height), page_y, 0) == 0 { return index }
		for i in index .. end {
			if chromium_outer_decoration_gap_is_culled(unsafe { &app.paint_commands[i] }, mut culling,
				page_y, app.ctx.width, window_height - app.status_height()) {
				continue
			}
			app.draw_command(app.paint_commands[i], 0, page_y, window_height)
		}
		C.native_end_inset_decorations()
		return end
	}
	return index
}
