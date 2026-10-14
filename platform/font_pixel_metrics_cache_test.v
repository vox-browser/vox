module platform

import os
import time

fn test_font_handle_retains_metrics_at_its_exact_fractional_size() {
	font := &Font{family: 'SerenitySans', point_size: 13.25}
	metrics := font.pixel_metrics()
	assert font.has_pixel_metrics_
	assert metrics == font.pixel_metrics_uncached()
	assert font.pixel_metrics() == metrics
	other := &Font{family: 'SerenitySans', point_size: 13.5}
	assert other.pixel_metrics() == other.pixel_metrics_uncached()
	assert other.pixel_metrics().size != metrics.size
}

fn test_metrics_for_a_missing_explicit_source_remain_retryable() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-late-metrics-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{family: 'UnavailableTestFace', point_size: 16, source_path: path}
	_ = font.pixel_metrics()
	assert !font.has_pixel_metrics_
	os.cp(source, path)!
	metrics := font.pixel_metrics()
	assert font.has_pixel_metrics_
	assert metrics == font.pixel_metrics_uncached()
	os.rm(path)!
	assert font.pixel_metrics() == metrics
}
