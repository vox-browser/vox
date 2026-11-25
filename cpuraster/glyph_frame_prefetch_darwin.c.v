module cpuraster

import os
import time

$if !cpuraster_freetype ? {
	const glyph_frame_prefetch_diagnostics = os.getenv('VOX_GLYPH_FRAME_PREFETCH_DIAGNOSTICS') == '1'
	const glyph_frame_prefetch_strikes = 4
	const glyph_frame_prefetch_jobs = 128

	pub struct GlyphFramePrefetchRun {
	pub:
		run       CanvasGlyphRun
		transform [6]f32
		color     u32
	}

	struct GlyphFrameStrike {
		key string
	mut:
		strike GlyphStrike
		keys   map[u32]bool
	}

	struct GlyphFrameJob {
		slot int
	mut:
		image GlyphImageJob
	}

	@[heap]
	struct GlyphFrameWork {
	mut:
		strikes      []GlyphFrameStrike
		jobs         []GlyphFrameJob
		ticket       voidptr
		lanes        int
		owner_start  u64
	}

	fn draw_glyph_frame_jobs(context voidptr, first i32, end i32) {
		mut batch := unsafe { &GlyphFrameWork(context) }
		for index in first .. end {
			mut job := unsafe { &batch.jobs[index] }
			strike := unsafe { &batch.strikes[job.slot].strike }
			draw_glyph_image_job(strike, mut job.image, glyph_frame_prefetch_diagnostics)
		}
	}

	fn (mut batch GlyphFrameWork) collect(run_spec &GlyphFramePrefetchRun, cache &GlyphCache) {
		run := &run_spec.run
		if run.glyphs.len == 0 || run.positions.len != run.glyphs.len * 2
			|| !run.retained || !run.chromium_coverage || run.font_path == '' { return }
		device := pre_translate(canvas_affine(run_spec.transform), run.translation[0], run.translation[1])
		if !affine_is_finite(device) || glyphs_draw_as_paths(run.font_size, device) { return }
		face_key := glyph_face_key(run.font_path, run.face_index)
		color := run_spec.color
		alpha := if precise := run.paint_color { fmin(fmax(precise[3], 0), 1) }
			else { canvas_paint_alpha(color, 1) }
		luminance := paint_luminance(color, alpha, none, none)
		mut strike := glyph_strike_template(run.font_size, device, luminance) or { return }
		strike.snap_y = run.baseline_snap && sk_relax(device.ky) == 0
		strike.snap_x = run.baseline_snap && !strike.snap_y && sk_relax(device.sx) == 0
		strike.smoothing = run.smoothing
		smooth := select_glyph_mask_gamma(mut strike, run, color, alpha, none, none, luminance)
		key := glyph_strike_key(face_key + '\x00chromium', run.font_size, device, &strike,
			smooth, luminance)
		mut slot := -1
		for index, planned in batch.strikes {
			if planned.key == key {
				slot = index
				break
			}
		}
		if slot < 0 {
			if batch.strikes.len >= glyph_frame_prefetch_strikes { return }
			mut lazy := LazyGlyphFace{path: run.font_path, index: run.face_index}
			defer { lazy.release() }
			info := glyph_face_info(cache, face_key, mut lazy) or { return }
			if info.color_glyphs || !strike.ensure_font(mut lazy) { return }
			slot = batch.strikes.len
			batch.strikes << GlyphFrameStrike{key: key, strike: strike}
		}
		mut owner := &batch.strikes[slot]
		entry := cache.strikes[key] or { unsafe { &CachedGlyphStrike(nil) } }
		rounding := SkAffine{
			...device
			tx: device.tx + if strike.snap_x { f32(0.5) } else { glyph_subpixel_round }
			ty: device.ty + if strike.snap_y { f32(0.5) } else { glyph_subpixel_round }
		}
		for index in 0 .. run.glyphs.len {
			if batch.jobs.len == glyph_frame_prefetch_jobs { break }
			point := map_point_affine(rounding,
				Point{run.positions[index * 2], run.positions[index * 2 + 1]})
			if !is_finite_f32(point.x) || !is_finite_f32(point.y) { continue }
			glyph := glyph_mask_key_at_position(run.glyphs[index], &strike, point)
			if glyph in owner.keys || (entry != unsafe { nil } && glyph in entry.glyphs) { continue }
			owner.keys[glyph] = true
			batch.jobs << GlyphFrameJob{slot: slot, image: GlyphImageJob{key: glyph}}
		}
	}

	// The batch owns its CoreText strikes and carries no borrowed cache entry
	// across replay. Even an unused batch must be joined before scratch resets.
	pub fn start_glyph_frame_prefetch(cache &GlyphCache, runs []GlyphFramePrefetchRun) voidptr {
		if runs.len == 0 || serial_glyph_masks || C.vox_scan_workers_disabled() { return unsafe { nil } }
		mut batch := &GlyphFrameWork{
			strikes: []GlyphFrameStrike{cap: glyph_frame_prefetch_strikes}
			jobs: []GlyphFrameJob{cap: glyph_frame_prefetch_jobs}
		}
		for run_spec in runs {
			batch.collect(run_spec, cache)
			if batch.jobs.len == glyph_frame_prefetch_jobs { break }
		}
		ticket, lanes := start_background_raster_ranges(batch, batch.jobs.len, batch.jobs.len / 4,
			draw_glyph_frame_jobs)
		if ticket == unsafe { nil } {
			for mut slot in batch.strikes { slot.strike.release() }
			return unsafe { nil }
		}
		batch.ticket = ticket
		batch.lanes = lanes
		if glyph_frame_prefetch_diagnostics { batch.owner_start = time.sys_mono_now() }
		return batch
	}

	pub fn finish_glyph_frame_prefetch(context voidptr, cache &GlyphCache) {
		if context == unsafe { nil } { return }
		mut batch := unsafe { &GlyphFrameWork(context) }
		before_join := if glyph_frame_prefetch_diagnostics { time.sys_mono_now() } else { u64(0) }
		ready := join_background_raster_range(batch.ticket)
		mut published := 0
		for slot_index, mut slot in batch.strikes {
			slot.strike.release()
			mut entry := if cache != unsafe { nil } { glyph_cache_strike(cache, slot.key) }
				else { unsafe { &CachedGlyphStrike(nil) } }
			if entry != unsafe { nil } { glyph_cache_enter(entry.owner) }
			for job in batch.jobs {
				if job.slot != slot_index || !job.image.ready { continue }
				if entry != unsafe { nil } && job.image.key !in entry.glyphs {
					entry.publish_glyph_image(job.image)
					published++
				} else if job.image.mask != unsafe { nil } {
					C.free(job.image.mask)
				}
			}
			if entry != unsafe { nil } { glyph_cache_leave(entry.owner) }
		}
		if glyph_frame_prefetch_diagnostics {
			overlap := batch.jobs.count(it.image.rendered > batch.owner_start && it.image.started < before_join)
			eprintln('VOX_GLYPH_FRAME_PREFETCH jobs=${batch.jobs.len} strikes=${batch.strikes.len} lanes=${batch.lanes} published=${published} ready_at_join=${ready} owner_overlap=${overlap}')
		}
	}
}
