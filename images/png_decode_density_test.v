module main

import math

fn test_png_decode_extent_retains_render_density_before_capture() {
	assert sampled_png_decode_extent([f64(24), 24]!, 2, 1)? == [f64(48), 48]!
	assert sampled_png_decode_extent([f64(9), 20]!, 2, 1)? == [f64(18), 40]!
	assert sampled_png_decode_extent([f64(18), 40]!, 2, 2)? == [f64(18), 40]!
	for invalid in [f64(0), -1, math.inf(1), math.nan()] {
		assert sampled_png_decode_extent([f64(24), 24]!, invalid, 1) == none
		assert sampled_png_decode_extent([f64(24), 24]!, 2, invalid) == none
		assert sampled_png_decode_extent([invalid, f64(24)]!, 2, 1) == none
	}
}
