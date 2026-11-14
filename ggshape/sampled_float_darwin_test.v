// vtest build: macos
module ggshape

import math

fn test_fractional_sampled_image_color_reaches_the_destination_once() {
	colors := []f32{len: 34 * 34 * 4, init: [f32(.25), .5, .75, 1][index % 4]}
	mut pixels := []u8{len: 64 * 64 * 4}
	for samples in [1, 4] {
		assert draw_sampled_colors_clipped(pixels.data, 64, 64, 256, 0, colors, 34, 34, 20, 20, 24, 24, samples, 540, 540, [
			f32(20),
			20,
			24,
			24,
			12,
			12,
			12,
			12,
			12,
			12,
			12,
			12,
		]!) == 1
		assert pixels[(32 * 64 + 32) * 4..(32 * 64 + 32) * 4 + 4] == [u8(191), 128, 64, 255]
	}
}

fn test_invalid_sampled_float_sources_leave_the_destination_unchanged() {
	mut pixels := []u8{len: 64, init: 83}
	for value in [f32(math.nan()), f32(-1), f32(2), f32(.5)] {
		mut source := []f32{len: 16, init: if index % 4 == 3 { f32(1) } else { f32(0) }}
		source[if value == .5 { 3 } else { 0 }] = value
		assert draw_sampled_colors_clipped(pixels.data, 4, 4, 16, 1, source, 2, 2, 0, 0, 2, 2, 1, 2, 2, [12]f32{}) == 0
		assert pixels.all(it == 83)
	}
}
