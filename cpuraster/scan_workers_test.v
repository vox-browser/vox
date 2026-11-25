module cpuraster

import os
import platform
import runtime

const serial_cpu_raster = 'VOX_SERIAL_CPU_RASTER'

fn restore_serial_raster_setting(previous ?string) {
	if value := previous {
		assert os.setenv(serial_cpu_raster, value, true) == 0
	} else {
		assert os.unsetenv(serial_cpu_raster) == 0
	}
}

$if macos && !cpuraster_freetype ? {
	struct BackgroundRasterTestRange {
	mut:
		thread_id u64
		first     i32
		end       i32
	}

	fn record_background_raster_range(context voidptr, first i32, end i32) {
		mut range := unsafe { &BackgroundRasterTestRange(context) }
		C.pthread_threadid_np(unsafe { nil }, &range.thread_id)
		range.first = first
		range.end = end
	}

	fn test_submitted_raster_range_runs_on_a_worker() {
		if runtime.nr_cpus() < 2 { return }
		previous := os.getenv_opt(serial_cpu_raster)
		defer { restore_serial_raster_setting(previous) }
		assert os.unsetenv(serial_cpu_raster) == 0

		mut caller := u64(0)
		C.pthread_threadid_np(unsafe { nil }, &caller)
		mut range := BackgroundRasterTestRange{}
		ticket := start_background_raster_range(&range, 32, record_background_raster_range)
		assert ticket != unsafe { nil }
		join_background_raster_range(ticket)
		assert range.first == 0
		assert range.end == 32
		assert range.thread_id != 0 && range.thread_id != caller
	}

	struct JoinedRasterTestRanges {
	mut:
		thread_ids [37]u64
		first      [37]i32
	}

	fn record_joined_raster_range(context voidptr, first i32, end i32) {
		mut ranges := unsafe { &JoinedRasterTestRanges(context) }
		thread_id := platform.native_thread_identity()
		for index in int(first) .. int(end) {
			ranges.thread_ids[index] = thread_id
			ranges.first[index] = first
		}
	}

	fn test_joined_raster_ranges_cover_every_item_with_either_caller_range() {
		if runtime.nr_cpus() < 2 { return }
		previous := os.getenv_opt(serial_cpu_raster)
		defer { restore_serial_raster_setting(previous) }
		assert os.unsetenv(serial_cpu_raster) == 0

		caller := platform.native_thread_identity()
		for prefer_shorter in [false, true] {
			mut ranges := JoinedRasterTestRanges{}
			lanes := run_raster_ranges_with_caller(&ranges, ranges.thread_ids.len, 20,
				record_joined_raster_range, prefer_shorter_range: prefer_shorter)
			assert lanes == if runtime.nr_cpus() < 4 { runtime.nr_cpus() } else { 4 }
			caller_lane := if prefer_shorter { 0 } else { lanes - 1 }
			for lane in 0 .. lanes {
				first := ranges.thread_ids.len * lane / lanes
				end := ranges.thread_ids.len * (lane + 1) / lanes
				for index in first .. end {
					assert ranges.first[index] == first
					assert ranges.thread_ids[index] != 0
					assert (ranges.thread_ids[index] == caller) == (lane == caller_lane)
				}
			}
		}

		assert os.setenv(serial_cpu_raster, '1', true) == 0
		mut untouched := JoinedRasterTestRanges{}
		assert run_raster_ranges_with_caller(&untouched, untouched.thread_ids.len, 4,
			record_joined_raster_range) == 0
		assert untouched.thread_ids[0] == 0
		assert untouched.thread_ids[untouched.thread_ids.len - 1] == 0
	}

	fn test_joined_shaping_ranges_publish_exact_glyphs() {
		if runtime.nr_cpus() < 2 { return }
		previous := os.getenv_opt(serial_cpu_raster)
		defer { restore_serial_raster_setting(previous) }
		assert os.unsetenv(serial_cpu_raster) == 0

		font := &platform.Font{family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium}
		phrases := ['AV office  ', 'Private file choices', 'Words for line fitting', 'Keep both spaces  ',
			'First worker range', 'Second worker range', 'Third worker range', 'Browser thread tail']
		mut expected := [][]platform.Glyph{cap: phrases.len}
		mut whitespace := []platform.TrailingWhitespace{cap: phrases.len}
		for phrase in phrases {
			shaped := platform.shape_text_with_spacing(0, 0, 0, phrase, font, .ltr)
			expected << shaped.glyph_run.glyphs().clone()
			whitespace << shaped.trailing_whitespace
		}
		for background in [false, true] {
			platform.release_unused_text_shaping()
			jobs := platform.prepare_ascii_shape_jobs(phrases.map(platform.ASCIIShapeRequest{it, font}))
			assert jobs.len == phrases.len
			mut batch := if background {
				ticket, lanes := start_background_raster_ranges(jobs.data, jobs.len, 4,
					platform.shape_ascii_job_range)
				assert lanes >= 2 && ticket != unsafe { nil }
				platform.stage_ascii_shape_jobs(jobs,
					worker_ticket: ticket
					join_workers: join_background_raster_range
				)
			} else {
				assert run_raster_ranges_with_caller(jobs.data, jobs.len, 4, platform.shape_ascii_job_range) >= 2
				platform.stage_ascii_shape_jobs(jobs)
			}
			for index, phrase in phrases {
				shaped := platform.shape_text_with_spacing(0, 0, 0, phrase, font, .ltr)
				assert shaped.glyph_run.glyphs() == expected[index]
				assert shaped.trailing_whitespace == whitespace[index]
			}
			batch.finish()
		}
	}
}

