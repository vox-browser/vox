module cpuraster

import math
import os
import runtime

struct TestGlyphBackdrop {
	pixels []u8
	caller u64
	decline bool
	prepared_cache &GlyphCache = unsafe { nil }
mut:
	calls int
}

fn read_test_glyph_backdrop(context voidptr) bool {
	mut backdrop := unsafe { &TestGlyphBackdrop(context) }
	mut current := u64(0)
	C.pthread_threadid_np(unsafe { nil }, &current)
	assert current == backdrop.caller
	assert backdrop.pixels.all(it == 0)
	if backdrop.prepared_cache != unsafe { nil } {
		assert backdrop.prepared_cache.strikes.values().any(it.glyphs.len > 0)
	}
	backdrop.calls++
	if backdrop.decline { return false }
	unsafe { C.memset(backdrop.pixels.data, 255, backdrop.pixels.len) }
	return true
}

fn test_mask_batch_loads_backdrop_once_across_flushes() {
	mut pixels := []u8{len: 4}
	mut caller := u64(0)
	assert C.pthread_threadid_np(unsafe { nil }, &caller) == 0
	mut backdrop := TestGlyphBackdrop{pixels: pixels, caller: caller}
	mut batch := GlyphMaskBatch{
		backdrop: CanvasGlyphBackdrop{context: &backdrop, read: read_test_glyph_backdrop}
	}
	mut blitter := Blitter(new_pipeline_blitter(mut pixels, 4, 0xff123456, 1, .src_over))
	assert batch.flush(mut blitter)
	assert backdrop.calls == 0
	clip := IRect{0, 0, 1, 1}
	mask := Mask{bounds: clip, row_bytes: 1, image: [u8(255)]}
	for _ in 0 .. 2 {
		batch.add(mask, clip)
		assert batch.flush(mut blitter)
		assert backdrop.calls == 1
		assert pixels == [u8(0x12), 0x34, 0x56, 0xff]
	}
}

fn test_glyph_mask_converts_padded_bitmap_in_place() {
	width, height := 5, 3
	pitch, rows := 8, 4
	mut pixels := []u32{len: pitch * rows, init: 0xff000000 | u32(index) * 0x030303}
	expected := []u8{len: width * height, init: u8(255 - 3 * (pitch + index / width * pitch + index % width))}
	strike := GlyphStrike{ table: identity_mask_gamma_table.clone() }
	mut separate := []u8{len: expected.len}
	strike.write_glyph_mask(pixels.data, separate.data, width, height, pitch, rows)
	assert separate == expected
	strike.write_glyph_mask(pixels.data, pixels.data, width, height, pitch, rows)
	for index, value in expected {
		assert unsafe { (&u8(pixels.data))[index] } == value
	}
}

