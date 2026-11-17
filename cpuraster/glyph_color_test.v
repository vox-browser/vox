module cpuraster

fn test_extended_glyph_color_rounds_after_coverage_and_keeps_row_padding() {
	ink := [f32(1.0000991821289062), 0.9999618530273438, 0.9999465942382812, 1]!
	mut pixels := [u8(66), 134, 70, 255, 11, 22, 33, 44, 66, 134, 70, 255, 55, 66, 77, 88]
	assert blend_extended_glyph_mask(mut pixels, 1, 2, 8, [u8(199), 0], ink)
	assert pixels == [u8(214), 228, 214, 255, 11, 22, 33, 44, 66, 134, 70, 255, 55, 66, 77, 88]
	mut bounded := [u8(66), 134, 70, 255]
	assert blend_extended_glyph_mask(mut bounded, 1, 1, 4, [u8(199)], [f32(1), ink[1], ink[2], 1]!)
	assert bounded == [u8(213), 228, 214, 255]
}

fn test_extended_glyph_color_keeps_author_alpha_and_clamps_only_the_result() {
	mut pixels := [u8(0), 0, 0, 255]
	assert blend_extended_glyph_mask(mut pixels, 1, 1, 4, [u8(255)], [f32(2), -1, 0.5, 0.5]!)
	assert pixels == [u8(255), 0, 64, 255]
	before := pixels.clone()
	assert !blend_extended_glyph_mask(mut pixels, 1, 1, 4, []u8{}, [f32(1), 1, 1, 1]!)
	assert !blend_extended_glyph_mask(mut pixels, 1, 1, 4, [u8(255)], [f32(1), 1, 1, 2]!)
	assert pixels == before
}
