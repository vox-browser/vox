module main

import layout

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
fn C.native_document_text_raster_begin(f32, f32, f32, f32, f32, f32, i32, &i32, &f32) i32
fn C.native_document_text_raster_finish(&u8, i32, i32, i32, i32, i32, i32, f32, i32) i32
fn C.native_document_text_raster_read_backdrop(&u8, i32, i32, i32, i32, f32) i32

$if macos {
	#include "@VMODROOT/native/include/native_text_backdrop_darwin.h"
	fn C.native_document_start_text_backdrop_copy(&u8, i32, i32, i32, i32, f32) voidptr
	fn C.native_document_finish_text_backdrop_copy(voidptr)
}

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
	color u32, font_smoothing int, paint_color ?[4]f32, clip_bounds ?[4]f32,
	options RetainedGlyphGeometryOptions) bool {
	reason := draw_document_glyph_raster_run(glyphs, positions, font_path, face_index, font_size,
		font_weight, baseline_x, baseline_y, matrix, page_x, page_y, scroll_y, canvas_width,
		canvas_height, color, font_smoothing, paint_color, clip_bounds, options.glyph_geometry)
	if reason != '' && document_glyph_raster_dump != '' {
		eprintln('VOX_TEXT_RASTER fallback=${reason} font=${font_path}#${face_index} size=${font_size} weight=${font_weight} smoothing=${font_smoothing}')
	}
	return reason == ''
}

__global document_glyph_raster_dump = os.getenv('VOX_TEXT_RASTER_DUMP')
// Same-binary control: draw and merge a clipped glyph run on the GPU even when
// its clip edges cross no glyph coverage.
const retain_covered_glyph_clip_draws = os.getenv('VOX_RETAIN_COVERED_GLYPH_CLIP_DRAWS') != ''
// Also draw and merge such runs and report any pixel that differs from the
// skipped draw's result.
const verify_covered_glyph_clip_draws = os.getenv('VOX_VERIFY_COVERED_GLYPH_CLIP_DRAWS') != ''
const overlap_glyph_backdrop = os.getenv('VOX_OVERLAP_GLYPH_BACKDROP') == '1'
const pipeline_glyph_masks = os.getenv('VOX_PIPELINE_GLYPH_MASKS') == '1'
const prefetch_glyph_backdrop_copy = os.getenv('VOX_PREFETCH_GLYPH_BACKDROP_COPY') == '1'

struct DocumentGlyphBackdrop {
	pixels   &u8
	geometry [7]i32
	scale    f32
mut:
	attempted bool
	loaded    bool
	ticket    voidptr
}

fn (mut backdrop DocumentGlyphBackdrop) finish_copy() {
	$if macos {
		if backdrop.ticket != unsafe { nil } {
			C.native_document_finish_text_backdrop_copy(backdrop.ticket)
			backdrop.ticket = unsafe { nil }
			backdrop.attempted = true
			backdrop.loaded = true
		}
	}
}

fn read_document_glyph_backdrop(context voidptr) bool {
	mut backdrop := unsafe { &DocumentGlyphBackdrop(context) }
	backdrop.finish_copy()
	if !backdrop.attempted {
		backdrop.attempted = true
		backdrop.loaded = C.native_document_text_raster_read_backdrop(backdrop.pixels,
			backdrop.geometry[0], backdrop.geometry[1], backdrop.geometry[2], backdrop.geometry[3],
			backdrop.scale) != 0
	}
	return backdrop.loaded
}

__global document_glyph_raster_records = 0

fn document_glyph_raster_record(run cpuraster.CanvasGlyphRun, transform [6]f32, geometry [7]i32,
	scale f32, color u32, font_smoothing int, pixels []u8, backdrop bool) {
	index := document_glyph_raster_records
	document_glyph_raster_records++
	os.mkdir_all(document_glyph_raster_dump) or {}
	if backdrop {
		os.write_file_array(os.join_path(document_glyph_raster_dump, '${index}.rgba'), pixels) or {}
	}
	precise := if components := run.paint_color {
		'[${components[0]},${components[1]},${components[2]},${components[3]}]'
	} else { 'null' }
	display_p3 := $if macos { C.native_document_raster_uses_p3() != 0 } $else { false }
	line := '{"index":${index},"font":"${run.font_path}","face":${run.face_index},"size":${run.font_size},' +
		'"glyphs":${run.glyphs},"positions":${run.positions},"translation":${run.translation[..]},' +
		'"transform":${transform[..]},"geometry":${geometry[..]},"scale":${scale},"color":${color},' +
		'"smoothing":${font_smoothing},"backdrop":${backdrop},"paint_color":${precise},' +
		'"destination_p3":${display_p3}}\n'
	mut file := os.open_append(os.join_path(document_glyph_raster_dump, 'runs.jsonl')) or { return }
	file.write_string(line) or {}
	file.close()
}

