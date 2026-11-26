module yuv

import math

fn test_webp_half_size_reduces_luma_before_rgb_conversion() {
	mut planes := []u8{len: 24, init: 128}
	for y in 0 .. 4 {
		for x in 0 .. 4 { planes[y * 4 + x] = u8(16 + x + y * 4) }
	}
	colors := webp_sampled_colors(planes, 4, 4, 2, 2) or { panic('half-size conversion') }
	// Each 2x2 luma block is reduced with integer truncation, not rounded RGB.
	for i, expected in [2, 5, 12, 14] {
		for c in 0 .. 3 {
			assert int(math.floor(colors[i * 4 + c] * 255 + .5)) == expected
		}
		assert colors[i * 4 + 3] == 1
	}
	assert colors[0] > f32(2) / 255 && colors[0] < f32(3) / 255
}

fn test_webp_native_size_interpolates_chroma_before_saturating_rgb() {
	mut planes := []u8{len: 24, init: 128}
	planes[16], planes[17], planes[18], planes[19] = 0, 255, 0, 255
	colors := webp_sampled_colors(planes, 4, 4, 4, 4) or { panic('native-size conversion') }
	// At x=1 chroma is 63.75, not a rounded byte or nearest 2x2 block.
	assert colors[4 + 2] > 0 && colors[4 + 2] < f32(1) / 255
	assert colors[3 * 4 + 2] == 1
	assert colors.len == 64
}

fn test_webp_sampled_colors_rejects_partial_planes_and_unverified_scales() {
	planes := []u8{len: 24, init: 128}
	assert webp_sampled_colors(planes[..23], 4, 4, 4, 4) == none
	for size in [-1, 0, 1, 3, 5] {
		assert webp_sampled_colors(planes, 4, 4, size, size) == none
	}
	assert webp_sampled_colors(planes, 4, 4, 4, 2) == none
	assert webp_sampled_colors(planes, 3, 4, 3, 4) == none
	assert webp_sampled_colors(planes, 4098, 2, 4098, 2) == none
}
