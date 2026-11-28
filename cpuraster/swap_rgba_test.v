module cpuraster

fn test_swap_rgba_red_blue_preserves_odd_rows_and_padding() {
	width, height := 1031, 513
	pitch := width * 4 + 7
	// Offset the surface by a byte, and omit padding after its last row.
	mut pixels := []u8{len: 1 + (height - 1) * pitch + width * 4, init: u8((index + index / 256 * 3) & 255)}
	original := pixels.clone()
	mut expected := pixels.clone()
	for y in 0 .. height {
		for x in 0 .. width {
			i := 1 + y * pitch + x * 4
			expected[i] = original[i + 2]
			expected[i + 2] = original[i]
		}
	}
	unsafe { swap_rgba_red_blue(&pixels[1], i32(width), i32(height), i32(pitch)) }
	swapped := pixels == expected
	assert swapped
	unsafe { swap_rgba_red_blue(&pixels[1], i32(width), i32(height), i32(pitch)) }
	restored := pixels == original
	assert restored
}
