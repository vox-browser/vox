module main

fn C.native_composite_opacity_pixels(layer &u8, backdrop &u8, result &u8, count uint, opacity f32)
fn C.native_opacity_layer_ink_bounds(pixels &u8, pitch uint, left int, top int, right int, bottom int, ink_left &int, ink_top &int, ink_right &int, ink_bottom &int) int

fn opacity_group_test_composite(layer []u8, backdrop []u8, opacity f32) []u8 {
	mut result := []u8{len: layer.len}
	$if macos {
		C.native_composite_opacity_pixels(layer.data, backdrop.data, result.data, uint(layer.len / 4),
			opacity)
	}
	return result
}

// Brave composites an 8-bit opacity layer with float32 arithmetic and one
// fused multiply-add. A faint shadow pixel halfway between two levels rounds
// down, and an opaque text pixel at 0.7 rounds up.
fn test_opacity_group_composite_follows_chromium_float_rounding() {
	$if macos {
		page := [u8(255), 255, 238, 255]
		// Black shadow coverage 1/255 and 3/255 at opacity 0.5: 254.5 and 253.5
		// land on 254 and 253.
		assert opacity_group_test_composite([u8(0), 0, 0, 1], page, 0.5) == [u8(254), 254, 238,
			255]
		assert opacity_group_test_composite([u8(0), 0, 0, 3], page, 0.5) == [u8(253), 253, 237,
			255]
		// Opaque text over the group's background at 0.7: blue 199.5 rounds up.
		assert opacity_group_test_composite([u8(224), 191, 183, 255], page, 0.7) == [u8(233), 210,
			200, 255]
		// Navy glyph coverage inside a 0.8 group.
		assert opacity_group_test_composite([u8(0), 0, 68, 136], page, 0.8) == [u8(146), 146, 191,
			255]
		// Transparent layer pixels leave the backdrop unchanged.
		assert opacity_group_test_composite([u8(0), 0, 0, 0], [u8(12), 34, 56, 78], 0.3) == [u8(12),
			34, 56, 78]
	}
}

fn test_opacity_layer_ink_bounds_cover_painted_pixels_only() {
	$if macos {
		width := 8
		mut pixels := []u8{len: width * 6 * 4}
		mut left := 0
		mut top := 0
		mut right := 0
		mut bottom := 0
		assert C.native_opacity_layer_ink_bounds(pixels.data, uint(width * 4), 0, 0, width, 6,
			&left, &top, &right, &bottom) == 0
		// Any channel marks a painted pixel, including alpha alone.
		pixels[(2 * width + 3) * 4 + 3] = 1
		pixels[(4 * width + 5) * 4] = 9
		pixels[(5 * width + 7) * 4 + 3] = 255
		assert C.native_opacity_layer_ink_bounds(pixels.data, uint(width * 4), 0, 0, width, 6,
			&left, &top, &right, &bottom) == 1
		assert [left, top, right, bottom] == [3, 2, 8, 6]
		// Only the searched region contributes.
		assert C.native_opacity_layer_ink_bounds(pixels.data, uint(width * 4), 0, 0, 6, 5,
			&left, &top, &right, &bottom) == 1
		assert [left, top, right, bottom] == [3, 2, 6, 5]
	}
}
