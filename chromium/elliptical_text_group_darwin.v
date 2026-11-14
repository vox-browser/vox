module main

import layout
import cpuraster
import ggshape
import math
import os

// A bounded picture prefix with only supported geometry followed by glyphs.
// Culled commands have no drawing or resource state to preserve. Every visible
// leaf must keep the same owner and clip; effects and other resources stop it.
fn elliptical_text_group_indices(commands []layout.PaintCommand, layers []int, start int,
	viewport layout.LayoutRect) []int {
	end := elliptical_outer_group_end(commands, layers, start)
	if end == start { return []int{} }
	first := &commands[start]
	mut indices := []int{}
	mut text := false
	mut shapes := 0
	mut runs := 0
	for i in start .. math.min(start + 128, commands.len) {
		if layers[i] < 0 { continue }
		c := &commands[i]
		if chromium_compositor_leaf_is_culled(c, viewport) { continue }
		if clip := chromium_recorded_filter_clip(c) {
			if clip[2] <= viewport.x || clip[3] <= viewport.y || clip[0] >= viewport.x + viewport.width || clip[1] >= viewport.y + viewport.height {
				continue
			}
		}
		if layers[i] != layers[start] || voidptr(c.clip_list) != voidptr(first.clip_list)
			|| c.has_clip != first.has_clip || c.clip_x != first.clip_x || c.clip_y != first.clip_y
			|| c.clip_width != first.clip_width || c.clip_height != first.clip_height
			|| c.opacity != 1 || c.group_opacity != 1 || c.outer_shadow || c.disable_antialias
			|| c.recording_clip != none || c.clip_outs.len != 0 || c.scrollbar_axis != ''
			|| !chromium_shared_recording_clips_supported(c) || chromium_contoured_box_supported(c) {
			if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
				eprintln('ELLIPSE_TEXT_BLOCK start=${start} i=${i} kind=${c.kind} owner=${layers[i]} clip_same=${voidptr(c.clip_list) == voidptr(first.clip_list)} clip=${c.has_clip} compat=${c.clip_x},${c.clip_y},${c.clip_width},${c.clip_height} opacity=${c.opacity}/${c.group_opacity} props=${c.outer_shadow}/${c.disable_antialias}/${c.recording_clip != none}/${c.clip_outs.len}')
			}
			break
		}
		mut finite := true
		for v in [c.x, c.y, c.width, c.height, c.blur, c.stroke_width, c.font_size, c.radius] {
			finite = finite && !math.is_nan(v) && !math.is_inf(v, 0)
		}
		for v in normalized_paint_transform(c.transform) {
			finite = finite && !math.is_nan(v) && !math.is_inf(v, 0)
		}
		for radius in [c.corner_radii.top_left, c.corner_radii.top_right, c.corner_radii.bottom_right,
			c.corner_radii.bottom_left] {
			finite = finite && math.is_finite(radius.x) && math.is_finite(radius.y) && radius.x >= 0 && radius.y >= 0
		}
		if !finite || c.width <= 0 || c.height <= 0 || c.blur < 0 { break }
		if c.kind == 'draw_text' {
			glyph := c.glyph_run or { break }
			if c.blur != 0 || c.glyph_orientation != .horizontal || glyph.face() == .emoji
				|| glyph.glyph_indices().len == 0 || glyph.glyph_positions().len != glyph.glyph_indices().len * 2 {
				break
			}
			runs++
			if runs > 16 { break }
			text = true
		} else {
			if text || c.kind !in ['paint_outer_box_shadow', 'paint_uniform_border', 'fill_rect',
				'fill_rounded_rect']
				|| (c.kind != 'paint_outer_box_shadow' && c.blur != 0)
				|| (c.kind == 'paint_outer_box_shadow' && c.box_shadow_data == unsafe { nil })
				|| (c.kind == 'paint_uniform_border' && c.stroke_width <= 0) {
				break
			}
			shapes++
			if shapes > 32 { break }
		}
		indices << i
	}
	if !text { return []int{} }
	return indices
}

