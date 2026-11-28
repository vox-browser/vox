// vtest build: macos
module ggshape

import math

fn test_text_shadow_mask_blends_fractional_alpha_once() {
	mut pixels := []u8{len: 16, init: [u8(92), 184, 92, 255][index % 4]}
	mask := [u8(0), 128, 255, 64]
	assert draw_text_shadow_mask(pixels.data, 2, 2, 8, 1, mask, 2, 2, 0, 0, 0,
		[f32(0), 0, 0, .5]!) == 1
	assert pixels == [u8(92), 184, 92, 255, 69, 138, 69, 255, 46, 92, 46, 255, 80, 161, 80, 255]
}

fn test_text_shadow_mask_rejects_invalid_inputs_before_mutating_pixels() {
	original := []u8{len: 16, init: u8(index * 13)}
	for blur in [f32(-1), 3.01, f32(math.nan()), f32(math.inf(1))] {
		mut pixels := original.clone()
		assert draw_text_shadow_mask(pixels.data, 2, 2, 8, 1, [u8(255), 255, 255, 255], 2, 2,
			0, 0, blur, [f32(0), 0, 0, .5]!) == 0
		assert pixels == original
	}
	mut pixels := original.clone()
	assert draw_text_shadow_mask(pixels.data, 2, 2, 8, 1, [u8(255), 255, 255], 2, 2,
		0, 0, 0, [f32(0), 0, 0, .5]!) == 0
	assert pixels == original
}

fn test_text_shadow_mask_filter_preserves_a_constant_source_inside_its_support() {
	mut pixels := []u8{len: 16, init: [u8(92), 184, 92, 255][index % 4]}
	mask := []u8{len: 32 * 32, init: 255}
	assert draw_text_shadow_mask(pixels.data, 2, 2, 8, 1, mask, 32, 32, 16, 16, 3,
		[f32(0), 0, 0, .5]!) == 1
	assert pixels == [u8(46), 92, 46, 255, 46, 92, 46, 255, 46, 92, 46, 255, 46, 92, 46, 255]
}

fn test_text_shadow_masks_blend_each_overlapping_glyph_before_the_next() {
	mut pixels := [u8(255), 255, 255, 255]
	for _ in 0 .. 2 {
		assert draw_text_shadow_mask(pixels.data, 1, 1, 4, 1, [u8(255)], 1, 1,
			0, 0, 0, [f32(0), 0, 0, .5]!) == 1
	}
	assert pixels == [u8(64), 64, 64, 255]
}
