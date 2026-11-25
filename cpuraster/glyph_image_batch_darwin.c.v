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
	const single_glyph_mask_batch = os.getenv('VOX_SINGLE_GLYPH_MASK_BATCH') == '1'
	const glyph_mask_batch_min_four = os.getenv('VOX_GLYPH_MASK_BATCH_MIN_FOUR') == '1'
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
		jobs     []GlyphImageJob
		followup bool
	}

	struct GlyphMaskWindow {
	mut:
		next int
	}

	@[heap]
	struct PendingGlyphBackdropBatch {
		entry    &CachedGlyphStrike
		pipeline bool
		next     int
	mut:
		batch         GlyphImageBatch
		ticket        voidptr
		lanes         int
		owner_started u64
		read_started  u64
		read_finished u64
	}

	fn glyph_run_mask_key(run &CanvasGlyphRun, strike &GlyphStrike, rounding SkAffine,
		index int) u32 {
		mapped := map_point_affine(rounding,
			Point{run.positions[index * 2], run.positions[index * 2 + 1]})
		return glyph_mask_key_at_position(run.glyphs[index], strike, mapped)
	}

	fn glyph_mask_key_at_position(id u16, strike &GlyphStrike, mapped Point) u32 {
		return packed_glyph_key(id,
			if strike.snap_x { 0 } else { packed_subpixel(mapped.x) },
			if strike.snap_y { 0 } else { packed_subpixel(mapped.y) })
	}

	fn draw_glyph_image_jobs(context voidptr, first i32, end i32) {
		mut batch := unsafe { &GlyphImageBatch(context) }
		for index in first .. end {
			mut job := unsafe { &batch.jobs[index] }
			draw_glyph_image_job(batch.strike, mut job, batch.diagnostics)
		}
	}

	fn draw_glyph_image_job(strike &GlyphStrike, mut job GlyphImageJob, diagnostics bool) {
		if diagnostics {
			C.pthread_threadid_np(unsafe { nil }, &job.thread)
			job.started = time.sys_mono_now()
		}
		// Only the caller publishes into the cache's V arena.
		id := u16(job.key >> 4)
		sub_x := int((job.key >> 2) & 3)
		sub_y := int(job.key & 3)
		bounds := strike.glyph_mask_bounds(id, sub_x, sub_y)
		job.bounds = bounds
		if bounds.width == 0 || bounds.height == 0 || bounds.width >= glyph_max_width {
			job.ready = true
			return
		}
		width := next_pow2(bounds.width)
		height := next_pow2(bounds.height)
		if i64(width) * height > glyph_batch_max_context_pixels { return }
		bitmap := C.calloc(uint(width * height), sizeof(u32))
		if bitmap == unsafe { nil } { return }
		x := f32(-bounds.left) + f32(sub_x) / 4
		y := f32(bounds.top + bounds.height) - f32(sub_y) / 4
		if C.cpuraster_ct_draw_glyph(strike.font, id, &strike.transform[0],
			int(strike.invertible), f64(x), f64(y), bitmap, width, height, bounds.width,
			bounds.height, 0, 0, strike.smoothing) == 0 {
			C.free(bitmap)
			return
		}
		strike.write_glyph_mask(bitmap, bitmap, bounds.width, bounds.height, width, height)
		job.mask = bitmap
		job.ready = true
		if diagnostics { job.rendered = time.sys_mono_now() }
	}

	fn (entry &CachedGlyphStrike) glyph_image_batch(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, start int,
		rounding SkAffine, minimum_jobs int, mut window GlyphMaskWindow) ?GlyphImageBatch {
		window.next = run.glyphs.len
		if entry.empty || run.glyphs.len - start < minimum_jobs || serial_glyph_masks
			|| C.vox_scan_workers_disabled() {
			return none
		}
		mut keys := [glyph_batch_max]u32{}
		mut count := 0
		mut next := start
		for index in start .. math.min(run.glyphs.len, start + glyph_batch_lookahead) {
			next = index + 1
			if routes[index].kind != .mask { continue }
			key := glyph_run_mask_key(run, &strike, rounding, index)
			if key in entry.glyphs || key in keys[..count] { continue }
			keys[count] = key
			count++
			if count == keys.len { break }
		}
		if !single_glyph_mask_batch { window.next = next }
		if count < minimum_jobs { return none }
		if runtime.nr_cpus() < 2 || !strike.ensure_font(mut lazy) {
			window.next = run.glyphs.len
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
			entry.publish_glyph_image(job)
		}
		glyph_cache_leave(entry.owner)
		if batch.diagnostics {
			mut threads := []u64{}
			for job in batch.jobs {
				if job.thread != 0 && job.thread !in threads { threads << job.thread }
			}
			eprintln('VOX_GLYPH_MASK_BATCH jobs=${batch.jobs.len} threads=${threads.len} followup=${batch.followup}')
		}
	}

	// The caller holds the cache's allocation scope.
	fn (mut entry CachedGlyphStrike) publish_glyph_image(job GlyphImageJob) {
		if !job.ready { return }
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

	fn (mut entry CachedGlyphStrike) prepare_glyph_masks(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, start int,
		rounding SkAffine, followup bool) int {
		mut window := GlyphMaskWindow{}
		minimum_jobs := if glyph_mask_batch_min_four { glyph_batch_min } else { 2 }
		mut batch := entry.glyph_image_batch(mut strike, mut lazy, run, routes, start, rounding,
			minimum_jobs, mut window) or { return window.next }
		batch.followup = followup
		if batch.jobs.len < glyph_batch_min {
			// Two lanes suffice for short batches. Submit one explicitly so
			// the caller can draw the remaining masks in parallel.
			if run_raster_ranges_with_caller(&batch, batch.jobs.len, 2, draw_glyph_image_jobs) == 0 {
				return window.next
			}
		} else {
			// Give each lane at least two keys to amortize its dispatch.
			lanes := math.min(batch.jobs.len / 2, math.min(runtime.nr_cpus(), int(C.VOX_SCAN_WORKERS_MAX)))
			C.vox_scan_workers_run(&batch, i32(batch.jobs.len), i32(lanes), draw_glyph_image_jobs)
		}
		entry.publish_glyph_image_batch(&batch)
		return window.next
	}

	fn (mut entry CachedGlyphStrike) start_glyph_backdrop_batch(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, rounding SkAffine,
		pipeline bool) voidptr {
		// Keep warm starts on the ordinary loop. It can discover a later miss
		// without a second scan of the warm prefix.
		if routes[0].kind != .mask || glyph_run_mask_key(run, &strike, rounding, 0) in entry.glyphs {
			return unsafe { nil }
		}
		mut window := GlyphMaskWindow{}
		batch := entry.glyph_image_batch(mut strike, mut lazy, run, routes, 0, rounding,
			glyph_batch_min, mut window) or {
			return unsafe { nil }
		}
		mut pending := &PendingGlyphBackdropBatch{
			entry: &entry
			pipeline: pipeline
			next: window.next
			batch: batch
		}
		ticket, lanes := start_background_raster_ranges(&pending.batch, batch.jobs.len, batch.jobs.len / 2,
			draw_glyph_image_jobs)
		if lanes == 0 { return unsafe { nil } }
		pending.ticket = ticket
		pending.lanes = lanes
		if batch.diagnostics { pending.owner_started = time.sys_mono_now() }
		return pending
	}

	fn read_pending_glyph_backdrop(context voidptr, backdrop CanvasGlyphBackdrop) bool {
		if context == unsafe { nil } { return backdrop.read(backdrop.context) }
		mut pending := unsafe { &PendingGlyphBackdropBatch(context) }
		if pending.batch.diagnostics { pending.read_started = time.sys_mono_now() }
		loaded := backdrop.read(backdrop.context)
		if pending.batch.diagnostics { pending.read_finished = time.sys_mono_now() }
		return loaded
	}

	fn finish_glyph_backdrop_batch(context voidptr, publish bool) int {
		if context == unsafe { nil } { return 0 }
		pending := unsafe { &PendingGlyphBackdropBatch(context) }
		batch := &pending.batch
		join_started := if batch.diagnostics { time.sys_mono_now() } else { u64(0) }
		ready := join_background_raster_range(pending.ticket)
		if publish {
			mut entry := unsafe { pending.entry }
			entry.publish_glyph_image_batch(batch)
		} else {
			for job in batch.jobs {
				if job.mask != unsafe { nil } { C.free(job.mask) }
			}
		}
		if batch.diagnostics {
			overlap := batch.jobs.count(it.rendered > pending.read_started && it.started < pending.read_finished)
			setup_overlap := batch.jobs.count(it.rendered > pending.owner_started && it.started < join_started)
			eprintln('VOX_GLYPH_BACKDROP_BATCH jobs=${batch.jobs.len} lanes=${pending.lanes} published=${publish} ready_at_join=${ready} overlap=${overlap} owner_overlap=${setup_overlap} pipeline=${pending.pipeline}')
		}
		return pending.next
	}

	fn (mut entry CachedGlyphStrike) prepare_glyph_masks_over_backdrop(mut strike GlyphStrike,
		mut lazy LazyGlyphFace, run &CanvasGlyphRun, routes []GlyphRoute, rounding SkAffine,
		backdrop CanvasGlyphBackdrop) (int, bool) {
		pending := entry.start_glyph_backdrop_batch(mut strike, mut lazy, run, routes, rounding, false)
		loaded := read_pending_glyph_backdrop(pending, backdrop)
		next := finish_glyph_backdrop_batch(pending, loaded)
		return next, loaded
	}
}
