module main

import math

fn test_document_p3_conversion_preserves_alpha_and_neutral_paints() {
	for value in [f32(0), 0.25, 0.5, 1] {
		color := document_color_to_p3([value, value, value, f32(0.37)]!)
		for channel in 0 .. 3 {
			assert math.abs(color[channel] - value) < 0.0002
			assert color[channel] >= 0 && color[channel] <= 1
		}
		assert color[3] == f32(0.37)
	}
	// The color transform precedes antialiased coverage. Converting an already
	// rounded sRGB blend loses this fractional source value.
	ink := document_color_to_p3([f32(31) / 255, f32(35) / 255, f32(40) / 255, f32(1)]!)
	assert ink[2] * 255 > 39.5 && ink[2] * 255 < 39.6
}

fn test_document_p3_profile_describes_its_matrix_and_shared_transfer_curve() {
	profile := document_display_p3_icc()
	assert profile.len >= 360
	assert profile[12..24].bytestr() == 'mntrRGB XYZ '
	assert profile[36..40].bytestr() == 'acsp'
	assert profile[132..136].bytestr() == 'rXYZ'
	assert profile[240..244].bytestr() == 'XYZ '
	assert profile[320..324].bytestr() == 'para'
	assert profile[329] == 4
	for index in 4 .. 7 {
		at := 136 + index * 12
		assert profile[at..at + 4] == [u8(0), 0, 1, 64]
		assert profile[at + 4..at + 8] == [u8(0), 0, 0, 40]
	}
}

fn test_document_p3_compatibility_backdrop_keeps_alpha_and_row_padding() {
	color := document_color_to_p3([f32(31) / 255, f32(35) / 255, f32(40) / 255, f32(1)]!)
	mut pixels := [u8(math.floor(color[0] * 255 + 0.5)), u8(math.floor(color[1] * 255 + 0.5)),
		u8(math.floor(color[2] * 255 + 0.5)), 255, 17, 18, 19, 20, 0, 0, 0, 0, 21, 22, 23, 24]
	document_p3_to_srgb_pixels(pixels.data, 1, 2, 8)
	for index, expected in [31, 35, 40] {
		assert math.abs(int(pixels[index]) - expected) <= 1
	}
	assert pixels[3..] == [u8(255), 17, 18, 19, 20, 0, 0, 0, 0, 21, 22, 23, 24]
}
