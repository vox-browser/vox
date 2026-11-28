module main

import ggshape
import layout
import math
import platform
import os

fn C.native_draw_svg_drop_shadow(&C.VoxGraphiteSvgShadow, f32, f32, f32, f32) i32

fn svg_drop_shadow_group_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start + 2 >= commands.len || layers.len != commands.len
		|| layers[start] != 0 || layers[start + 1] != 0 || layers[start + 2] != 0
		|| commands[start + 2].kind != 'end_css_filter_layer'
		|| !chromium_svg_filter_recording_supported(commands, start) {
		return start
	}
	for i in start .. start + 3 {
		c := &commands[i]
		if (i != start + 1 && (c.has_clip || c.clip_list != unsafe { nil })) || c.recording_clip != none
			|| c.clip_outs.len != 0 {
			return start
		}
	}
	c := &commands[start + 1]
	if c.svg_data.fill_opacity != 1 || c.disable_antialias { return start }
	return start + 3
}

// Clips introduced inside this filter may bound its source. They must contain
// the SVG viewport; ancestor clips stay on the ordinary filter path.
fn svg_drop_shadow_source_clips_supported(c &layout.PaintCommand,
	geometry layout.CssSvgFilterGeometry) bool {
	if !c.has_clip { return c.clip_list == unsafe { nil } }
	if c.clip_list == unsafe { nil } || c.clip_list.items.len == 0 { return false }
	m := normalized_paint_transform(c.transform)
	mut left, mut top := math.inf(1), math.inf(1)
	mut right, mut bottom := math.inf(-1), math.inf(-1)
	for i in 0 .. 4 {
		x := geometry.origin_x + geometry.bounds.x + if i & 1 != 0 {
			geometry.bounds.width
		} else {
			0
		}
		y := geometry.origin_y + geometry.bounds.y + if i & 2 != 0 {
			geometry.bounds.height
		} else {
			0
		}
		dx, dy := m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]
		left, top = math.min(left, dx), math.min(top, dy)
		right, bottom = math.max(right, dx), math.max(bottom, dy)
	}
	for clip in c.clip_list.items {
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask || clip.path_components.len != 0
			|| clip.corner_radii != layout.BoxRadii{} || clip.rect.width <= 0 || clip.rect.height <= 0 {
			return false
		}
		t := normalized_paint_transform(clip.transform)
		if t.any(!math.is_finite(it)) || !((math.abs(t[1]) < 1e-12 && math.abs(t[2]) < 1e-12)
			|| (math.abs(t[0]) < 1e-12 && math.abs(t[3]) < 1e-12)) {
			return false
		}
		mut cl, mut ct := math.inf(1), math.inf(1)
		mut cr, mut cb := math.inf(-1), math.inf(-1)
		for i in 0 .. 4 {
			x := clip.rect.x + if i & 1 != 0 { clip.rect.width } else { 0 }
			y := clip.rect.y + if i & 2 != 0 { clip.rect.height } else { 0 }
			dx, dy := t[0] * x + t[2] * y + t[4], t[1] * x + t[3] * y + t[5]
			cl, ct = math.min(cl, dx), math.min(ct, dy)
			cr, cb = math.max(cr, dx), math.max(cb, dy)
		}
		if cl > left || ct > top || cr < right || cb < bottom { return false }
	}
	return true
}