fn test_prepared_glyph_masks_match_serial_at_subpixel_origins() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 { return }
		previous := os.getenv_opt('VOX_SERIAL_CPU_RASTER')
		defer {
			if value := previous {
				os.setenv('VOX_SERIAL_CPU_RASTER', value, true)
			} else {
				os.unsetenv('VOX_SERIAL_CPU_RASTER')
			}
		}
		os.unsetenv('VOX_SERIAL_CPU_RASTER')
		run := CanvasGlyphRun{
			font_path:         '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'
			font_size:         26.66
			glyphs:            [u16(43), 68, 70, 78, 72, 85, 3, 49, 72, 90, 86, 43]
			positions:         [f32(221.20312), 50, 243.52826, 50, 261.3363, 50, 277.02246, 50,
				294.90863, 50, 312.61252, 50, 325.8644, 50, 334.9767, 50, 357.5492, 50, 375.2531,
				50, 401.36633, 50, 221.20312, 50]
			retained:          true
			chromium_coverage: true
			baseline_snap:     true
		}
		device := SkAffine{ sx: 1, sy: 1, tx: -202, ty: -18 }
		mut strike := glyph_strike_template(run.font_size, device, 0) or { panic('invalid strike') }
		defer { strike.release() }
		strike.snap_y = true
		strike.table = identity_mask_gamma_table
		mut lazy := LazyGlyphFace{ path: run.font_path }
		defer { lazy.release() }
		mut entry := CachedGlyphStrike{}
		rounding := SkAffine{ ...device, tx: device.tx + glyph_subpixel_round, ty: device.ty + 0.5 }
		entry.prepare_glyph_masks(mut strike, mut lazy, run, []GlyphRoute{len: run.glyphs.len},
			0, rounding, false, false)
		assert entry.glyphs.len >= glyph_batch_min
		mut bytes := 0
		for key, parallel in entry.glyphs {
			serial := strike.make_glyph(u16(key >> 4), int((key >> 2) & 3), int(key & 3))
			assert parallel == serial
			bytes += parallel.image.len
		}
		assert bytes == entry.bytes
		routes := []GlyphRoute{len: run.glyphs.len}
		mut streamed_entry := CachedGlyphStrike{}
		_, abandoned := streamed_entry.prepare_glyph_masks(mut strike, mut lazy, run, routes,
			0, rounding, false, true)
		assert abandoned != unsafe { nil }
		assert streamed_entry.glyphs.len == 0
		first_mask_key := glyph_run_mask_key(run, &strike, rounding, 0)
		streamed_entry.consume_streamed_glyph_mask(abandoned, first_mask_key)
		assert streamed_entry.glyphs.len == 1
		assert streamed_entry.glyphs[first_mask_key] == entry.glyphs[first_mask_key]
		finish_streamed_glyph_masks(abandoned)
		assert streamed_entry.glyphs.len == 1

		_, stream := streamed_entry.prepare_glyph_masks(mut strike, mut lazy, run, routes,
			0, rounding, false, true)
		assert stream != unsafe { nil }
		for i in 0 .. run.glyphs.len {
			streamed_entry.consume_streamed_glyph_mask(stream, glyph_run_mask_key(run, &strike,
				rounding, i))
		}
		finish_streamed_glyph_masks(stream)
		assert streamed_entry.glyphs == entry.glyphs
		assert streamed_entry.bytes == bytes
		// The full draw still composites repeated and overlapping glyphs in order.
		mut serial := []u8{len: 256 * 48 * 4, init: 255}
		mut parallel := serial.clone()
		transform := [f32(1), 0, 0, 1, -202, -18]!
		os.setenv('VOX_SERIAL_CPU_RASTER', '1', true)
		assert fill_canvas_glyphs(mut serial, 256, 48, 1024, 2, run, transform, 0xff123456, none,
			1, .src_over, [], none)
		os.unsetenv('VOX_SERIAL_CPU_RASTER')
		assert fill_canvas_glyphs(mut parallel, 256, 48, 1024, 2, run, transform, 0xff123456, none,
			1, .src_over, [], none)
		assert serial == parallel

		mut prefetched_cache := new_glyph_cache()
		other := CanvasGlyphRun{...run, font_size: 16}
		expect := [
			GlyphFramePrefetchRun{run: run, transform: transform, color: 0xff123456},
			GlyphFramePrefetchRun{run: other, transform: transform, color: 0xff123456},
		]
		prefetch := start_glyph_frame_prefetch(prefetched_cache, expect)
		assert prefetch != unsafe { nil }
		assert prefetched_cache.strikes.len == 0
		finish_glyph_frame_prefetch(prefetch, prefetched_cache)
		assert prefetched_cache.strikes.len == 2
		assert prefetched_cache.strikes.values().all(it.glyphs.len >= glyph_batch_min)
		assert start_glyph_frame_prefetch(prefetched_cache, expect) == unsafe { nil }
		mut prefetched := []u8{len: serial.len, init: 255}
		assert fill_canvas_glyphs_cached(mut prefetched_cache, mut prefetched, 256, 48, 1024,
			2, run, transform, 0xff123456, none, 1, .src_over, [], none)
		assert prefetched == serial

		native_positions := []f64{len: run.positions.len, init: f64(run.positions[index]) + 0.015625}
		origin := [f32(0.375), f32(-0.125)]!
		mut folded := []f32{len: native_positions.len}
		prepare_retained_glyph_positions(native_positions, mut folded, origin[0], origin[1], true)
		prepared_run := GlyphFramePrefetchRun{...expect[0], run: CanvasGlyphRun{...run, positions: folded}}
		raw_run := GlyphFramePrefetchRun{
			...expect[0]
			run: CanvasGlyphRun{...run, positions: []f32{}}
			raw_positions: native_positions
			raw_origin: origin
			fold_origin: true
		}
		prepared_cache := new_glyph_cache()
		raw_cache := new_glyph_cache()
		finish_glyph_frame_prefetch(start_glyph_frame_prefetch(prepared_cache, [prepared_run]), prepared_cache)
		finish_glyph_frame_prefetch(start_glyph_frame_prefetch(raw_cache, [raw_run]), raw_cache)
		assert raw_cache.strikes.len == prepared_cache.strikes.len && raw_cache.strikes.len == 1
		for key, expected in prepared_cache.strikes {
			actual := raw_cache.strikes[key] or { panic('missing raw position strike') }
			assert actual.glyphs == expected.glyphs
		}
		assert start_glyph_frame_prefetch(raw_cache, [raw_run]) == unsafe { nil }

		mut split_cache := new_glyph_cache()
		if glyph_frame_prefetch_can_split(split_cache) {
			wave_runs := [expect[0], expect[0], expect[1]]
			waves := start_glyph_frame_prefetch(split_cache, wave_runs, front_runs: 1, tail_command: 64)
			assert advance_glyph_frame_prefetch(waves, split_cache, 0) == 64
			assert split_cache.strikes.len == 1
			batch := unsafe { &GlyphFrameWork(waves) }
			assert batch.front_jobs * 2 == batch.job_count
			assert advance_glyph_frame_prefetch(waves, split_cache, 63) == 64
			assert split_cache.strikes.len == 1
			assert advance_glyph_frame_prefetch(waves, split_cache, 64) == -1
			assert split_cache.strikes.len == 2
			mut expected_tail := []u8{len: serial.len, init: 255}
			mut actual_tail := expected_tail.clone()
			assert fill_canvas_glyphs(mut expected_tail, 256, 48, 1024, 2, other, transform,
				0xff123456, none, 1, .src_over, [], none)
			assert fill_canvas_glyphs_cached(mut split_cache, mut actual_tail, 256, 48, 1024, 2, other,
				transform, 0xff123456, none, 1, .src_over, [], none)
			assert actual_tail == expected_tail

			discard_cache := new_glyph_cache()
			unused := start_glyph_frame_prefetch(discard_cache, expect, front_runs: 1, tail_command: 64)
			assert advance_glyph_frame_prefetch(unused, discard_cache, 0) == 64
			finish_glyph_frame_prefetch(unused, unsafe { nil })
			assert discard_cache.strikes.len == 1

			skipped_cache := new_glyph_cache()
			skipped := start_glyph_frame_prefetch(skipped_cache, expect, front_runs: 1, tail_command: 64)
			assert advance_glyph_frame_prefetch(skipped, skipped_cache, 64) == -1
			assert skipped_cache.strikes.len == 2
		}

		// Replay can cache a glyph before frame publication. Keep that mask and
		// publish only the missing masks from the worker-owned batch.
		mut growing_cache := new_glyph_cache()
		pending := start_glyph_frame_prefetch(growing_cache, expect)
		assert pending != unsafe { nil }
		mut before_join := []u8{len: serial.len, init: 255}
		assert fill_canvas_glyphs_cached(mut growing_cache, mut before_join, 256, 48, 1024,
			2, run, transform, 0xff123456, none, 1, .src_over, [], none)
		first_key := growing_cache.order[0]
		first_strike := growing_cache.strikes[first_key] or { panic('missing replay strike') }
		mut used_before_join := map[u32]StrikeGlyph{}
		for key, glyph in first_strike.glyphs { used_before_join[key] = glyph }
		finish_glyph_frame_prefetch(pending, growing_cache)
		assert before_join == serial
		retained_strike := growing_cache.strikes[first_key] or { panic('lost replay strike') }
		for key, glyph in used_before_join {
			retained := retained_strike.glyphs[key] or { panic('lost replay mask') }
			assert voidptr(glyph.image.data) == voidptr(retained.image.data)
		}
		assert start_glyph_frame_prefetch(growing_cache, expect) == unsafe { nil }

		// An unavailable early face must leave room for all four usable
		// strikes, including one beyond the first four candidates.
		missing := CanvasGlyphRun{...run, font_path: '/nonexistent/vox-frame-prefetch-test.ttf'}
		with_missing := [
			GlyphFramePrefetchRun{...expect[0], run: missing},
			expect[0],
			expect[1],
			GlyphFramePrefetchRun{...expect[0], run: CanvasGlyphRun{...run, font_size: 17}},
			GlyphFramePrefetchRun{...expect[0], run: CanvasGlyphRun{...run, font_size: 18}},
		]
		fallback_cache := new_glyph_cache()
		fallback := start_glyph_frame_prefetch(fallback_cache, with_missing)
		assert fallback != unsafe { nil }
		finish_glyph_frame_prefetch(fallback, fallback_cache)
		assert fallback_cache.strikes.len == glyph_frame_prefetch_strikes
		assert start_glyph_frame_prefetch(fallback_cache, with_missing) == unsafe { nil }

		finite_keys_only := new_glyph_cache()
		invalid_positions := []f32{len: run.positions.len, init: f32(math.nan())}
		invalid := start_glyph_frame_prefetch(finite_keys_only, [
			GlyphFramePrefetchRun{run: run, transform: [f32(1), 0, 0, 1, f32(math.inf(1)), 0]!,
				color: 0xff123456},
			GlyphFramePrefetchRun{run: CanvasGlyphRun{...run, positions: invalid_positions},
				transform: transform, color: 0xff123456},
		])
		finish_glyph_frame_prefetch(invalid, finite_keys_only)
		assert finite_keys_only.strikes.len == 0

		mut caller := u64(0)
		C.pthread_threadid_np(unsafe { nil }, &caller)
		for mode in [CanvasGlyphBackdrop{}, CanvasGlyphBackdrop{pipeline_masks: true},
			CanvasGlyphBackdrop{copy_pending: true}] {
			late := late_glyph_backdrop_join && mode.copy_pending && !serial_glyph_blend
			mut deferred := []u8{len: serial.len}
			mut cache := new_glyph_cache()
			mut backdrop := TestGlyphBackdrop{
				pixels: deferred
				caller: caller
				prepared_cache: if late { &cache } else { unsafe { nil } }
			}
			assert fill_canvas_glyphs_cached(mut cache, mut deferred, 256, 48, 1024, 2, run,
				transform, 0xff123456, none, 1, .src_over, [], none,
				CanvasGlyphBackdrop{...mode, context: &backdrop, read: read_test_glyph_backdrop})
			assert backdrop.calls == 1
			assert serial == deferred

			mut rejected := []u8{len: serial.len}
			mut failing := TestGlyphBackdrop{pixels: rejected, caller: caller, decline: true}
			mut empty_cache := new_glyph_cache()
			assert !fill_canvas_glyphs_cached(mut empty_cache, mut rejected, 256, 48, 1024, 2, run,
				transform, 0xff123456, none, 1, .src_over, [], none,
				CanvasGlyphBackdrop{...mode, context: &failing, read: read_test_glyph_backdrop})
			assert failing.calls == 1
			assert rejected.all(it == 0)
			assert empty_cache.strikes.values().all(it.glyphs.len == 0) == !late
		}

		mut culled := []u8{len: serial.len}
		mut unread := TestGlyphBackdrop{pixels: culled, caller: caller, decline: true}
		mut empty_cache := new_glyph_cache()
		assert fill_canvas_glyphs_cached(mut empty_cache, mut culled, 256, 48, 1024, 2, run,
			[f32(1), 0, 0, 1, -1200, -18]!, 0xff123456, none, 1, .src_over, [], none,
			context: &unread, read: read_test_glyph_backdrop, pipeline_masks: true)
		assert unread.calls == 0
		assert culled.all(it == 0)
		assert empty_cache.strikes.values().all(it.glyphs.len == 0)
	}
}

