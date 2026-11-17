module main

import cpuraster
import ggshape
import layout
import math
import os

const chromium_text_shadow_diagnostic = os.getenv('VOX_DIAGNOSTIC_TEXT_SHADOW') == '1'

fn (mut app BrowserApp) draw_chromium_text_shadow(command &layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f64) bool {
	if !app.ctx.native_rendering || app.document == unsafe { nil }
		|| app.document.font_rendering_policy() != .chromium
		|| app.document.rendering_device_pixel_ratio() != 1 || command.glyph_orientation != .horizontal
		|| command.blur < 0 || command.blur > 3 {
		return false
	}
	m := normalized_paint_transform(command.transform)
	if m[0] != 1 || m[1] != 0 || m[2] != 0 || m[3] != 1 { return false }
	color := chromium_retained_paint_color(*command) or { return false }
	if color[0] != 0 || color[1] != 0 || color[2] != 0 { return false }
	glyph := command.glyph_run or { return false }
	if glyph.face() == .emoji || glyph.glyph_indices().len == 0 || glyph.glyph_indices().len > 64 {
		return false
	}
	smoothing := native_retained_font_smoothing(command.font_smoothing, glyph.font())
	font_path := native_replay_font_path(glyph.font())
	if (smoothing & 128 == 0 && glyph.font().weight >= 600) || smoothing & 64 != 0 {
		style := document_glyph_face_style(font_path, glyph.font().face_index())
		if style & 4 == 0 || (smoothing & 128 == 0 && glyph.font().weight >= 600 && style & 1 == 0)
			|| (smoothing & 64 != 0 && style & 2 == 0) {
			return false
		}
	}
	positions := glyph.glyph_positions()
	run := cpuraster.CanvasGlyphRun{
		font_path:         font_path
		face_index:        glyph.font().face_index()
		font_size:         glyph.font().point_size
		glyphs:            glyph.glyph_indices()
		positions:         []f32{len: positions.len, init: f32(positions[index]) + if index % 2 == 0 {
			f32(command.glyph_translation_x)
		} else {
			f32(command.glyph_translation_y)
		}}
		baseline_snap:     true
		smoothing:         smoothing & 15
		retained:          true
		chromium_coverage: true
		linear_coverage:   command.blur > 0
	}
	mut cache := document_glyph_cache()
	bounds := cpuraster.canvas_glyph_run_bounds(mut cache, run) or { return false }
	tx, ty := page_x + f32(m[4]), page_y - f32(scroll_y) + f32(m[5])
	pad := f32(math.ceil(command.blur * 1.5)) + 1
	left, top := f32(math.floor(f64(bounds[0] + tx))) - pad, f32(math.floor(f64(bounds[1] + ty))) - pad
	right, bottom := f32(math.ceil(f64(bounds[2] + tx))) + pad, f32(math.ceil(f64(bounds[3] + ty))) + pad
	if !math.is_finite(left) || !math.is_finite(top) || !math.is_finite(right) || !math.is_finite(bottom) {
		return false
	}
	w, h := int(right - left), int(bottom - top)
	if w <= 0 || h <= 0 || w > 4096 || h > 4096 || w * h * run.glyphs.len > 4 * 1024 * 1024 {
		return false
	}
	mut geometry := [7]i32{}
	mut scale := f32(1)
	prepared := C.native_document_text_raster_begin(left, top, right, bottom, f32(app.ctx.width),
		f32(app.ctx.height), i32(smoothing), &geometry[0], &scale)
	if prepared == 2 { return true }
	if prepared != 1 || scale != 1 || geometry[4] == 0 { return false }
	width, height := int(geometry[2]), int(geometry[3])
	backdrop := geometry[4] != 0
	mut pixels := []u8{len: width * height * 4}
	if backdrop && C.native_document_text_raster_read_backdrop(pixels.data, geometry[0], geometry[1],
		geometry[2], geometry[3], scale) == 0 {
		return false
	}
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], i32(width * 4))
	// A mask filter belongs to each cached glyph, not the merged text blob.
	// Blend each tinted halo before the next one, preserving their overlap.
	for index, id in run.glyphs {
		single := cpuraster.CanvasGlyphRun{ ...run, glyphs: [id], positions: run.positions[index * 2..index * 2 + 2] }
		mut source := []u8{len: w * h * 4}
		if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut source, w, h, w * 4, 2, single,
			[f32(1), 0, 0, 1, tx - left, ty - top]!, 0xff000000, none, 1, .src_over, [], none) {
			return false
		}
		mask := []u8{len: w * h, init: source[index * 4 + 3]}
		if ggshape.draw_text_shadow_mask(pixels.data, geometry[2], geometry[3], i32(width * 4),
			1, mask, w, h, f32(geometry[0]) - left, f32(geometry[1]) - top, f32(command.blur), color) == 0 {
			return false
		}
	}
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], i32(width * 4))
	if chromium_text_shadow_diagnostic {
		eprintln('VOX_TEXT_SHADOW gpu=1 native_scale=${app.ctx.scale} rendering_scale=${scale} source=${w}x${h} target=${width}x${height}')
	}
	return C.native_document_text_raster_finish(pixels.data, geometry[0], geometry[1], geometry[2],
		geometry[3], geometry[5], geometry[6], f32(app.ctx.height), i32(backdrop)) != 0
}