fn draw_document_glyph_raster_run(glyphs []u16, positions []f64, font_path string, face_index int,
	font_size f32, font_weight int, baseline_x f32, baseline_y f32, matrix [6]f32,
	page_x f32, page_y f32, scroll_y f32, canvas_width f32, canvas_height f32,
	color u32, font_smoothing int, paint_color ?[4]f32, clip_bounds ?[4]f32,
	glyph_geometry &layout.RetainedGlyphReplayGeometry) string {
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
		mut glyph_positions := []f32{}
		mut position_bounds := cpuraster.Rect{}
		mut position_validation := cpuraster.GlyphPositionValidation{}
		if glyph_geometry != unsafe { nil } && glyph_geometry.positions.len == glyphs.len * 2 {
			glyph_positions = glyph_geometry.positions
			position_bounds = glyph_geometry.bounds
			position_validation = glyph_geometry.validation
			if retained_glyph_geometry_diagnostics {
				eprintln('VOX_RETAINED_GLYPH_GEOMETRY_USE positions=${glyph_positions.len}')
			}
		} else {
			glyph_positions = []f32{len: glyphs.len * 2}
			position_bounds = cpuraster.prepare_retained_glyph_positions(positions,
				mut glyph_positions, baseline_x, baseline_y, chromium)
		}
		source_color := paint_color or {
			[f32((color >> 16) & 255) / 255, f32((color >> 8) & 255) / 255,
				f32(color & 255) / 255, f32(color >> 24) / 255]!
		}
		effective_color := if C.native_document_raster_uses_p3() != 0 {
			if document_extended_glyph_color && source_color[3] == 1 {
				?[4]f32(document_color_to_p3_for_blending(source_color))
			} else { ?[4]f32(document_color_to_p3(source_color)) }
		} else { paint_color }
		ink := effective_color or { source_color }
		extended_blend := document_extended_glyph_color && document_glyph_requires_extended_blend(ink)
		run := cpuraster.CanvasGlyphRun{
			font_path:         font_path
			face_index:        face_index
			font_size:         font_size
			glyphs:            glyphs
			positions:         glyph_positions
			position_validation: position_validation
			translation:       if chromium { [f32(0), 0]! } else { [baseline_x, baseline_y]! }
			baseline_snap:     true
			smoothing:         font_smoothing & 15
			retained:          true
			chromium_coverage: chromium
			paint_color:       effective_color
		}
		// The page matrix: CSS transform after the page offset and scroll.
		tx := page_x + matrix[4]
		ty := page_y - scroll_y + matrix[5]
		mut cache := document_glyph_cache()
		local := cpuraster.canvas_glyph_run_bounds(mut cache, run, position_bounds: position_bounds) or {
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
		prepared := C.native_document_text_raster_begin(left, top, right, bottom, canvas_width, canvas_height,
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
		can_defer_backdrop := backdrop && glyphs.len >= 4 && clip_bounds == none
			&& !extended_blend && document_glyph_raster_dump == ''
		mut destination := DocumentGlyphBackdrop{pixels: pixels.data, geometry: geometry, scale: scale}
		if can_defer_backdrop && prefetch_glyph_backdrop_copy {
			destination.ticket = C.native_document_start_text_backdrop_copy(pixels.data,
				geometry[0], geometry[1], geometry[2], geometry[3], scale)
		}
		// A rejected run can return before its loader is called.
		defer { destination.finish_copy() }
		copy_pending := destination.ticket != unsafe { nil }
		deferred_backdrop := can_defer_backdrop && (pipeline_glyph_masks || overlap_glyph_backdrop || copy_pending)
		if backdrop && !deferred_backdrop && C.native_document_text_raster_read_backdrop(pixels.data,
			geometry[0], geometry[1], i32(width), i32(height), scale) == 0 {
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
		if bounds := clip_bounds {
			if ink[3] != 1 { return 'clipped glyph requires opaque A8 ink' }
			mask_run := cpuraster.CanvasGlyphRun{...run, paint_color: ink}
			mut coverage := []u8{len: pixels.len}
			if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut coverage, width, height, width * 4, 2,
				mask_run, transform, color, none, 1, .src_over, [], none) { return 'clipped glyph mask declined' }
			mask := []u8{len: width * height, init: coverage[index * 4 + 3]}
			clip := document_glyph_device_clip(bounds, geometry, scale_x, scale_y, page_x, page_y, scroll_y)
			// A clip whose edges cross no glyph coverage leaves the merge below
			// nothing to take from the clipped GPU draw; skip its upload and readback.
			covered := !retain_covered_glyph_clip_draws
				&& document_glyph_clip_edges_are_blank(clip, mask, width, height)
			mut clipped := if covered && !verify_covered_glyph_clip_draws { []u8{} } else { pixels.clone() }
			if extended_blend {
				if !cpuraster.blend_extended_glyph_mask(mut pixels, width, height, width * 4, mask, ink) {
					return 'extended glyph interior declined'
				}
			} else if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, width, height, width * 4, 2, run,
				transform, color, none, 1, .src_over, [], none) { return 'clipped glyph interior declined' }
			if covered {
				if !document_glyph_mask_drawable(pixels, width, height, mask, ink, clip, geometry,
					scale_x, scale_y, page_x, page_y, scroll_y) { return 'clipped glyph GPU declined' }
				if verify_covered_glyph_clip_draws {
					verify_covered_glyph_clip_draw(pixels, mut clipped, width, height, mask, ink, bounds,
						clip, geometry, scale_x, scale_y, page_x, page_y, scroll_y)
				}
			} else {
				if !draw_document_glyph_mask(mut clipped, width, height, mask, ink, bounds,
					geometry, scale_x, scale_y, page_x, page_y, scroll_y) { return 'clipped glyph GPU declined' }
				if !merge_clipped_glyph_edges(mut pixels, clipped, width, height, clip) { return 'clipped glyph merge declined' }
			}
			if chromium_paint_layer_diagnostics {
				eprintln('VOX_GLYPH_CLIP_COVERED covered=${covered} raster=${width}x${height}')
			}
		} else if extended_blend {
			mut coverage := []u8{len: pixels.len}
			if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut coverage, width, height, width * 4, 2,
				run, transform, color, none, 1, .src_over, [], none) { return 'extended glyph mask declined' }
			mask := []u8{len: width * height, init: coverage[index * 4 + 3]}
			if !cpuraster.blend_extended_glyph_mask(mut pixels, width, height, width * 4, mask, ink) {
				return 'extended glyph blend declined'
			}
		} else {
			loader := if deferred_backdrop {
				cpuraster.CanvasGlyphBackdrop{
					context: &destination
					read: read_document_glyph_backdrop
					pipeline_masks: pipeline_glyph_masks
					copy_pending: copy_pending && !overlap_glyph_backdrop
				}
			} else {
				cpuraster.CanvasGlyphBackdrop{}
			}
			if !cpuraster.fill_canvas_glyphs_cached(mut cache, mut pixels, width, height, width * 4, 2,
				run, transform, color, none, 1, .src_over, [], none, loader) {
				return if destination.attempted && !destination.loaded { 'backdrop unreadable' } else { 'cpuraster declined' }
			}
			// A culled run can succeed before the loader runs. Preserve the
			// earlier pixels when the finish operation replaces the backdrop.
			if deferred_backdrop && !destination.loaded && !read_document_glyph_backdrop(&destination) {
				return 'backdrop unreadable'
			}
		}
		if C.native_document_text_raster_finish(pixels.data, geometry[0], geometry[1], i32(width), i32(height),
			geometry[5], geometry[6], canvas_height, i32(backdrop)) == 0 {
			return 'composite failed'
		}
		if chromium_paint_layer_diagnostics {
			if bounds := clip_bounds {
				eprintln('VOX_GLYPH_RECTANGLE_CLIP bounds=${bounds} raster=${geometry[..]} backend=gpu')
			}
			if extended_blend {
				eprintln('VOX_EXTENDED_GLYPH_COLOR ink=${ink[..]} raster=${geometry[..]} backend=cpu')
			}
		}
		return ''
	}
	return 'unsupported platform'
}
