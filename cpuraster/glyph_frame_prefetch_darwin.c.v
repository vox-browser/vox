module cpuraster

import math
import os
import time

$if !cpuraster_freetype ? {
	const glyph_frame_prefetch_diagnostics = os.getenv('VOX_GLYPH_FRAME_PREFETCH_DIAGNOSTICS') == '1'
	const sync_glyph_frame_planning = os.getenv('VOX_SYNC_FRAME_GLYPH_PLANNING') == '1'
	const sync_glyph_frame_strikes = os.getenv('VOX_SYNC_FRAME_GLYPH_STRIKES') == '1'
	const glyph_frame_prefetch_strikes = 4
	const glyph_frame_prefetch_jobs = 128

	pub struct GlyphFramePrefetchRun {
	pub:
		run       CanvasGlyphRun
		transform [6]f32
		color     u32
	}

	struct GlyphFrameStrikeSpec {
		path string
		index int
		size f32
		device SkAffine
		smooth int
		luminance int
	}

	// Compare the same strike inputs as glyph_strike_key. Keep the original
	// device transform for publication, with translation omitted from equality.
	fn (spec GlyphFrameStrikeSpec) matches(other GlyphFrameStrikeSpec) bool {
		return spec.path == other.path && spec.index == other.index
			&& math.f32_bits(spec.size) == math.f32_bits(other.size)
			&& math.f32_bits(spec.device.sx) == math.f32_bits(other.device.sx)
			&& math.f32_bits(spec.device.kx) == math.f32_bits(other.device.kx)
			&& math.f32_bits(spec.device.ky) == math.f32_bits(other.device.ky)
			&& math.f32_bits(spec.device.sy) == math.f32_bits(other.device.sy)
			&& spec.smooth == other.smooth && spec.luminance == other.luminance
	}

	fn (spec GlyphFrameStrikeSpec) cache_key(face_key string, strike &GlyphStrike) string {
		return glyph_strike_key(face_key + '\x00chromium', spec.size, spec.device, strike,
			spec.smooth, spec.luminance)
	}

	struct GlyphFrameStrike {
	mut:
		spec GlyphFrameStrikeSpec
		key string
		cached map[u32]bool
		strike GlyphStrike
		// A frame admits at most 128 keys across all strikes. Keep this
		// table at no more than half full without growing it on a worker.
		keys [256]u32
	}

	struct GlyphFrameRunPlan {
		slot int
		glyphs []u16
		positions []f32
		rounding SkAffine
	}

	struct GlyphFrameJob {
		slot int
	mut:
		image GlyphImageJob
	}

	@[heap]
	struct GlyphFrameWork {
		input []GlyphFramePrefetchRun
	mut:
		strikes      []GlyphFrameStrike
		strike_count int
		template     GlyphStrike
		runs         []GlyphFrameRunPlan
		jobs         []GlyphFrameJob
		job_count    int
		ticket       voidptr
		lanes        int
		owner_start  u64
		has_cold_strike bool
		prepare_strikes bool
		planner_thread u64
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
		color := run_spec.color
		alpha := if precise := run.paint_color { fmin(fmax(precise[3], 0), 1) }
			else { canvas_paint_alpha(color, 1) }
		luminance := paint_luminance(color, alpha, none, none)
		mut strike := unsafe { &batch.template }
		if !strike.set_template(run.font_size, device, luminance) { return }
		strike.snap_y = run.baseline_snap && sk_relax(device.ky) == 0
		strike.snap_x = run.baseline_snap && !strike.snap_y && sk_relax(device.sx) == 0
		strike.smoothing = run.smoothing
		smooth := select_glyph_mask_gamma(mut strike, run, color, alpha, none, none, luminance)
		spec := GlyphFrameStrikeSpec{run.font_path, run.face_index, run.font_size, device,
			smooth, luminance}
		mut slot := -1
		for index in 0 .. batch.strike_count {
			planned := unsafe { &batch.strikes[index] }
			if planned.strike.snap_x == strike.snap_x && planned.strike.snap_y == strike.snap_y
				&& planned.strike.smoothing == strike.smoothing && planned.spec.matches(spec) {
				slot = index
				break
			}
		}
		if slot < 0 {
			if batch.strike_count >= glyph_frame_prefetch_strikes { return }
			mut lazy := LazyGlyphFace{path: run.font_path, index: run.face_index}
			defer { lazy.release() }
			mut planned := unsafe { &batch.strikes[batch.strike_count] }
			mut face_key := ''
			if cache == unsafe { nil } {
				face := lazy.get() or { return }
				if face.color_glyphs { return }
			} else {
				face_key = glyph_face_key(spec.path, spec.index)
				info := glyph_face_info(cache, face_key, mut lazy) or { return }
				if info.color_glyphs { return }
			}
			planned.strike = *strike
			if !planned.strike.ensure_font(mut lazy) { return }
			if cache != unsafe { nil } {
				planned.key = spec.cache_key(face_key, strike)
				if entry := cache.strikes[planned.key] {
					planned.cached = map[u32]bool{}
					for glyph, _ in entry.glyphs { planned.cached[glyph] = true }
				}
			}
			planned.spec = spec
			batch.has_cold_strike = batch.has_cold_strike || planned.cached.len == 0
			slot = batch.strike_count
			batch.strike_count++
		}
		rounding := SkAffine{
			...device
			tx: device.tx + if strike.snap_x { f32(0.5) } else { glyph_subpixel_round }
			ty: device.ty + if strike.snap_y { f32(0.5) } else { glyph_subpixel_round }
		}
		batch.runs << GlyphFrameRunPlan{slot: slot, glyphs: run.glyphs,
			positions: run.positions, rounding: rounding}
	}

	fn (mut slot GlyphFrameStrike) schedule_key(key u32) bool {
		if key in slot.cached { return false }
		// Glyph keys occupy 20 bits. Reserve zero for an empty slot.
		stored := key + 1
		mut index := int(((key >> 4) ^ (key << 4)) & 255)
		for slot.keys[index] != 0 {
			if slot.keys[index] == stored { return false }
			index = (index + 1) & 255
		}
		slot.keys[index] = stored
		return true
	}

	fn (mut batch GlyphFrameWork) plan_keys() {
		if glyph_frame_prefetch_diagnostics {
			C.pthread_threadid_np(unsafe { nil }, &batch.planner_thread)
		}
		for run in batch.runs {
			mut slot := &batch.strikes[run.slot]
			for index, id in run.glyphs {
				if batch.job_count == glyph_frame_prefetch_jobs { return }
				point := map_point_affine(run.rounding,
					Point{run.positions[index * 2], run.positions[index * 2 + 1]})
				if !is_finite_f32(point.x) || !is_finite_f32(point.y) { continue }
				glyph := glyph_mask_key_at_position(id, &slot.strike, point)
				if !slot.schedule_key(glyph) { continue }
				batch.jobs[batch.job_count] = GlyphFrameJob{slot: run.slot, image: GlyphImageJob{key: glyph}}
				batch.job_count++
			}
		}
	}

	fn plan_and_draw_glyph_frame(context voidptr, _ i32, _ i32) {
		mut batch := unsafe { &GlyphFrameWork(context) }
		if batch.prepare_strikes {
			for index in 0 .. batch.input.len {
				batch.collect(unsafe { &batch.input[index] }, unsafe { nil })
			}
		}
		batch.plan_keys()
		if batch.job_count >= 8 {
			batch.lanes = run_raster_ranges(batch, batch.job_count, batch.job_count / 4,
				draw_glyph_frame_jobs)
		}
	}

	// The batch owns its CoreText strikes and carries no borrowed cache entry
	// across replay. Even an unused batch must be joined before scratch resets.
	pub fn start_glyph_frame_prefetch(cache &GlyphCache, runs []GlyphFramePrefetchRun) voidptr {
		if cache == unsafe { nil } || runs.len == 0 || serial_glyph_masks || C.vox_scan_workers_disabled() {
			return unsafe { nil }
		}
		mut batch := &GlyphFrameWork{
			input: runs
			strikes: []GlyphFrameStrike{len: glyph_frame_prefetch_strikes}
			runs: []GlyphFrameRunPlan{cap: runs.len}
			jobs: []GlyphFrameJob{len: glyph_frame_prefetch_jobs}
		}
		// With no cached strikes the worker needs only the immutable runs.
		// Slot storage and the run plan are allocated before dispatch.
		if cache.strikes.len == 0 && !sync_glyph_frame_strikes && !sync_glyph_frame_planning {
			batch.prepare_strikes = true
			batch.ticket = start_background_raster_range(batch, 1, plan_and_draw_glyph_frame)
		}
		if batch.ticket == unsafe { nil } {
			batch.prepare_strikes = false
			for index in 0 .. runs.len {
				batch.collect(unsafe { &runs[index] }, cache)
			}
			if batch.has_cold_strike && !sync_glyph_frame_planning {
				batch.ticket = start_background_raster_range(batch, 1, plan_and_draw_glyph_frame)
			}
		}
		if batch.ticket == unsafe { nil } {
			// Warm frames can detect an empty plan without waking a worker.
			batch.plan_keys()
			ticket, lanes := start_background_raster_ranges(batch, batch.job_count,
				batch.job_count / 4, draw_glyph_frame_jobs)
			batch.ticket = ticket
			batch.lanes = lanes
		}
		if batch.ticket == unsafe { nil } {
			for index in 0 .. batch.strike_count { batch.strikes[index].strike.release() }
			return unsafe { nil }
		}
		if glyph_frame_prefetch_diagnostics { batch.owner_start = time.sys_mono_now() }
		return batch
	}

	pub fn finish_glyph_frame_prefetch(context voidptr, cache &GlyphCache) {
		if context == unsafe { nil } { return }
		mut batch := unsafe { &GlyphFrameWork(context) }
		before_join := if glyph_frame_prefetch_diagnostics { time.sys_mono_now() } else { u64(0) }
		ready := join_background_raster_range(batch.ticket)
		mut published := 0
		for slot_index in 0 .. batch.strike_count {
			mut slot := unsafe { &batch.strikes[slot_index] }
			slot.strike.release()
			mut entry := unsafe { &CachedGlyphStrike(nil) }
			for job in batch.jobs[..batch.job_count] {
				if job.slot != slot_index || !job.image.ready { continue }
				if entry == unsafe { nil } && cache != unsafe { nil } {
					key := if batch.prepare_strikes {
						face_key := glyph_face_key(slot.spec.path, slot.spec.index)
						slot.spec.cache_key(face_key, &slot.strike)
					} else { slot.key }
					entry = glyph_cache_strike(cache, key)
					glyph_cache_enter(entry.owner)
				}
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
			overlap := batch.jobs[..batch.job_count].count(it.image.rendered > batch.owner_start && it.image.started < before_join)
			mut caller := u64(0)
			C.pthread_threadid_np(unsafe { nil }, &caller)
			planned_off_thread := batch.planner_thread != 0 && batch.planner_thread != caller
			eprintln('VOX_GLYPH_FRAME_PREFETCH jobs=${batch.job_count} strikes=${batch.strike_count} lanes=${batch.lanes} published=${published} ready_at_join=${ready} owner_overlap=${overlap} planned_off_thread=${planned_off_thread} strikes_off_thread=${batch.prepare_strikes && planned_off_thread}')
		}
	}
}
