// vtest build: macos
module ggshape

fn test_sampled_image_clip_does_not_clip_a_following_glyph_mask() {
	mut pixels := []u8{len: 8 * 8 * 4, init: 255}
	mut mask := []u8{len: 8 * 8}
	mask[6 * 8 + 6] = 255
	clip := [f32(2), 2, 4, 4, 2, 2, 2, 2, 2, 2, 2, 2]!
	identity := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	assert draw_sampled_srgb_gamut_with_shadow_and_glyphs(pixels.data, 8, 8, 32, 1,
		[u8(255), 0, 0, 255].repeat(4), 2, 2, 2, 2, 4, 4, 4, 2, 2,
		clip, false, identity, unsafe { nil },
		[GlyphCoverage{ pixels: mask, color: [f32(0), 1, 0, 1]! }]) == 1
	assert pixels[(6 * 8 + 6) * 4..(6 * 8 + 6) * 4 + 4] == [u8(0), 255, 0, 255]
	assert pixels[(3 * 8 + 3) * 4..(3 * 8 + 3) * 4 + 4] == [u8(0), 0, 255, 255]
	assert pixels[..4] == [u8(255), 255, 255, 255]
}

fn test_sampled_image_with_incomplete_glyph_coverage_preserves_destination() {
	mut pixels := []u8{len: 8 * 8 * 4, init: 129}
	assert draw_sampled_srgb_gamut_with_shadow_and_glyphs(pixels.data, 8, 8, 32, 1,
		[u8(255), 0, 0, 255].repeat(4), 2, 2, 2, 2, 4, 4, 4, 2, 2,
		[12]f32{}, false, [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!, unsafe { nil },
		[GlyphCoverage{ pixels: [u8(255)], color: [f32(0), 1, 0, 1]! }]) == 0
	assert pixels.all(it == 129)
}
