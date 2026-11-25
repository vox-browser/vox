module main

import cpuraster
import layout
import math
import os
import processmetrics

$if !cpuraster_freetype ? {
	const prefetch_frame_glyph_masks = os.getenv('VOX_PREFETCH_FRAME_GLYPH_MASKS') == '1'
	const prefetch_tail_frame_glyph_masks = os.getenv('VOX_PREFETCH_TAIL_FRAME_GLYPH_MASKS') == '1'
	const prefetch_frame_glyph_masks_during_setup = os.getenv('VOX_EARLY_FRAME_GLYPH_PREFETCH') == '1'

	@[params]
	struct DocumentGlyphPrefetchOptions {
		width  int
		height int
	}

	fn (mut app BrowserApp) start_early_document_glyph_prefetch(page_y f32, width int, height int) voidptr {
		if !prefetch_frame_glyph_masks_during_setup || document_display_p3_enabled() != 0
			|| serial_retained_glyph_geometry || app.paint_commands.len > retained_glyph_geometry_command_limit
			|| width <= 0 || height <= 0 {
			return unsafe { nil }
		}
		return app.start_document_glyph_prefetch([], page_y, width: width, height: height)
	}

	fn (mut app BrowserApp) start_document_glyph_prefetch(geometry []RetainedGlyphReplayGeometry,
		page_y f32, options DocumentGlyphPrefetchOptions) voidptr {
		if !prefetch_frame_glyph_masks || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| C.native_document_raster_uses_p3() != 0 || document_glyph_raster_dump != '' {
			return unsafe { nil }
		}
		scale := f32(C.native_raster_device_pixel_ratio())
		if scale != 1 && scale != 2 { return unsafe { nil } }
		stage := processmetrics.begin_thread_instruction_substage('glyph_frame_prefetch_submission')
		defer { stage.finish() }
		cache := document_glyph_cache()
		cold := cpuraster.glyph_frame_prefetch_can_split(cache)
		early := options.width > 0 && options.height > 0
		if early && !cold { return unsafe { nil } }
		split := prefetch_tail_frame_glyph_masks && cold
		limit := if split { 128 } else { 32 }
		mut runs := []cpuraster.GlyphFramePrefetchRun{cap: limit}
		mut front_runs := 0
		mut tail_command := 0
		command_count := if early { app.paint_commands.len } else { geometry.len }
		for index in 0 .. math.min(command_count, if split { 512 } else { 160 }) {
			in_front := index < 160 && front_runs < 32
			if !in_front && front_runs == 0 { break }
			command := unsafe { &app.paint_commands[index] }
			if early {
				if command.kind != 'draw_text' || retained_glyph_geometry_position_count(command) == 0
					|| layout.paint_leaf_is_outside_canvas(command, 0, f64(page_y), f64(options.width), f64(options.height)) {
					continue
				}
			} else if geometry[index].positions.len == 0 {
				continue
			}
			if command.opacity != 1 || command.group_opacity != 1 { continue }
			run := command.glyph_run or { continue }
			if run.face() != .document { continue }
			font := run.font()
			smoothing := native_retained_font_smoothing(command.font_smoothing, font)
			if smoothing & 16 == 0 { continue }
			matrix := normalized_paint_transform(command.transform)
			if matrix[1] != 0 || matrix[2] != 0 || matrix[0] <= 0 || matrix[3] <= 0
				|| !f32_finite(f32(matrix[0])) || !f32_finite(f32(matrix[3])) {
				continue
			}
			color := app.paint_colors.color(command.color, command.opacity)
			if in_front {
				front_runs++
			} else if tail_command == 0 {
				tail_command = index
			}
			// An integral device scale makes removing the raster's integer
			// origin subpixel-neutral. Float rounding can still pick a
			// neighboring key, which ordinary glyph lookup then misses.
			runs << cpuraster.GlyphFramePrefetchRun{
				run: cpuraster.CanvasGlyphRun{
					font_path: native_replay_font_path(font)
					face_index: font.face_index()
					font_size: font.point_size
					glyphs: run.glyph_indices()
					positions: if early { []f32{} } else { geometry[index].positions }
					baseline_snap: true
					smoothing: smoothing & 15
					retained: true
					chromium_coverage: true
					paint_color: chromium_retained_paint_color(*command)
				}
				transform: [f32(matrix[0]) * scale, f32(0), 0, f32(matrix[3]) * scale, f32(matrix[4]) * scale,
					(page_y + f32(matrix[5])) * scale]!
				color: u32(color.a) << 24 | u32(color.r) << 16 | u32(color.g) << 8 | u32(color.b)
				raw_positions: if early { run.glyph_positions() } else { []f64{} }
				raw_origin: [f32(command.glyph_translation_x), f32(command.glyph_translation_y)]!
				fold_origin: font.font_rendering_policy == .chromium
			}
			if runs.len == limit { break }
		}
		if runs.len == 0 { return unsafe { nil } }
		return cpuraster.start_glyph_frame_prefetch(cache, runs, front_runs: front_runs, tail_command: tail_command)
	}

	fn publish_document_glyph_prefetch(context voidptr, command_index int) int {
		stage := processmetrics.begin_thread_instruction_substage('glyph_frame_prefetch_join')
		defer { stage.finish() }
		return cpuraster.advance_glyph_frame_prefetch(context, document_glyph_cache(), command_index)
	}

	fn discard_document_glyph_prefetch(context voidptr) {
		cpuraster.finish_glyph_frame_prefetch(context, unsafe { nil })
	}
}
