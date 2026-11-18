module main

import layout
import math
import os

const disjoint_rounded_batch = os.getenv('VOX_DIAGNOSTIC_DISJOINT_ROUNDED_BATCH') == '1'
const trace_disjoint_rounded_batch = os.getenv('VOX_TRACE_DISJOINT_ROUNDED_BATCH') == '1'

// Commuting a leaf needs its ink bounds, rather than eligibility for the solid
// SVG batch renderer. A path may retain an inactive stroke or fractional color.
fn rounded_outer_gap_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	if command.kind == 'draw_text' { return rounded_outer_text_ink(command) }
	if command.kind != 'draw_svg_path' { return chromium_partial_gap_ink(command) }
	data := command.svg_data
	if data == unsafe { nil } || command.blur != 0 || command.outer_shadow
		|| data.fill_pattern != none || data.stroke_pattern != none
		|| data.svg_gradient_data != none || data.stroke_dasharray.len != 0
		|| data.non_scaling_stroke {
		return none
	}
	return layout.paint_svg_path_native_ink_bounds(command)
}

// Bold/varied faces deliberately retain face-wide layout bounds. Use the same
// supported retained A8 raster route to refine only this separation proof.
// Declines and clipped crops keep the original conservative enclosure.
fn rounded_outer_text_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	coarse := chromium_partial_gap_ink(command) or { return none }
	if command.blur != 0 || command.outer_shadow || command.opacity != 1
		|| command.group_opacity != 1 || command.glyph_orientation != .horizontal {
		return coarse
	}
	left, top := int(math.floor(coarse.x)) - 4, int(math.floor(coarse.y)) - 4
	width := int(math.ceil(coarse.x + coarse.width)) + 4 - left
	height := int(math.ceil(coarse.y + coarse.height)) + 4 - top
	if width <= 0 || height <= 0 || width > 2048 || height > 256 { return coarse }
	geometry := [i32(left), i32(top), i32(width), i32(height), i32(0), i32(width), i32(height)]!
	mask := elliptical_text_coverage(command, geometry, 0) or {
		if trace_disjoint_rounded_batch {
			eprintln('VOX_DISJOINT_ROUNDED_TEXT raster=declined coarse=${coarse}')
		}
		return coarse
	}
	ink := rounded_outer_mask_ink(mask.pixels, width, height, left, top) or {
		if trace_disjoint_rounded_batch {
			eprintln('VOX_DISJOINT_ROUNDED_TEXT raster=unbounded coarse=${coarse}')
		}
		return coarse
	}
	if trace_disjoint_rounded_batch {
		eprintln('VOX_DISJOINT_ROUNDED_TEXT coarse=${coarse} ink=${ink}')
	}
	return ink
}

fn rounded_outer_mask_ink(mask []u8, width int, height int, left int, top int) ?layout.LayoutRect {
	if width <= 0 || height <= 0 || width > 2048 || height > 256 || mask.len != width * height {
		return none
	}
	mut x0, mut y0, mut x1, mut y1 := width, height, -1, -1
	for y in 0 .. height {
		for x in 0 .. width {
			if mask[y * width + x] == 0 { continue }
			if x == 0 || y == 0 || x == width - 1 || y == height - 1 { return none }
			x0 = math.min(x0, x)
			y0 = math.min(y0, y)
			x1 = math.max(x1, x)
			y1 = math.max(y1, y)
		}
	}
	if x1 < x0 || y1 < y0 { return none }
	return layout.LayoutRect{f64(left + x0), f64(top + y0), f64(x1 - x0 + 1), f64(y1 - y0 + 1)}
}

// Bound the same padded caster that the native group bridge rasterizes.
fn rounded_outer_batch_ink(commands []layout.PaintCommand, start int, end int) ?layout.LayoutRect {
	mut bounds := layout.LayoutRect{}
	for i in start .. end {
		c := &commands[i]
		if chromium_contoured_box_supported(c) { return none }
		pad := if c.kind == 'paint_outer_box_shadow' { c.blur * 1.5 } else { c.stroke_width }
		proxy := layout.PaintCommand{
			...*c
			kind:         'fill_rect'
			blur:         0
			outer_shadow: false
			x:            c.x - pad
			y:            c.y - pad
			width:        c.width + pad * 2
			height:       c.height + pad * 2
		}
		ink := layout.paint_leaf_native_ink_bounds(&proxy) or { return none }
		if ink.width <= 0 || ink.height <= 0 || c.group_opacity != 1 { return none }
		bounds = if i == start { ink } else { chromium_compositor_ink_union(bounds, ink) }
	}
	return bounds
}

