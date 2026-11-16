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
