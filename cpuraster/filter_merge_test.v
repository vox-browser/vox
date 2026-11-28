module cpuraster

import os

fn test_filter_merge_preserves_input_order_and_repeated_inputs() {
	first := BlurImage{[u8(150), 20, 0, 170, 40, 70, 0, 110, 160, 10, 50, 111, 21, 230, 0, 64], 2, 2}
	second := BlurImage{[u8(0), 40, 140, 160, 80, 9, 17, 0, 13, 23, 31, 255, 240, 250, 100, 121], 2, 2}
	merged := general_merge([first, second], 2, 2)
	assert merged.pixels[..4] == [u8(56), 47, 140, 223]
	assert merged.pixels[4..12] == [u8(40), 70, 0, 110, 13, 23, 31, 255]
	repeated := general_merge([first, second, first], 2, 2)
	assert repeated.pixels == [u8(169), 36, 47, 244, 63, 110, 0, 173, 167, 23, 68, 255, 209, 255,
		75, 180]
	assert general_merge([], 2, 2).pixels == []u8{len: 16}
}

fn test_parallel_filter_merge_matches_serial() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	width, height := 521, 257
	size := width * height * 4
	first := BlurImage{[]u8{len: size, init: u8((index * 29 + index / 113) & 255)}, width, height}
	second := BlurImage{[]u8{len: size, init: u8((index * 7 + index / 137) & 255)}, width, height}
	first_original := first.pixels.clone()
	second_original := second.pixels.clone()
	inputs := [first, second, first, second]
	assert os.setenv(serial_setting, '1', true) == 0
	serial := general_merge(inputs, width, height)
	assert os.unsetenv(serial_setting) == 0
	parallel := general_merge(inputs, width, height)
	pixels_match := parallel.pixels == serial.pixels
	assert pixels_match
	inputs_unchanged := first.pixels == first_original && second.pixels == second_original
	assert inputs_unchanged
}
