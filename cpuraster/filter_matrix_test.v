module cpuraster

import os

fn test_filter_matrix_preserves_transparency_and_applies_alpha_bias() {
	image := BlurImage{[u8(0), 0, 0, 0, 241, 122, 33, 0, 80, 16, 4, 128, 201, 15, 88, 255], 2, 2}
	mut matrix := [f32(1), 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]!
	preserved := general_color_matrix(image, MatrixColorFilter{ matrix: matrix, clamp: true })
	assert preserved.pixels == [u8(0), 0, 0, 0, 0, 0, 0, 0, 80, 16, 4, 128, 201, 15, 88, 255]

	matrix[4] = .125
	matrix[14] = .25
	matrix[19] = .25
	flooded := general_color_matrix(image, MatrixColorFilter{ matrix: matrix, clamp: true })
	assert flooded.pixels[..8] == [u8(8), 0, 16, 64, 8, 0, 16, 64]
	assert flooded.pixels[12..] == [u8(233), 15, 152, 255]

	matrix[4] = f32_infinity
	invalid := general_color_matrix(image, MatrixColorFilter{ matrix: matrix, clamp: true })
	assert invalid.pixels == image.pixels
}

fn test_in_place_filter_matrix_matches_premultiplied_layer() {
	mut pixels := [u8(0), 0, 0, 0, 80, 16, 4, 128, 201, 15, 88, 255, 32, 9, 5, 64]
	matrix := MatrixColorFilter{
		matrix: [f32(0), 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0]!
		clamp: true
	}
	expected := general_color_matrix(BlurImage{pixels, 2, 2}, matrix)
	assert apply_canvas_color_matrix_in_place(mut pixels, 2, 2, matrix, false)
	assert pixels == expected.pixels
}

fn test_linear_rgb_matrix_encodes_before_rounding() {
	mut pixels := [u8(208), 128, 64, 255, 26, 52, 78, 102, 12, 8, 4, 255, 0, 0, 0, 0]
	matrix := MatrixColorFilter{
		matrix: [f32(.25), 0, 0, 0, 0, 0, .25, 0, 0, 0, 0, 0, .25, 0, 0, 0, 0, 0, 1, 0]!
		clamp: true
	}
	assert apply_canvas_color_matrix_in_place(mut pixels, 2, 2, matrix, true)
	assert pixels == [u8(111), 66, 30, 255, 12, 27, 41, 102, 3, 2, 1, 255, 0, 0, 0, 0]
}

fn test_parallel_filter_matrix_matches_serial() {
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
	pixels := []u8{len: width * height * 4, init: if index % 16 == 3 {
		u8(0)
	} else {
		u8((index * 29 + index / 113) & 255)
	}}
	image := BlurImage{pixels, width, height}
	original := pixels.clone()
	for bias in [f32(0), .25] {
		matrix := MatrixColorFilter{
			matrix: [f32(1.125), .15, -.1, 0, .125, .08, .8, .05, 0, 0, .13, .17, .72, 0, .25,
				0, 0, 0, .75, bias]!
			clamp:  true
		}
		assert os.setenv(serial_setting, '1', true) == 0
		serial := general_color_matrix(image, matrix)
		assert os.unsetenv(serial_setting) == 0
		parallel := general_color_matrix(image, matrix)
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match
	}
	input_unchanged := pixels == original
	assert input_unchanged
}
