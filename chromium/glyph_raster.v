module main

import cpuraster
import os
import platform

// Retained document text through cpuraster's glyph masks: the port of Skia's
// CoreText A8 strikes, subpixel placement, mask gamma and legacy blitters that
// canvas text already uses. The removed Skia bridge drew each run into a
// device raster covering its bounds, blending opaque text over a copy of the
// page pixels it covers (Blink's raster does the same), and Quartz then placed
// that raster. This reproduces it so document text keeps Chromium's pixels.

fn C.native_text_raster_begin(left f32, top f32, right f32, bottom f32, canvas_width f32, canvas_height f32, font_smoothing i32, geometry &i32, scale &f32) i32
fn C.native_text_raster_read_backdrop(pixels &u8, left i32, top i32, width i32, height i32, scale f32) i32
fn C.native_text_raster_finish(pixels &u8, left i32, top i32, width i32, height i32, logical_width i32, logical_height i32, canvas_height f32, backdrop i32) i32

// The cache keeps typeface facts and glyph masks across frames. Its retained
// allocations go to their own arena, reset (with the cache) once it has grown
// past a budget, because frame scratch is reset every frame and prealloc never
// reuses memory a cache evicts.
struct DocumentGlyphRaster {
mut:
	arena   &platform.Arena       = unsafe { nil }
	cache   &cpuraster.GlyphCache = unsafe { nil }
	entries [4]platform.ArenaEntry
	depth   int
	styles  map[string]int
}

__global document_glyph_raster = DocumentGlyphRaster{}

const document_glyph_arena_budget = i64(48 * 1024 * 1024)

fn document_glyph_cache_enter() {
	mut state := unsafe { &document_glyph_raster }
	entry := state.arena.enter()
	if state.depth < state.entries.len {
		state.entries[state.depth] = entry
	}
	state.depth++
}

fn document_glyph_cache_leave() {
	mut state := unsafe { &document_glyph_raster }
	state.depth--
	if state.depth < state.entries.len {
		state.arena.leave(state.entries[state.depth])
	}
}

fn document_glyph_cache() &cpuraster.GlyphCache {
	mut state := unsafe { &document_glyph_raster }
	if state.arena == unsafe { nil } {
		persistent := platform.enter_persistent()
		state.arena = platform.new_arena('document glyph raster cache')
		platform.leave_persistent(persistent)
	}
	if state.cache != unsafe { nil } && state.arena.usage().used > document_glyph_arena_budget {
		state.cache = unsafe { nil }
		state.arena.reset()
	}
	if state.cache == unsafe { nil } {
		document_glyph_cache_enter()
		state.cache = cpuraster.new_scoped_glyph_cache(document_glyph_cache_enter,
			document_glyph_cache_leave)
		document_glyph_cache_leave()
	}
	return state.cache
}

// Whether the run's face is itself bold and italic: 1 bold, 2 italic, 4 known.
fn document_glyph_face_style(path string, face_index int) int {
	key := '${path}#${face_index}'
	mut state := unsafe { &document_glyph_raster }
	if style := state.styles[key] {
		return style
	}
	mut style := 0
	if bold, italic := cpuraster.glyph_face_style(path, face_index) {
		style = 4 | int(bold) | (int(italic) << 1)
	}
	persistent := platform.enter_persistent()
	state.styles[key.clone()] = style
	platform.leave_persistent(persistent)
	return style
}

fn f32_finite(value f32) bool {
	return value == value && value - value == 0
}

// draw_document_glyph_raster draws a horizontal retained glyph run with
// cpuraster. It returns false, drawing nothing, for runs it does not cover:
// Skia's synthetic bold and slant, unopenable faces and declined draws.
// VOX_TEXT_RASTER_DUMP=DIR records each run's inputs and fallbacks there.
fn draw_document_glyph_raster(glyphs []u16, positions []f64, font_path string, face_index int,
	font_size f32, font_weight int, baseline_x f32, baseline_y f32, matrix [6]f32,
	page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32,
	color u32, font_smoothing int, paint_color ?[4]f32) bool {
	reason := draw_document_glyph_raster_run(glyphs, positions, font_path, face_index, font_size,
		font_weight, baseline_x, baseline_y, matrix, page_x, page_y, scroll_y, canvas_width,
		canvas_height, color, font_smoothing, paint_color)
	if reason != '' && document_glyph_raster_dump != '' {
		eprintln('VOX_TEXT_RASTER fallback=${reason} font=${font_path}#${face_index} size=${font_size} weight=${font_weight} smoothing=${font_smoothing}')
	}
	return reason == ''
}

__global document_glyph_raster_dump = os.getenv('VOX_TEXT_RASTER_DUMP')
__global document_glyph_raster_records = 0

fn document_glyph_raster_record(run cpuraster.CanvasGlyphRun, transform [6]f32, geometry [7]i32,
	scale f32, color u32, font_smoothing int, pixels []u8, backdrop bool) {
	index := document_glyph_raster_records
	document_glyph_raster_records++
	os.mkdir_all(document_glyph_raster_dump) or {}
	if backdrop {
		os.write_file_array(os.join_path(document_glyph_raster_dump, '${index}.rgba'), pixels) or {}
	}
	line := '{"index":${index},"font":"${run.font_path}","face":${run.face_index},"size":${run.font_size},' +
		'"glyphs":${run.glyphs},"positions":${run.positions},"translation":${run.translation[..]},' +
		'"transform":${transform[..]},"geometry":${geometry[..]},"scale":${scale},"color":${color},' +
		'"smoothing":${font_smoothing},"backdrop":${backdrop}}\n'
	mut file := os.open_append(os.join_path(document_glyph_raster_dump, 'runs.jsonl')) or { return }
	file.write_string(line) or {}
	file.close()
}

