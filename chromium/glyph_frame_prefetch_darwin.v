module main

import cpuraster
import math
import os
import processmetrics

$if !cpuraster_freetype ? {
	const prefetch_frame_glyph_masks = os.getenv('VOX_PREFETCH_FRAME_GLYPH_MASKS') == '1'

	fn (mut app BrowserApp) start_document_glyph_prefetch(geometry []RetainedGlyphReplayGeometry,
		page_y f32) voidptr {
		if !prefetch_frame_glyph_masks || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| C.native_document_raster_uses_p3() != 0 || document_glyph_raster_dump != '' {
			return unsafe { nil }
		}
		scale := f32(C.native_raster_device_pixel_ratio())
		if scale != 1 && scale != 2 { return unsafe { nil } }
		stage := processmetrics.begin_thread_instruction_substage('glyph_frame_prefetch_submission')
		defer { stage.finish() }
		mut runs := []cpuraster.GlyphFramePrefetchRun{cap: 32}
		for index in 0 .. math.min(geometry.len, 160) {
			prepared := &geometry[index]
			if prepared.positions.len == 0 { continue }
			command := unsafe { &app.paint_commands[index] }
			if command.opacity != 1 || command.group_opacity != 1 { continue }
			run := command.glyph_run or { continue }
			if run.face() != .document { continue }
			font := run.font()
			smoothing := native_retained_font_smoothing(command.font_smoothing, font)
			if smoothing & 16 == 0 { continue }
			matrix := normalized_paint_transform(command.transform)
			if matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1 { continue }
			color := app.paint_colors.color(command.color, command.opacity)
			// An integral device scale makes removing the raster's integer
			// origin subpixel-neutral. Float rounding can still pick a
			// neighboring key, which ordinary glyph lookup then misses.
			runs << cpuraster.GlyphFramePrefetchRun{
				run: cpuraster.CanvasGlyphRun{
					font_path: native_replay_font_path(font)
					face_index: font.face_index()
					font_size: font.point_size
					glyphs: run.glyph_indices()
					positions: prepared.positions
					baseline_snap: true
					smoothing: smoothing & 15
					retained: true
					chromium_coverage: true
					paint_color: chromium_retained_paint_color(*command)
				}
				transform: [scale, f32(0), 0, scale, f32(matrix[4]) * scale,
					(page_y + f32(matrix[5])) * scale]!
				color: u32(color.a) << 24 | u32(color.r) << 16 | u32(color.g) << 8 | u32(color.b)
			}
			if runs.len == 32 { break }
		}
		if runs.len == 0 { return unsafe { nil } }
		return cpuraster.start_glyph_frame_prefetch(document_glyph_cache(), runs)
	}

	fn publish_document_glyph_prefetch(context voidptr) {
		stage := processmetrics.begin_thread_instruction_substage('glyph_frame_prefetch_join')
		defer { stage.finish() }
		cpuraster.finish_glyph_frame_prefetch(context, document_glyph_cache())
	}

	fn discard_document_glyph_prefetch(context voidptr) {
		cpuraster.finish_glyph_frame_prefetch(context, unsafe { nil })
	}
}
