module cpuraster

import math
import os
import runtime

$if !cpuraster_freetype ? {
	fn C.pthread_threadid_np(voidptr, &u64) i32

	const glyph_batch_min = 4
	const glyph_batch_max = 16
	const glyph_batch_lookahead = 48
	const glyph_batch_max_context_pixels = 64 * 1024
	const serial_glyph_masks = os.getenv('VOX_SERIAL_GLYPH_MASKS') == '1'
	const glyph_batch_diagnostics = os.getenv('VOX_GLYPH_BATCH_DIAGNOSTICS') == '1'

	struct GlyphImageJob {
		key    u32
		bounds StrikeGlyph
		width  int
		height int
	mut:
		pixels []u32
		drawn  bool
		thread u64
	}

	struct GlyphImageBatch {
		strike      &GlyphStrike
		diagnostics bool
	mut:
		jobs []GlyphImageJob
	}

	fn draw_glyph_image_jobs(context voidptr, first i32, end i32) {
		mut batch := unsafe { &GlyphImageBatch(context) }
		strike := batch.strike
		for index in first .. end {
			mut job := unsafe { &batch.jobs[index] }
			x := f32(-job.bounds.left) + f32((job.key >> 2) & 3) / 4
			y := f32(job.bounds.top + job.bounds.height) - f32(job.key & 3) / 4
			// The font is immutable and stays retained until the join. Each
			// job has its own bitmap context and writes to its own storage.
			job.drawn = C.cpuraster_ct_draw_glyph(strike.font, u16(job.key >> 4),
				&strike.transform[0], int(strike.invertible), f64(x), f64(y), job.pixels.data,
				job.width, job.height, job.bounds.width, job.bounds.height, 0, 0,
				strike.smoothing) != 0
			if batch.diagnostics { C.pthread_threadid_np(unsafe { nil }, &job.thread) }
		}
	}

	// Look ahead only after the first cold mask. Publish completed masks into
	// the cache on its owning thread. The caller still blits in glyph order.
	fn (mut entry CachedGlyphStrike) prepare_glyph_masks(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, start int,
		rounding SkAffine) {
		if entry.empty || run.glyphs.len - start < glyph_batch_min || serial_glyph_masks
			|| C.vox_scan_workers_disabled() {
			return
		}
		mut keys := [glyph_batch_max]u32{}
		mut count := 0
		for index in start .. math.min(run.glyphs.len, start + glyph_batch_lookahead) {
			if routes[index].kind != .mask { continue }
			mapped := map_point_affine(rounding,
				Point{run.positions[index * 2], run.positions[index * 2 + 1]})
			key := packed_glyph_key(run.glyphs[index],
				if strike.snap_x { 0 } else { packed_subpixel(mapped.x) },
				if strike.snap_y { 0 } else { packed_subpixel(mapped.y) })
			if key in entry.glyphs || key in keys[..count] { continue }
			keys[count] = key
			count++
			if count == keys.len { break }
		}
		if count < glyph_batch_min || !strike.ensure_font(mut lazy) { return }
		lanes := math.min(runtime.nr_cpus(), int(C.VOX_SCAN_WORKERS_MAX))
		if lanes < 2 { return }
		mut jobs := []GlyphImageJob{cap: count}
		for key in keys[..count] {
			bounds := strike.glyph_bounds(u16(key >> 4), int((key >> 2) & 3), int(key & 3))
			if bounds.width == 0 || bounds.height == 0 || bounds.width >= glyph_max_width {
				continue
			}
			width := next_pow2(bounds.width)
			height := next_pow2(bounds.height)
			if i64(width) * height > glyph_batch_max_context_pixels { continue }
			jobs << GlyphImageJob{ key: key, bounds: bounds, width: width, height: height }
		}
		if jobs.len < glyph_batch_min { return }
		for mut job in jobs {
			job.pixels = []u32{len: job.width * job.height}
		}
		mut batch := GlyphImageBatch{
			strike:      &strike
			diagnostics: glyph_batch_diagnostics
			jobs:        jobs
		}
		C.vox_scan_workers_run(&batch, i32(jobs.len), i32(math.min(lanes, jobs.len)),
			draw_glyph_image_jobs)
		glyph_cache_enter(entry.owner)
		for job in jobs {
			if !job.drawn { continue }
			glyph := strike.glyph_image(job.bounds, job.pixels, job.width, job.height)
			entry.glyphs[job.key] = glyph
			entry.bytes += glyph.image.len
		}
		glyph_cache_leave(entry.owner)
		if batch.diagnostics {
			mut threads := []u64{}
			for job in jobs {
				if job.thread != 0 && job.thread !in threads { threads << job.thread }
			}
			eprintln('VOX_GLYPH_MASK_BATCH jobs=${jobs.len} threads=${threads.len}')
		}
	}
}
