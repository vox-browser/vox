module cpuraster

import math
import os
import runtime

struct TestGlyphBackdrop {
	pixels []u8
	caller u64
	decline bool
mut:
	calls int
}

fn read_test_glyph_backdrop(context voidptr) bool {
	mut backdrop := unsafe { &TestGlyphBackdrop(context) }
	mut current := u64(0)
	C.pthread_threadid_np(unsafe { nil }, &current)
	assert current == backdrop.caller
	backdrop.calls++
	if backdrop.decline { return false }
	unsafe { C.memset(backdrop.pixels.data, 255, backdrop.pixels.len) }
	return true
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
			0, rounding)
		assert entry.glyphs.len >= glyph_batch_min
		mut bytes := 0
		for key, parallel in entry.glyphs {
			serial := strike.make_glyph(u16(key >> 4), int((key >> 2) & 3), int(key & 3))
			assert parallel == serial
			bytes += parallel.image.len
		}
		assert bytes == entry.bytes
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

		// Replay can cache a glyph before frame publication. Keep that mask and
		// publish only the missing masks from the worker-owned batch.
		mut growing_cache := new_glyph_cache()
		pending := start_glyph_frame_prefetch(growing_cache, expect)
		assert pending != unsafe { nil }
		mut before_join := []u8{len: serial.len, init: 255}
		assert fill_canvas_glyphs_cached(mut growing_cache, mut before_join, 256, 48, 1024,
			2, run, transform, 0xff123456, none, 1, .src_over, [], none)
		first_key := growing_cache.order[0]
		mut used_before_join := map[u32]StrikeGlyph{}
		for key, glyph in growing_cache.strikes[first_key].glyphs { used_before_join[key] = glyph }
		finish_glyph_frame_prefetch(pending, growing_cache)
		assert before_join == serial
		for key, glyph in used_before_join {
			retained := growing_cache.strikes[first_key].glyphs[key]
			assert voidptr(glyph.image.data) == voidptr(retained.image.data)
		}
		assert start_glyph_frame_prefetch(growing_cache, expect) == unsafe { nil }

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
		for pipeline in [false, true] {
			mut deferred := []u8{len: serial.len}
			mut backdrop := TestGlyphBackdrop{pixels: deferred, caller: caller}
			mut cache := new_glyph_cache()
			assert fill_canvas_glyphs_cached(mut cache, mut deferred, 256, 48, 1024, 2, run,
				transform, 0xff123456, none, 1, .src_over, [], none,
				context: &backdrop, read: read_test_glyph_backdrop, pipeline_masks: pipeline)
			assert backdrop.calls == 1
			assert serial == deferred

			mut rejected := []u8{len: serial.len}
			mut failing := TestGlyphBackdrop{pixels: rejected, caller: caller, decline: true}
			mut empty_cache := new_glyph_cache()
			assert !fill_canvas_glyphs_cached(mut empty_cache, mut rejected, 256, 48, 1024, 2, run,
				transform, 0xff123456, none, 1, .src_over, [], none,
				context: &failing, read: read_test_glyph_backdrop, pipeline_masks: pipeline)
			assert failing.calls == 1
			assert rejected.all(it == 0)
			assert empty_cache.strikes.values().all(it.glyphs.len == 0)
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