fn test_cold_glyph_masks_prefer_the_shorter_caller_range() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 || glyph_mask_dispatch_apply || C.vox_scan_workers_disabled() { return }
		mut lazy := LazyGlyphFace{path: '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'}
		defer { lazy.release() }
		mut strike := glyph_strike_template(24, SkAffine{}, 0) or { panic('invalid strike') }
		defer { strike.release() }
		assert strike.ensure_font(mut lazy)
		strike.table = identity_mask_gamma_table
		glyphs := [u16(43), 44, 68, 70, 72]
		mut caller := u64(0)
		assert C.pthread_threadid_np(unsafe { nil }, &caller) == 0
		for count in [3, 4, 5] {
			mut batch := GlyphImageBatch{
				strike:      &strike
				diagnostics: true
				jobs:        glyphs[..count].map(GlyphImageJob{key: packed_glyph_key(it, 1, 0)})
			}
			assert batch.draw()
			mut entry := CachedGlyphStrike{}
			entry.publish_glyph_image_batch(&batch)
			assert entry.glyphs.len == count
			caller_first := !glyph_mask_caller_last && count % 2 != 0
			for index, job in batch.jobs {
				assert job.thread != 0
				on_caller := if caller_first { index < count / 2 } else { index >= count / 2 }
				assert (job.thread == caller) == on_caller
				glyph := entry.glyphs[job.key] or { panic('missing batch glyph') }
				assert glyph.image.len > 0
				assert glyph == strike.make_glyph(u16(job.key >> 4), 1, 0)
			}
		}
	}
}

