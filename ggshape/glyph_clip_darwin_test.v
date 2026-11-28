module ggshape

fn test_glyph_mask_rectangular_clip_preserves_ink_and_fractional_fringe() {
	for samples in [1, 4] {
		mut pixels := []u8{len: 4 * 2 * 4, init: 255}
		mask := []u8{len: 4 * 2, init: 85}
		assert draw_clipped_glyph_mask(pixels.data, 4, 2, 16, 1, mask,
			[f32(0), 0, 0, 1]!, [f32(1.5), 0, 4, 2]!, samples) == 1
		for y in 0 .. 2 {
			for c in 0 .. 3 {
				assert pixels[y * 16 + c] == 255
				assert pixels[y * 16 + 4 + c] > 170 && pixels[y * 16 + 4 + c] < 255
				assert pixels[y * 16 + 8 + c] == 170
				assert pixels[y * 16 + 12 + c] == 170
			}
			for x in 0 .. 4 { assert pixels[y * 16 + x * 4 + 3] == 255 }
		}
	}
}

fn test_extended_glyph_ink_blends_before_the_destination_byte_clamp() {
	for samples in [1, 4] {
		// BGRA destination and an A8 glyph sample. Clamping the source's
		// red component first changes its final result from 214 to 213.
		mut extended := [u8(70), 134, 66, 255]
		mut bounded := extended.clone()
		ink := [f32(1.0000991821289062), 0.9999618530273438, 0.9999465942382812, 1]!
		assert draw_clipped_glyph_mask(extended.data, 1, 1, 4, 1, [u8(199)], ink,
			[f32(0), 0, 1, 1]!, samples) == 1
		assert draw_clipped_glyph_mask(bounded.data, 1, 1, 4, 1, [u8(199)],
			[f32(1), ink[1], ink[2], 1]!, [f32(0), 0, 1, 1]!, samples) == 1
		assert extended == [u8(214), 228, 214, 255]
		assert bounded == [u8(214), 228, 213, 255]
	}
}
