module cpuraster

import math

fn test_glyph_mask_uses_fixed_point_separable_filter_and_preserves_bounds() {
	mut source := []u8{len: 81}
	source[40] = 255
	filtered := blur_glyph_mask(source, 9, 9, 1) or { panic('filter failed') }
	assert filtered.len == source.len
	for y in 0 .. 9 {
		for x in 0 .. 9 {
			expected := if x >= 3 && x <= 5 && y >= 3 && y <= 5 {
				[u8(2), 20, 2, 20, 163, 20, 2, 20, 2][(y - 3) * 3 + x - 3]
			} else {
				u8(0)
			}
			assert filtered[y * 9 + x] == expected
		}
	}
	assert source[40] == 255
	assert blur_glyph_mask(source, 9, 9, 0) or { panic('zero blur') } == source
	assert blur_glyph_mask(source, 9, 9, .5) or { panic('subthreshold blur') } == source
}

fn test_glyph_mask_rejects_unbounded_or_nonfinite_inputs() {
	for blur in [f32(-1), 3.01, f32(math.nan()), f32(math.inf(1))] {
		if _ := blur_glyph_mask([u8(255)], 1, 1, blur) {
			assert false
		}
	}
	if _ := blur_glyph_mask([u8(255)], 2, 2, 1) {
		assert false
	}
	if _ := blur_glyph_mask([], 0, 0, 1) {
		assert false
	}
}
