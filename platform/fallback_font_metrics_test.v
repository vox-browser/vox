module platform

import os
import time

fn fallback_metrics_test_source() string {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-fallback-metrics-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.cp(source, path) or { panic(err) }
	return path
}

fn test_temporary_metrics_match_retained_face_metrics_without_publishing_a_face_or_glyphs() {
	path := fallback_metrics_test_source()
	defer { os.rm(path) or {} }
	key := '${path}|0'
	face_count := platform_font_faces.len
	attempt_count := platform_font_face_attempted.len
	glyph_count := platform_glyph_units_cache.len
	sizes := [f32(0), 7.75, 13.25, 16, 41.125]
	mut actual := []FontPixelMetrics{}
	for size in sizes {
		metrics := temporary_file_font_pixel_metrics('TemporaryMetricsFixture', size, path) or { panic('missing temporary face') }
		actual << metrics
	}
	assert platform_font_faces.len == face_count
	assert platform_font_face_attempted.len == attempt_count
	assert platform_glyph_units_cache.len == glyph_count
	assert key !in platform_font_faces
	assert key !in platform_font_face_attempted
	for index, size in sizes {
		font := Font{ family: 'TemporaryMetricsFixture', point_size: size, source_path: path }
		expected := font.pixel_metrics()
		assert actual[index] == expected
		// This time the helper reuses an already published face without adding
		// a temporary Font or any new glyph cache entry to a global owner.
		cached := temporary_file_font_pixel_metrics('TemporaryMetricsFixture', size, path) or { panic('missing cached face') }
		assert cached == expected
	}
}

fn test_generic_fallback_metrics_preserve_fractional_and_zero_size_results() {
	for size in [f32(0), 0.25, 13.25, 16, 41.125] {
		actual := fallback_font_pixel_metrics(size)
		font := Font{ family: 'sans-serif', point_size: size }
		expected := font.pixel_metrics()
		assert actual == expected
	}
}

fn test_temporary_metrics_support_collection_and_cff_faces() {
	$if macos {
		for family, path in {
			'Helvetica Neue':    '/System/Library/Fonts/HelveticaNeue.ttc'
			'CFFMetricsFixture': '/System/Library/Fonts/Supplemental/STIXGeneral.otf'
		} {
			assert os.is_file(path)
			for size in [f32(0), 13.25, 16] {
				actual := temporary_file_font_pixel_metrics(family, size, path) or { panic('missing installed temporary face') }
				font := Font{ family: family, point_size: size, source_path: path }
				expected := font.pixel_metrics()
				assert actual == expected
			}
		}
	}
}

fn test_temporary_metrics_retire_font_storage_and_keep_only_scalar_results() {
	path := fallback_metrics_test_source()
	defer { os.rm(path) or {} }
	first := temporary_file_font_pixel_metrics('RetiredMetricsFixture', 13.25, path) or { panic('missing temporary face') }
	before := thread_arena_usage().used
	for _ in 0 .. 8 {
		actual := temporary_file_font_pixel_metrics('RetiredMetricsFixture', 13.25, path) or { panic('missing temporary face') }
		assert actual == first
	}
	$if prealloc {
		assert thread_arena_usage().used - before < 4096
	}
	scratch := begin_thread_scratch('metrics storage reuse')
	bytes := []u8{len: 1024 * 1024, init: 91}
	assert bytes[bytes.len - 1] == 91
	scratch.finish()
	assert first.size == 13.25
	assert first.x_height > 0
	assert first.advance_of_ascii_zero > 0
	assert first.ascent > 0
	assert first.descent > 0
}

fn test_unreadable_temporary_metrics_do_not_publish_a_failed_face_attempt() {
	path := os.join_path(os.temp_dir(), 'vox-invalid-metrics-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.write_file(path, 'not a font')!
	defer { os.rm(path) or {} }
	missing := temporary_file_font_pixel_metrics('InvalidMetricsFixture', 16, path) == none
	assert missing
	assert '${path}|0' !in platform_font_faces
	assert '${path}|0' !in platform_font_face_attempted
}
