module cpuraster

import math
import os
import runtime
import time

$if !cpuraster_freetype ? {
	fn C.pthread_threadid_np(voidptr, &u64) i32
	fn C.calloc(uint, uint) voidptr

	const glyph_batch_min = 4
	const glyph_batch_max = 16
	const glyph_batch_lookahead = 48
	const glyph_batch_max_context_pixels = 64 * 1024
	const serial_glyph_masks = os.getenv('VOX_SERIAL_GLYPH_MASKS') == '1'
	const glyph_batch_diagnostics = os.getenv('VOX_GLYPH_BATCH_DIAGNOSTICS') == '1'

	struct GlyphImageJob {
		key u32
	mut:
		bounds GlyphMaskBounds
		mask   voidptr
		ready  bool
		thread u64
		started u64
		rendered u64
	}

	struct GlyphImageBatch {
		strike      &GlyphStrike
		diagnostics bool
	mut:
		jobs []GlyphImageJob
	}

	fn glyph_run_mask_key(run &CanvasGlyphRun, strike &GlyphStrike, rounding SkAffine,
		index int) u32 {
		mapped := map_point_affine(rounding,
			Point{run.positions[index * 2], run.positions[index * 2 + 1]})
		return packed_glyph_key(run.glyphs[index],
			if strike.snap_x { 0 } else { packed_subpixel(mapped.x) },
			if strike.snap_y { 0 } else { packed_subpixel(mapped.y) })
	}

	fn draw_glyph_image_jobs(context voidptr, first i32, end i32) {
		mut batch := unsafe { &GlyphImageBatch(context) }
		strike := batch.strike
		for index in first .. end {
			mut job := unsafe { &batch.jobs[index] }
			if batch.diagnostics {
				C.pthread_threadid_np(unsafe { nil }, &job.thread)
				job.started = time.sys_mono_now()
			}
			// Workers share the immutable strike and use native memory for
			// temporary bitmaps. The cache's V arena belongs to the caller.
			id := u16(job.key >> 4)
			sub_x := int((job.key >> 2) & 3)
			sub_y := int(job.key & 3)
			bounds := strike.glyph_mask_bounds(id, sub_x, sub_y)
			job.bounds = bounds
			if bounds.width == 0 || bounds.height == 0 || bounds.width >= glyph_max_width {
				job.ready = true
				continue
			}
			width := next_pow2(bounds.width)
			height := next_pow2(bounds.height)
			if i64(width) * height > glyph_batch_max_context_pixels { continue }
			bitmap := C.calloc(uint(width * height), sizeof(u32))
			if bitmap == unsafe { nil } { continue }
			x := f32(-bounds.left) + f32(sub_x) / 4
			y := f32(bounds.top + bounds.height) - f32(sub_y) / 4
			if C.cpuraster_ct_draw_glyph(strike.font, id, &strike.transform[0],
				int(strike.invertible), f64(x), f64(y), bitmap, width, height, bounds.width,
				bounds.height, 0, 0, strike.smoothing) == 0 {
				C.free(bitmap)
				continue
			}
			strike.write_glyph_mask(bitmap, bitmap, bounds.width, bounds.height, width, height)
			job.mask = bitmap
			job.ready = true
			if batch.diagnostics { job.rendered = time.sys_mono_now() }
		}
	}

	fn (entry &CachedGlyphStrike) glyph_image_batch(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, start int,
		rounding SkAffine) ?GlyphImageBatch {
		if entry.empty || run.glyphs.len - start < glyph_batch_min || serial_glyph_masks
			|| C.vox_scan_workers_disabled() {
			return none
		}
		mut keys := [glyph_batch_max]u32{}
		mut count := 0
		for index in start .. math.min(run.glyphs.len, start + glyph_batch_lookahead) {
			if routes[index].kind != .mask { continue }
			key := glyph_run_mask_key(run, &strike, rounding, index)
			if key in entry.glyphs || key in keys[..count] { continue }
			keys[count] = key
			count++
			if count == keys.len { break }
		}
		if count < glyph_batch_min || runtime.nr_cpus() < 2 || !strike.ensure_font(mut lazy) {
			return none
		}
		return GlyphImageBatch{
			strike:      &strike
			diagnostics: glyph_batch_diagnostics
			jobs:        []GlyphImageJob{len: count, init: GlyphImageJob{ key: keys[index] }}
		}
	}

	// Publish on the glyph cache's owning thread after the workers join.
	fn (mut entry CachedGlyphStrike) publish_glyph_image_batch(batch &GlyphImageBatch) {
		glyph_cache_enter(entry.owner)
		for job in batch.jobs {
			if !job.ready { continue }
			bounds := job.bounds
			mut image := []u8{}
			if job.mask != unsafe { nil } {
				image = []u8{len: bounds.width * bounds.height}
				unsafe { vmemcpy(image.data, job.mask, image.len) }
				C.free(job.mask)
			}
			entry.glyphs[job.key] = StrikeGlyph{bounds.left, bounds.top, bounds.width, bounds.height, image}
			entry.bytes += image.len
		}
		glyph_cache_leave(entry.owner)
		if batch.diagnostics {
			mut threads := []u64{}
			for job in batch.jobs {
				if job.thread != 0 && job.thread !in threads { threads << job.thread }
			}
			eprintln('VOX_GLYPH_MASK_BATCH jobs=${batch.jobs.len} threads=${threads.len}')
		}
	}

	fn (mut entry CachedGlyphStrike) prepare_glyph_masks(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, start int,
		rounding SkAffine) {
		mut batch := entry.glyph_image_batch(mut strike, mut lazy, run, routes, start, rounding) or { return }
		// Give each lane at least two keys to amortize its dispatch.
		lanes := math.min(batch.jobs.len / 2, math.min(runtime.nr_cpus(), int(C.VOX_SCAN_WORKERS_MAX)))
		C.vox_scan_workers_run(&batch, i32(batch.jobs.len), i32(lanes), draw_glyph_image_jobs)
		entry.publish_glyph_image_batch(&batch)
	}

	fn (mut entry CachedGlyphStrike) prepare_glyph_masks_over_backdrop(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, rounding SkAffine,
		backdrop CanvasGlyphBackdrop) (bool, bool) {
		// Keep warm starts on the ordinary loop. It can discover a later miss
		// without a second scan of the warm prefix.
		if routes[0].kind != .mask || glyph_run_mask_key(run, &strike, rounding, 0) in entry.glyphs {
			return false, backdrop.read(backdrop.context)
		}
		mut batch := entry.glyph_image_batch(mut strike, mut lazy, run, routes, 0, rounding) or {
			return false, backdrop.read(backdrop.context)
		}
		ticket, lanes := start_background_raster_ranges(&batch, batch.jobs.len, batch.jobs.len / 2,
			draw_glyph_image_jobs)
		if lanes == 0 { return false, backdrop.read(backdrop.context) }
		read_started := if batch.diagnostics { time.sys_mono_now() } else { u64(0) }
		loaded := backdrop.read(backdrop.context)
		read_finished := if batch.diagnostics { time.sys_mono_now() } else { u64(0) }
		ready := join_background_raster_range(ticket)
		if loaded {
			entry.publish_glyph_image_batch(&batch)
		} else {
			for job in batch.jobs {
				if job.mask != unsafe { nil } { C.free(job.mask) }
			}
		}
		if batch.diagnostics {
			overlap := batch.jobs.count(it.rendered > read_started && it.started < read_finished)
			eprintln('VOX_GLYPH_BACKDROP_BATCH jobs=${batch.jobs.len} lanes=${lanes} loaded=${loaded} ready_at_join=${ready} overlap=${overlap}')
		}
		return true, loaded
	}
}