fn elliptical_text_coverage(command &layout.PaintCommand, geometry [7]i32, page_y f32) ?ggshape.GlyphCoverage {
	glyph := command.glyph_run or { return none }
	smoothing := native_retained_font_smoothing(command.font_smoothing, glyph.font())
	if smoothing & 16 == 0 { return none }
	font_path := native_replay_font_path(glyph.font())
	if (smoothing & 128 == 0 && glyph.font().weight >= 600) || smoothing & 64 != 0 {
		style := document_glyph_face_style(font_path, glyph.font().face_index())
		if style & 4 == 0 || (smoothing & 128 == 0 && glyph.font().weight >= 600 && style & 1 == 0)
			|| (smoothing & 64 != 0 && style & 2 == 0) {
			return none
		}
	}
	precise := chromium_retained_paint_color(*command)
	fill := paint_color(command.color, 1)
	color := precise or { [f32(fill.r) / 255, f32(fill.g) / 255, f32(fill.b) / 255, f32(fill.a) / 255]! }
	if color[3] != 1 { return none }
	packed := u32(fill.a) << 24 | u32(fill.r) << 16 | u32(fill.g) << 8 | u32(fill.b)
	positions := glyph.glyph_positions()
	indices := glyph.glyph_indices()
	m := normalized_paint_transform(command.transform)
	run := cpuraster.CanvasGlyphRun{
		font_path:         font_path
		face_index:        glyph.font().face_index()
		font_size:         glyph.font().point_size
		glyphs:            indices
		positions:         []f32{len: positions.len, init: f32(positions[index]) + if index % 2 == 0 {
			f32(command.glyph_translation_x)
		} else {
			f32(command.glyph_translation_y)
		}}
		baseline_snap:     true
		smoothing:         smoothing & 15
		retained:          true
		chromium_coverage: true
		// Require an A8 mask; color glyphs and outline routes retain ordinary replay.
		paint_color:       color
	}
	transform := [f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]) - f32(geometry[0]),
		page_y + f32(m[5]) - f32(geometry[1])]!
	mut pixels := []u8{len: int(geometry[2]) * int(geometry[3]) * 4}
	mut cache := document_glyph_cache()
	if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, int(geometry[2]), int(geometry[3]), int(geometry[2]) * 4, 2, run, transform, packed, none, 1, .src_over, [], none) {
		return none
	}
	return ggshape.GlyphCoverage{ pixels: []u8{len: pixels.len / 4, init: pixels[index * 4 + 3]}, color: color }
}

