module cpuraster

import math
import os

fn test_filter_transfer_index_matches_previous_rounding_for_all_byte_pairs() {
	for alpha in 1 .. 256 {
		for channel in 0 .. 256 {
			expected := int(math.min(255.0, math.round(f64(channel) * 255 / f64(alpha))))
			assert filter_transfer_index(u8(channel), u32(alpha)) == expected
		}
	}
}

fn test_filter_transfer_converts_both_directions_and_keeps_alpha() {
	image := BlurImage{[u8(64), 128, 192, 255, 255, 123, 77, 0], 2, 1}
	linear := general_transfer(image, true)
	assert linear.pixels == [u8(13), 55, 134, 255, 0, 0, 0, 0]
	srgb := general_transfer(linear, false)
	assert srgb.pixels == [u8(64), 128, 192, 255, 0, 0, 0, 0]
}

fn test_parallel_filter_transfer_matches_serial() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	width, height := 1051, 509
	pixels := []u8{len: width * height * 4, init: u8((index * 37 + index / 121) & 255)}
	image := BlurImage{pixels, width, height}
	original := pixels.clone()
	for to_linear in [true, false] {
		assert os.setenv(serial_setting, '1', true) == 0
		serial := general_transfer(image, to_linear)
		assert os.unsetenv(serial_setting) == 0
		parallel := general_transfer(image, to_linear)
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match
	}
	input_unchanged := pixels == original
	assert input_unchanged
}