fn (mut app BrowserApp) draw_svg_drop_shadow(start int, page_y f32) int {
	if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
		|| app.document.font_rendering_policy() != .chromium || app.paint_effect_depth != 0
		|| C.native_document_raster_uses_p3() != 0 {
		return start
	}
	end := svg_drop_shadow_group_end(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if end == start { return start }
	c := &app.paint_commands[start + 1]
	color := app.paint_colors.color_with_retained(c.color, 1, c.retained_svg_fill_color())
	if color.r != 0 || color.g != 0 || color.b != 0 || color.a != 255 { return start }
	if precise := c.retained_svg_solid_components(false) {
		if precise != [f64(0), 0, 0, 1]! { return start }
	}
	owner := &app.paint_commands[start]
	geometry := layout.css_svg_filter_geometry(app.document, owner.visual_layer().scope_id) or { return start }
	if !svg_drop_shadow_source_clips_supported(c, geometry) { return start }
	m := normalized_paint_transform(owner.transform)
	if math.abs(m[0]) > 1e-12 || math.abs(m[3]) > 1e-12 || math.abs(m[1]) != 1 || m[2] != -m[1] {
		return start
	}
	filter := owner.visual_layer().filter or { return start }
	op := filter.operations[0]
	p := normalized_paint_transform(c.svg_data.path_transform)
	mut draw := C.VoxGraphiteSvgShadow{
		path:   C.VoxGraphitePath{
			matrix:        [f32(p[0]), f32(p[2]), f32(p[4] - geometry.origin_x), f32(p[1]), f32(p[3]),
				f32(p[5] - geometry.origin_y), 0, 0, 1]!
			segments:      c.svg_data.path_data.data
			segment_count: i32(c.svg_data.path_data.len / layout.compatibility_clip_path_segment_stride)
			even_odd:      i32(c.svg_data.fill_even_odd)
			alpha:         255
			opacity:       1
		}
		frame:  [f32(0), f32(m[2]), f32(m[4] + m[0] * geometry.origin_x + m[2] * geometry.origin_y),
			f32(m[1]), 0, page_y + f32(m[5] + m[1] * geometry.origin_x + m[3] * geometry.origin_y),
			0, 0, 1]!
		bounds: [f32(geometry.bounds.x), f32(geometry.bounds.y),
			f32(geometry.bounds.x + geometry.bounds.width),
			f32(geometry.bounds.y + geometry.bounds.height)]!
		shadow: [f32(m[1] * op.second), f32(m[2] * op.first), f32(op.third), f32(op.color.r) / 255,
			f32(op.color.g) / 255, f32(op.color.b) / 255, f32(op.color.a) / 255]!
	}
	if os.getenv('VOX_GG_DIAGNOSTICS') == '1' {
		eprintln('VOX_SVG_SHADOW source=${draw.path.matrix} frame=${draw.frame} bounds=${draw.bounds} shadow=${draw.shadow}')
	}
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	return if C.native_draw_svg_drop_shadow(&draw, f32(app.ctx.width), f32(app.ctx.height), 0, page_y) != 0 {
		end
	} else {
		start
	}
}

@[export: 'vox_draw_document_svg_shadow_pixels']
fn draw_document_svg_shadow_pixels(pixels &u8, width i32, height i32, pitch i32,
	first_x i32, first_y i32, draw &C.VoxGraphiteSvgShadow) i32 {
	work := platform.begin_thread_scratch('native SVG filter')
	defer { work.finish() }
	mut grid := document_geometry_grid
	x0, y0 := int(first_x), int(first_y)
	// Filter output may extend below the root picture's content bounds. Keep
	// the same tile phase for that transparent input fringe as for the picture.
	if grid.height > 2 && grid.clips_negative_origin {
		grid = DocumentGeometryGrid{ ...grid, rows: math.max(grid.rows, int(math.ceil(f64(y0 + height - 2) / f64(grid.height - 2)))) }
	}
	if os.getenv('VOX_GG_DIAGNOSTICS') == '1' {
		eprintln('VOX_SVG_SHADOW target=${width}x${height} first=${x0},${y0} grid=${grid.width}x${grid.height}/${grid.columns}x${grid.rows} origin=${grid.origin_x},${grid.origin_y} root=${grid.clips_negative_origin}')
	}
	if grid.origin_x != 0 || grid.origin_y != 0 || !grid.clips_negative_origin
		|| !geometry_grid_covers_leaf(grid, x0, y0, width, height) {
		return 0
	}
	swap_document_raster_channels(pixels, width, height, pitch)
	defer { swap_document_raster_channels(pixels, width, height, pitch) }
	mut result := []u8{len: int(height) * int(pitch)}
	unsafe { vmemcpy(result.data, pixels, result.len) }
	mut tile := []u8{len: grid.width * grid.height * 4}
	for row in geometry_tile_owner(y0, grid.height, grid.rows) .. geometry_tile_owner(y0 + height - 1, grid.height, grid.rows) + 1 {
		oy := row * (grid.height - 2)
		for col in geometry_tile_owner(x0, grid.width, grid.columns) .. geometry_tile_owner(x0 + width - 1, grid.width, grid.columns) + 1 {
			ox := col * (grid.width - 2)
			for i in 0 .. tile.len { tile[i] = 0 }
			left, top := math.max(x0, ox), math.max(y0, oy)
			right, bottom := math.min(x0 + width, ox + grid.width), math.min(y0 + height, oy + grid.height)
			for y in top .. bottom {
				unsafe { vmemcpy(&tile[((y - oy) * grid.width + left - ox) * 4], pixels + (y - y0) * int(pitch) + (left - x0) * 4, (right - left) * 4) }
			}
			mut local := *draw
			local.frame[2] += f32(x0 - ox)
			local.frame[5] += f32(y0 - oy)
			samples := if i32(row * grid.columns + col) in grid.cells { 4 } else { 1 }
			if ggshape.draw_svg_shadow(tile.data, grid.width, grid.height, grid.width * 4, samples, &local) == 0 {
				return 0
			}
			pl, pt := math.max(x0, ox + if col > 0 { 1 } else { 0 }), math.max(y0, oy + if row > 0 {
				1
			} else {
				0
			})
			pr, pb := math.min(x0 + width, ox + grid.width - if col + 1 < grid.columns {
				1
			} else {
				0
			}), math.min(y0 + height, oy + grid.height - if row + 1 < grid.rows { 1 } else { 0 })
			for y in pt .. pb {
				unsafe { vmemcpy(&result[(y - y0) * int(pitch) + (pl - x0) * 4], &tile[((y - oy) * grid.width + pl - ox) * 4], (pr - pl) * 4) }
			}
		}
	}
	unsafe { vmemcpy(pixels, result.data, result.len) }
	return 1
}