// Later decorations may move before crossed leaves only when their complete
// ink is disjoint. Resource/effect boundaries and foreign raster owners stop
// the scan. Retain every gap at its original replay position.
fn rounded_outer_batch_indices(commands []layout.PaintCommand, layers []int, start int) []int {
	first_end := rounded_outer_group_end_with_underlay(commands, layers, start, true)
	if first_end == start { return []int{} }
	first := &commands[start]
	transform := normalized_paint_transform(first.transform)
	initial := rounded_outer_batch_ink(commands, start, first_end) or { return []int{} }
	mut groups := [initial]
	mut gaps := []layout.LayoutRect{}
	mut indices := []int{len: first_end - start, init: start + index}
	mut scan := first_end
	for scan < math.min(commands.len, start + 128) {
		if layers[scan] < 0 {
			scan++
			continue
		}
		if layers[scan] != 0 { break }
		end := rounded_outer_group_end_with_underlay(commands, layers, scan, true)
		if end > scan {
			if indices.len + end - scan > 32
				|| normalized_paint_transform(commands[scan].transform) != transform
				|| commands[scan].fixed_to_viewport != first.fixed_to_viewport {
				if trace_disjoint_rounded_batch {
					eprintln('VOX_DISJOINT_ROUNDED_REASON start=${start} scan=${scan} state count=${indices.len} transform=${transform}/${normalized_paint_transform(commands[scan].transform)} fixed=${first.fixed_to_viewport}/${commands[scan].fixed_to_viewport}')
				}
				break
			}
			ink := rounded_outer_batch_ink(commands, scan, end) or {
				if trace_disjoint_rounded_batch {
					eprintln('VOX_DISJOINT_ROUNDED_REASON start=${start} scan=${scan} unbounded')
				}
				break
			}
			if gaps.any(chromium_compositor_ink_overlaps(it, ink))
				|| groups.any(chromium_compositor_ink_overlaps(it, ink)) {
				if trace_disjoint_rounded_batch {
					eprintln('VOX_DISJOINT_ROUNDED_REASON start=${start} scan=${scan} overlap ink=${ink} groups=${groups} gaps=${gaps}')
				}
				break
			}
			for i in scan .. end { indices << i }
			groups << ink
			scan = end
			continue
		}
		c := &commands[scan]
		if c.kind !in ['draw_text', 'draw_svg_path', 'fill_rect', 'fill_rounded_rect',
			'paint_uniform_border', 'paint_partial_rounded_border', 'stroke_rounded_rect'] || c.visual_layer_data != none
			|| c.fixed_to_viewport != first.fixed_to_viewport {
			break
		}
		ink := rounded_outer_gap_ink(c) or { break }
		gaps << ink
		scan++
	}
	if trace_disjoint_rounded_batch {
		kind := if scan < commands.len { commands[scan].kind } else { 'end' }
		eprintln('VOX_DISJOINT_ROUNDED_SCAN start=${start} first_end=${first_end} stop=${scan} kind=${kind} groups=${groups.len}')
	}
	return if groups.len > 1 { indices } else { []int{} }
}

fn (mut app BrowserApp) draw_disjoint_rounded_batch(start int, page_y f32) []int {
	if !disjoint_rounded_batch || !app.ctx.native_rendering || app.page_zoom != 1
		|| app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| C.native_raster_device_pixel_ratio() != 1 {
		return []int{}
	}
	indices := rounded_outer_batch_indices(app.paint_commands, app.chromium_raster_plan.command_layers, start)
	if trace_disjoint_rounded_batch && indices.len == 0 {
		eprintln('VOX_DISJOINT_ROUNDED_CLASSIFY start=${start} first_end=${rounded_outer_group_end_with_underlay(app.paint_commands, app.chromium_raster_plan.command_layers, start, true)}')
		for i in start .. math.min(start + 8, app.paint_commands.len) {
			c := &app.paint_commands[i]
			eprintln('VOX_DISJOINT_ROUNDED_BARRIER start=${start} i=${i} kind=${c.kind} owner=${app.chromium_raster_plan.command_layers[i]} underlay=${c.underlays_next} clip=${c.has_clip}/${c.clip_list != unsafe { nil }} box=${c.shares_paint_box_with(&app.paint_commands[start])} rect=${c.x},${c.y},${c.width},${c.height} radius=${c.radius} alpha=${c.opacity}/${c.group_opacity} stroke=${c.stroke_width} blur=${c.blur} aa_off=${c.disable_antialias} shadow=${c.outer_shadow}/${c.box_shadow_data != unsafe { nil }} contoured=${chromium_contoured_box_supported(c)} radii=${c.corner_radii}')
		}
	}
	if indices.len == 0 { return indices }
	shapes := app.rounded_outer_shapes(indices) or { return []int{} }
	m := normalized_paint_transform(app.paint_commands[start].transform)
	matrix := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), page_y + f32(m[5])]!
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	if C.native_draw_document_shape_group(shapes.data, i32(shapes.len), &matrix[0],
		f32(app.ctx.width), f32(app.ctx.height), 0, page_y, 0) == 0 {
		return []int{}
	}
	eprintln('VOX_DISJOINT_ROUNDED_BATCH start=${start} indices=${indices}')
	return indices
}