fn test_short_retained_glyph_mask_batches_match_serial_masks() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 || serial_glyph_masks || C.vox_scan_workers_disabled() { return }
		for count in [2, 3] {
			run := CanvasGlyphRun{
				font_path:         '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'
				font_size:         24
				glyphs:            [u16(43), 68, 70][..count]
				positions:         [f32(4.25), 28, 11.5, 28, 20.75, 28][..2 * count]
				retained:          true
				chromium_coverage: true
				baseline_snap:     true
			}
			mut strike := glyph_strike_template(run.font_size, SkAffine{}, 0) or { panic('invalid strike') }
			defer { strike.release() }
			strike.snap_y = true
			strike.table = identity_mask_gamma_table
			mut lazy := LazyGlyphFace{path: run.font_path}
			defer { lazy.release() }
			mut entry := CachedGlyphStrike{}
			rounding := SkAffine{tx: glyph_subpixel_round, ty: 0.5}
			next, _ := entry.prepare_glyph_masks(mut strike, mut lazy, run,
				[]GlyphRoute{len: count}, 0, rounding, false, false)
			assert next == count
			assert entry.glyphs.len == if glyph_mask_batch_min_four { 0 } else { count }
			for key, glyph in entry.glyphs {
				assert glyph.image.len > 0
				assert glyph == strike.make_glyph(u16(key >> 4), int((key >> 2) & 3), int(key & 3))
			}
		}
	}
}

