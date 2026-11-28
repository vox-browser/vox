module cpuraster

import os

fn test_filter_opacity_keeps_decal_and_uses_byte_alpha_table() {
	image := BlurImage{[u8(255), 100, 90, 0, 1, 1, 1, 1, 64, 32, 10, 128, 80, 140, 255, 255], 2, 2}
	mut table := [256]u8{}
	for i in 0 .. table.len {
		table[i] = u8(i / 2)
	}
	table[0] = 255
	result := general_alpha_table(image, table)
	assert result.pixels == [u8(0), 0, 0, 0, 0, 0, 0, 0, 32, 16, 5, 64, 40, 70, 127, 127]
}

fn test_parallel_filter_opacity_matches_serial() {
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
	for factor in [0, 87, 255] {
		mut table := [256]u8{}
		for i in 0 .. table.len {
			table[i] = u8(i * factor / 255)
		}
		assert os.setenv(serial_setting, '1', true) == 0
		serial := general_alpha_table(image, table)
		assert os.unsetenv(serial_setting) == 0
		parallel := general_alpha_table(image, table)
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match
	}
	input_unchanged := pixels == original
	assert input_unchanged
}