fn test_large_image_blur_matches_serial_with_cropped_and_in_place_passes() {
	previous := os.getenv_opt(serial_cpu_raster)
	defer { restore_serial_raster_setting(previous) }

	width, height := 973, 587
	mut pixels := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			alpha := (x * 37 + y * 71) % 256
			offset := (y * width + x) * 4
			pixels[offset] = u8((x * 53 + y * 17) % 256 * alpha / 255)
			pixels[offset + 1] = u8((x * 11 + y * 67) % 256 * alpha / 255)
			pixels[offset + 2] = u8((x * 29 + y * 41) % 256 * alpha / 255)
			pixels[offset + 3] = u8(alpha)
		}
	}
	source := BlurImage{pixels, width, height}
	source_bounds := IRect{5, 9, width + 5, height + 9}
	destination := IRect{-3, 21, width - 7, height + 16}
	// Mixed kernels, both kernel orders, and each single-axis path.
	for sigmas in [[f32(1.4), 5.7]!, [f32(6.2), 1.9]!, [f32(0), 2.1]!, [f32(1.1), 0]!] {
		assert os.setenv(serial_cpu_raster, '1', true) == 0
		serial, serial_subset := blur_8888(sigmas[0], sigmas[1], source, source_bounds, destination)
		assert os.unsetenv(serial_cpu_raster) == 0
		parallel, parallel_subset := blur_8888(sigmas[0], sigmas[1], source, source_bounds,
			destination)
		assert parallel_subset == serial_subset
		assert parallel.width == serial.width
		assert parallel.height == serial.height
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match, 'image blur differs at sigma ${sigmas}'
	}
}

fn test_large_box_blur_matches_serial_with_a_padded_mask() {
	previous := os.getenv_opt(serial_cpu_raster)
	defer { restore_serial_raster_setting(previous) }

	width, height := 963, 561
	pitch, offset := width + 17, 5
	mut pixels := []u8{len: offset + pitch * height, init: 0xf3}
	for y in 0 .. height {
		for x in 0 .. width {
			pixels[offset + y * pitch + x] = u8((x * 17 + y * 37) % 256)
		}
	}
	mask := Mask{
		bounds:    IRect{-9, 11, width - 9, height + 11}
		row_bytes: pitch
		offset:    offset
		image:     pixels
	}
	filter := new_mask_blur_filter(13.5)
	assert os.setenv(serial_cpu_raster, '1', true) == 0
	serial := filter.blur(&mask) or { panic('serial blur failed') }
	assert os.unsetenv(serial_cpu_raster) == 0
	parallel := filter.blur(&mask) or { panic('parallel blur failed') }
	assert parallel.bounds == serial.bounds
	assert parallel.row_bytes == serial.row_bytes
	pixels_match := parallel.image == serial.image
	assert pixels_match
}