fn test_later_glyph_mask_windows_use_workers_and_match_serial_pixels() {
	$if !cpuraster_freetype ? {
		if runtime.nr_cpus() < 2 || serial_glyph_masks || C.vox_scan_workers_disabled() { return }
		count := glyph_batch_lookahead + 25
		run := CanvasGlyphRun{
			font_path: '/System/Library/Fonts/Supplemental/Verdana Bold.ttf'
			font_size: 16
			glyphs: []u16{len: count, init: if index < glyph_batch_lookahead { u16(43) } else { u16(44 + index - glyph_batch_lookahead) }}
			positions: []f32{len: 2 * count, init: if index % 2 == 0 { f32(8 + 4 * (index / 2)) } else { f32(25) }}
			retained: true
			chromium_coverage: true
			baseline_snap: true
		}
		mut strike := glyph_strike_template(run.font_size, SkAffine{}, 0) or { panic('invalid strike') }
		defer { strike.release() }
		strike.snap_y = true
		mut lazy := LazyGlyphFace{path: run.font_path}
		defer { lazy.release() }
		mut entry := CachedGlyphStrike{}
		routes := []GlyphRoute{len: count}
		rounding := SkAffine{tx: glyph_subpixel_round, ty: 0.5}
		first, _ := entry.prepare_glyph_masks(mut strike, mut lazy, run, routes, 0, rounding, false, false)
		assert entry.glyphs.len == 0
		if single_glyph_mask_batch {
			assert first == count
		} else {
			assert first == glyph_batch_lookahead
			second, _ := entry.prepare_glyph_masks(mut strike, mut lazy, run, routes, first, rounding, true, false)
			assert second == first + glyph_batch_max
			assert entry.glyphs.len == glyph_batch_max
			last, _ := entry.prepare_glyph_masks(mut strike, mut lazy, run, routes, second, rounding, true, false)
			assert last == count
			assert entry.glyphs.len == 25
		}

		mut parallel := []u8{len: 320 * 48 * 4, init: 255}
		mut serial := parallel.clone()
		transform := [f32(1), 0, 0, 1, 0, 0]!
		assert fill_canvas_glyphs(mut parallel, 320, 48, 1280, 2, run, transform, 0xff123456,
			none, 1, .src_over, [], none)
		os.setenv('VOX_SERIAL_CPU_RASTER', '1', true)
		defer { os.unsetenv('VOX_SERIAL_CPU_RASTER') }
		assert fill_canvas_glyphs(mut serial, 320, 48, 1280, 2, run, transform, 0xff123456,
			none, 1, .src_over, [], none)
		assert parallel == serial
	}
}
