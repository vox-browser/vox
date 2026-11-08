module cpuraster

fn test_mipmap_even_box_and_odd_triangle_filters() {
	// In an odd three-pixel row, the center has twice the outer weight.
	bitmap := CanvasBitmap{pixels: [u8(0), 4, 8, 12, 40, 44, 48, 52, 80, 84, 88, 92],
		width: 3, height: 1, pitch: 12, premultiplied: true}
	image := build_image_mipmap(bitmap, 1) or { panic('mipmap') }
	assert image.width == 1 && image.height == 1
	assert image.pixels == [u8(40), 44, 48, 52]
	box := build_image_mipmap(CanvasBitmap{pixels: [u8(0), 0, 0, 0, 100, 100, 100, 100,
		200, 200, 200, 200, 255, 255, 255, 255], width: 2, height: 2, pitch: 8}, 1) or { panic('box') }
	assert box.pixels == [u8(138), 138, 138, 138]
	if _ := build_image_mipmap(bitmap, 2) { assert false }
}

fn test_mipmap_retains_a_one_pixel_axis_and_ignores_row_padding() {
	bitmap := CanvasBitmap{pixels: [u8(8), 8, 8, 8, 255, 255, 255, 255,
		16, 16, 16, 16, 255, 255, 255, 255, 24, 24, 24, 24], width: 1, height: 3, pitch: 8}
	image := build_image_mipmap(bitmap, 1) or { panic('mipmap') }
	assert image.pixels == [u8(16), 16, 16, 16]
}
