// vtest build: macos
module ggshape

import math

fn test_sampled_gamut_converts_source_before_blending_and_keeps_backdrop_space() {
	// Swap linear red and blue. Half-transparent red becomes blue before
	// blending over yellow; converting the already blended result would
	// incorrectly turn the yellow backdrop blue as well.
	swap_rb := [f32(0), 0, 1, 0, 1, 0, 1, 0, 0]!
	source := [u8(128), 0, 0, 128].repeat(4)
	for samples in [1, 4] {
		mut pixels := [u8(0), 255, 255, 255].repeat(16)
		assert draw_sampled_srgb_gamut_clipped(pixels.data, 4, 4, 16, 1,
			source, 2, 2, 1, 1, 2, 2, samples, 2, 2, [12]f32{}, false, swap_rb) == 1
		for y in 0 .. 4 {
			for x in 0 .. 4 {
				i := (y * 4 + x) * 4
				if x in [1, 2] && y in [1, 2] {
					for c, expected in [128, 127, 127] {
						assert math.abs(int(pixels[i + c]) - expected) <= 1
					}
					assert pixels[i + 3] == 255
				} else {
					assert pixels[i..i + 4] == [u8(0), 255, 255, 255]
				}
			}
		}
	}
}

fn test_sampled_gamut_rejects_invalid_transform_without_touching_pixels() {
	mut pixels := [u8(17), 18, 19, 255].repeat(16)
	before := pixels.clone()
	gamut := [f32(math.nan()), 0, 0, 0, 1, 0, 0, 0, 1]!
	assert draw_sampled_srgb_gamut_clipped(pixels.data, 4, 4, 16, 1,
		[u8(255), 0, 0, 255].repeat(4), 2, 2, 1, 1, 2, 2, 1, 2, 2,
		[12]f32{}, false, gamut) == 0
	assert pixels == before
}
