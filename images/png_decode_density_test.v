module main

import math

fn test_png_decode_extent_retains_render_density_before_capture() {
	assert sampled_png_decode_extent([f64(30), 30]!, 2, 1)? == [f64(60), 60]!
	assert sampled_png_decode_extent([f64(20), 20]!, 2, 1)? == [f64(40), 40]!
	assert sampled_png_decode_extent([f64(24), 24]!, 2, 1)? == [f64(48), 48]!
	assert sampled_png_decode_extent([f64(9), 20]!, 2, 1)? == [f64(18), 40]!
	assert sampled_png_decode_extent([f64(25), 40]!, 2.5, 1.25)? == [f64(50), 80]!
	assert sampled_png_decode_extent([f64(18), 40]!, 2, 2)? == [f64(18), 40]!
	assert sampled_png_decode_extent([f64(72), 120]!, 2, 3)? == [f64(72), 120]!
	for invalid in [f64(0), -1, math.inf(1), math.nan()] {
		assert sampled_png_decode_extent([f64(24), 24]!, invalid, 1) == none
		assert sampled_png_decode_extent([f64(24), 24]!, 2, invalid) == none
		assert sampled_png_decode_extent([invalid, f64(24)]!, 2, 1) == none
	}
	assert sampled_png_decode_extent([f64(30), 24]!, 1e308, 0.5) == none
}

fn test_sampled_png_keeps_the_full_source_for_a_minified_capture() {
	raster := [f64(16), 12]!
	rendering := sampled_png_decode_extent(raster, 3, 1)?
	width, height := sampled_png_decode_size(40, 30, raster, rendering)?
	assert width == 40 && height == 30

	width_at_natural, height_at_natural := sampled_png_decode_size(48, 36, raster, rendering)?
	assert width_at_natural == 48 && height_at_natural == 36

	width_at_capture, height_at_capture := sampled_png_decode_size(40, 30, raster, raster)?
	assert width_at_capture == 20 && height_at_capture == 15

	assert sampled_png_decode_size(16, 12, raster, rendering) == none
	assert sampled_png_decode_size(4097, 30, raster, rendering) == none
}
