module cpuraster

fn test_copy_rgba_alpha_ignores_incomplete_pixels() {
	assert copy_rgba_alpha([]u8{}).len == 0
	assert copy_rgba_alpha([u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) == [u8(4), 8]
}

fn test_copy_rgba_alpha_matches_scalar_at_dispatch_and_partial_batch() {
	for pixels in [512 * 1024 - 1, 512 * 1024, 512 * 1024 + 19] {
		rgba := []u8{len: pixels * 4 + 3, init: u8(index * 83 + index / 31)}
		expected := []u8{len: pixels, init: rgba[index * 4 + 3]}
		matches := copy_rgba_alpha(rgba) == expected
		assert matches
	}
}
