// vtest build: macos
module ggshape

import platform

fn test_yuv_conversion_follows_filtering_and_clipping() {
	// Clipping the individual RGB texels first would average to 128,128,128.
	// Average the independent chroma values before applying the RGB matrix.
	source := [u8(128), 0, 0, 255, 128, 255, 255, 255, 128, 0, 0, 255, 128, 255, 255, 255]
	for samples in [1, 4] {
		mut scratch := platform.begin_thread_scratch('YUV image frame')
		mut pixels := []u8{len: 16 * 16 * 4, init: 255}
		assert draw_sampled_yuv_clipped(pixels.data, 16, 16, 64, 1, source, 2, 2, 4, 4, 1, 1, samples, 2, 2, [12]f32{}) == 1
		i := (4 * 16 + 4) * 4
		assert pixels[i..i + 4] == [u8(129), 131, 130, 255]
		assert pixels[..4] == [u8(255), 255, 255, 255]
		// A destination clip must preserve the original opaque backdrop outside it.
		black := [u8(16), 128, 128, 255, 16, 128, 128, 255, 16, 128, 128, 255, 16, 128, 128, 255]
		assert draw_sampled_yuv_clipped(pixels.data, 16, 16, 64, 1, black, 2, 2, 6, 6, 4, 4, samples, 2, 2, [
			f32(7),
			7,
			2,
			2,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
			0,
		]!) == 1
		assert pixels[(7 * 16 + 7) * 4..(7 * 16 + 7) * 4 + 4] == [u8(0), 0, 0, 255]
		assert pixels[(6 * 16 + 6) * 4..(6 * 16 + 6) * 4 + 4] == [u8(255), 255, 255, 255]
		scratch.finish()
	}
}

fn test_yuv_upload_rejects_alpha_and_invalid_lengths() {
	mut pixels := []u8{len: 4 * 4 * 4, init: 255}
	assert draw_sampled_yuv_clipped(pixels.data, 4, 4, 16, 1, [u8(128), 128, 128, 0], 1, 1, 0, 0, 1, 1, 1, 1, 1, [12]f32{}) == 0
	assert draw_sampled_yuv_clipped(pixels.data, 4, 4, 16, 1, [u8(128)], 1, 1, 0, 0, 1, 1, 1, 1, 1, [12]f32{}) == 0
}