fn draw_document_glyph_raster_run(glyphs []u16, positions []f64, font_path string, face_index int,
	font_size f32, font_weight int, baseline_x f32, baseline_y f32, matrix [6]f32,
	page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32,
	color u32, font_smoothing int, paint_color ?[4]f32) string {
	$if macos {
		if glyphs.len == 0 || positions.len < glyphs.len * 2 || font_path == '' || !(font_size >= 0) {
			return 'empty run'
		}
		chromium := font_smoothing & 16 != 0
		if chromium && ((font_smoothing & 128 == 0 && font_weight >= 600) || font_smoothing & 64 != 0) {
			style := document_glyph_face_style(font_path, face_index)
			if style & 4 == 0 {
				return 'unopenable face style'
			}
			// Skia emboldens a regular face and slants an upright one.
			if font_smoothing & 128 == 0 && font_weight >= 600 && style & 1 == 0 {
				return 'synthetic bold'
			}
			if font_smoothing & 64 != 0 && style & 2 == 0 {
				return 'synthetic slant'
			}
		}
		// Chromium runs keep the document origin in the glyph positions
		// (f32(position) + origin), so the float sums select the same subpixel
		// masks; other runs draw the blob at its baseline.
		mut glyph_positions := []f32{len: glyphs.len * 2}
		for i in 0 .. glyphs.len * 2 {
			glyph_positions[i] = if chromium {
				f32(positions[i]) + if i % 2 == 0 { baseline_x } else { baseline_y }
			} else {
				f32(positions[i])
			}
		}
		run := cpuraster.CanvasGlyphRun{
			font_path:         font_path
			face_index:        face_index
			font_size:         font_size
			glyphs:            glyphs
			positions:         glyph_positions
			translation:       if chromium { [f32(0), 0]! } else { [baseline_x, baseline_y]! }
			baseline_snap:     true
			smoothing:         font_smoothing & 15
			retained:          true
			chromium_coverage: chromium
			paint_color:       paint_color
		}
		// The page matrix: CSS transform after the page offset and scroll.
		tx := page_x + matrix[4]
		ty := page_y - scroll_y + matrix[5]
		mut cache := document_glyph_cache()
		mut local := cpuraster.canvas_glyph_run_bounds(mut cache, run) or {
			// Faces without typeface bounds: the positions with an em of margin.
			mut b := [glyph_positions[0], glyph_positions[1], glyph_positions[0], glyph_positions[1]]!
			for i := 0; i + 1 < glyph_positions.len; i += 2 {
				if glyph_positions[i] < b[0] { b[0] = glyph_positions[i] }
				if glyph_positions[i + 1] < b[1] { b[1] = glyph_positions[i + 1] }
				if glyph_positions[i] > b[2] { b[2] = glyph_positions[i] }
				if glyph_positions[i + 1] > b[3] { b[3] = glyph_positions[i + 1] }
			}
			[b[0] - font_size * 2 + run.translation[0], b[1] - font_size * 2 + run.translation[1],
				b[2] + font_size * 3 + run.translation[0], b[3] + font_size * 2 + run.translation[1]]!
		}
		mut left := f32(0)
		mut top := f32(0)
		mut right := f32(0)
		mut bottom := f32(0)
		for corner in 0 .. 4 {
			x := if corner & 1 == 0 { local[0] } else { local[2] }
			y := if corner & 2 == 0 { local[1] } else { local[3] }
			dx := matrix[0] * x + matrix[2] * y + tx
			dy := matrix[1] * x + matrix[3] * y + ty
			if corner == 0 || dx < left { left = dx }
			if corner == 0 || dx > right { right = dx }
			if corner == 0 || dy < top { top = dy }
			if corner == 0 || dy > bottom { bottom = dy }
		}
		if !f32_finite(left) || !f32_finite(top) || !f32_finite(right) || !f32_finite(bottom) {
			return 'unbounded run'
		}
		mut geometry := [7]i32{}
		mut scale := f32(1)
		prepared := C.native_text_raster_begin(left, top, right, bottom, canvas_width, canvas_height,
			i32(font_smoothing), &geometry[0], &scale)
		if prepared == 2 {
			return ''
		}
		if prepared != 1 {
			return 'no raster destination'
		}
		width := int(geometry[2])
		height := int(geometry[3])
		backdrop := geometry[4] != 0
		mut pixels := []u8{len: width * height * 4}
		if backdrop && C.native_text_raster_read_backdrop(pixels.data, geometry[0], geometry[1],
			i32(width), i32(height), scale) == 0 {
			return 'backdrop unreadable'
		}
		scale_x := f32(width) / f32(geometry[5])
		scale_y := f32(height) / f32(geometry[6])
		transform := [matrix[0] * scale_x, matrix[1] * scale_y, matrix[2] * scale_x,
			matrix[3] * scale_y, (tx - f32(geometry[0])) * scale_x, (ty - f32(geometry[1])) * scale_y]!
		if document_glyph_raster_dump != '' {
			document_glyph_raster_record(run, transform, geometry, scale, color, font_smoothing, pixels,
				backdrop)
		}
		if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, width, height, width * 4, 2, run,
			transform, color, none, 1, .src_over, [], none) {
			return 'cpuraster declined'
		}
		if C.native_text_raster_finish(pixels.data, geometry[0], geometry[1], i32(width), i32(height),
			geometry[5], geometry[6], canvas_height, i32(backdrop)) == 0 {
			return 'composite failed'
		}
		return ''
	}
	return 'unsupported platform'
}
