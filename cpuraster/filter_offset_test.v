module cpuraster

import os

fn test_filter_offset_preserves_bilinear_decal_and_integer_translation() {
	image := BlurImage{[u8(40), 80, 120, 200, 80, 120, 160, 240, 4, 8, 12, 16, 20, 32, 40, 64], 2, 2}
	shifted := general_offset(image, 0.5, -0.5)
	assert shifted.pixels == [u8(11), 22, 33, 54, 36, 60, 83, 130, 1, 2, 3, 4, 6, 10, 13, 20]
	whole := general_offset(image, 1, -1)
	assert whole.pixels == [u8(0), 0, 0, 0, 4, 8, 12, 16, 0, 0, 0, 0, 0, 0, 0, 0]
	for displacement in [[f32(-2), 0.5]!, [f32(0.5), 2]!, [f32(1e20), 0.5]!, [f32(0), f32_infinity]!] {
		blank := general_offset(image, displacement[0], displacement[1])
		assert blank.width == 2 && blank.height == 2
		assert blank.pixels == []u8{len: 16}
	}
}

fn test_parallel_filter_offset_matches_serial() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	width, height := 1031, 527
	pixels := []u8{len: width * height * 4, init: u8((index * 29 + index / 113) & 255)}
	image := BlurImage{pixels, width, height}
	original := pixels.clone()
	for displacement in [[f32(13.16843), -9.625]!, [f32(-0.00014648), 1]!] {
		assert os.setenv(serial_setting, '1', true) == 0
		serial := general_offset(image, displacement[0], displacement[1])
		assert os.unsetenv(serial_setting) == 0
		parallel := general_offset(image, displacement[0], displacement[1])
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match
	}
	input_unchanged := pixels == original
	assert input_unchanged
}