fn (mut app BrowserApp) draw_elliptical_text_group(start int, page_y f32) int {
	if !app.ctx.native_rendering || app.document == unsafe { nil } || app.page_zoom != 1
		|| app.document.font_rendering_policy() != .chromium || C.native_display_device_pixel_ratio() != 1 {
		return start
	}
	selected := elliptical_text_group_indices(app.paint_commands, app.chromium_raster_plan.command_layers, start, layout.LayoutRect{0, 0, f64(app.viewport_width), f64(app.viewport_height)})
	if selected.len == 0 { return start }
	if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
		eprintln('ELLIPSE_TEXT_SELECTED start=${start} selected=${selected}')
	}
	first := &app.paint_commands[start]
	// Keep the existing elliptical group's native publication clip.
	if first.clip_list == unsafe { nil } { return start }
	filter_clip := chromium_recorded_filter_clip(first) or { return start }
	app.flush_rounded_rect_underlay(0, page_y, app.ctx.height)
	C.native_begin_clip()
	defer { C.native_end_clip() }
	for clip in first.clip_list.items {
		m := normalized_paint_transform(clip.transform)
		C.native_add_corner_rounded_clip(f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width), f32(clip.rect.height), f32(clip.corner_radii.top_left.x), f32(clip.corner_radii.top_left.y), f32(clip.corner_radii.top_right.x), f32(clip.corner_radii.top_right.y), f32(clip.corner_radii.bottom_right.x), f32(clip.corner_radii.bottom_right.y), f32(clip.corner_radii.bottom_left.x), f32(clip.corner_radii.bottom_left.y), f32(m[0]), f32(m[1]), f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5]), 0, page_y, 0, f32(app.ctx.height))
	}
	mut geometry := [7]i32{}
	mut scale := f32(1)
	if C.native_text_raster_begin(0, page_y, f32(app.viewport_width), page_y + f32(app.viewport_height), f32(app.ctx.width), f32(app.ctx.height), 16, &geometry[0], &scale) != 1
		|| scale != 1 || geometry[2] != geometry[5] || geometry[3] != geometry[6] {
		return start
	}
	mut pixels := []u8{len: int(geometry[2]) * int(geometry[3]) * 4}
	if geometry[4] != 0 && C.native_text_raster_read_backdrop(pixels.data, geometry[0], geometry[1], geometry[2], geometry[3], scale) == 0 {
		return start
	}
	mut shapes := []C.VoxGraphiteShape{}
	mut masks := []ggshape.GlyphCoverage{}
	for i in selected {
		c := &app.paint_commands[i]
		if c.kind == 'draw_text' {
			mask := elliptical_text_coverage(c, geometry, page_y) or {
				if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
					eprintln('ELLIPSE_TEXT_MASK_DECLINE index=${i}')
				}
				return start
			}
			masks << mask
			continue
		}
		fill := app.paint_colors.color(c.color, 1)
		precise := chromium_retained_paint_color(*c)
		shadow := c.kind == 'paint_outer_box_shadow'
		m := normalized_paint_transform(c.transform)
		mut radii := c.corner_radii
		if c.kind == 'fill_rect' {
			r := layout.CornerRadius{c.radius, c.radius}
			radii = layout.BoxRadii{r, r, r, r}
		}
		mut shape := C.VoxGraphiteShape{
			matrix:          [f32(m[0]), f32(m[2]), f32(m[4]) - f32(geometry[0]), f32(m[1]), f32(m[3]),
				page_y + f32(m[5]) - f32(geometry[1]), 0, 0, 1]!
			rect:            document_shadow_rect(c.x, c.y, c.width, c.height, radii)
			fill:            if shadow {
				if c.blur > 0 { 10 } else { 9 }
			} else if c.kind == 'paint_uniform_border' {
				6
			} else {
				1
			}
			thickness:       f32(if shadow { c.blur } else { c.stroke_width })
			anti_alias:      1
			force_msaa:      1
			red:             fill.r
			green:           fill.g
			blue:            fill.b
			alpha:           fill.a
			has_float_color: i32(precise != none)
			float_color:     precise or { [f32(0), 0, 0, 0]! }
			border_widths:   [f32(c.stroke_width), f32(c.stroke_width), f32(c.stroke_width),
				f32(c.stroke_width)]!
		}
		if shadow {
			b := c.box_shadow()
			shape.underlay_rect = document_shadow_rect(b.content_rect.x, b.content_rect.y, b.content_rect.width, b.content_rect.height, b.content_radii)
		}
		if shape.fill == 10 {
			shape.has_filter_clip = 1
			shape.filter_clip = [f32(math.floor(filter_clip[0])) - f32(geometry[0]),
				f32(math.floor(filter_clip[1] + page_y)) - f32(geometry[1]),
				f32(math.ceil(filter_clip[2])) - f32(geometry[0]),
				f32(math.ceil(filter_clip[3] + page_y)) - f32(geometry[1])]!
		}
		shapes << shape
	}
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], geometry[2] * 4)
	if draw_document_shape_glyph_tiles(pixels.data, geometry[2], geometry[3], geometry[2] * 4, geometry[4], int(geometry[0]), int(math.round(f32(geometry[1]) - page_y)), shapes.data, i32(shapes.len), masks) == 0 {
		return start
	}
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], geometry[2] * 4)
	if C.native_text_raster_finish(pixels.data, geometry[0], geometry[1], geometry[2], geometry[3], geometry[5], geometry[6], f32(app.ctx.height), geometry[4]) == 0 {
		return start
	}
	if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
		eprintln('VOX_ELLIPSE_TEXT start=${start} end=${selected.last() + 1} shapes=${shapes.len} glyphs=${masks.len}')
	}
	return selected.last() + 1
}
