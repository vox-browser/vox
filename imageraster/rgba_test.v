module imageraster

fn test_rounded_decode_size_selects_a_mip_from_the_actual_integer_size() {
	w, h := decode_size(500, 500, 60, 60) or { panic('size') }
	assert w == 63 && h == 63
	source := []u8{len: 500 * 500 * 4, init: 255}
	image := decode_rgba(source, 500, 500, w, h) or { panic('decode') }
	assert image.width == 63 && image.height == 63
	assert image.pixels.all(it == 255)
	sw, sh := decode_size(500, 500, 32, 32) or { panic('small size') }
	assert sw == 32 && sh == 32
	assert decode_size(500, 500, 500, 500) == none
	assert decode_rgba([], 500, 500, 63, 63) == none
}

fn test_alpha_is_premultiplied_before_neighboring_colors_are_filtered() {
	// Transparent red cannot leak into the opaque blue texel beside it.
	source := [u8(255), 0, 0, 0, 0, 0, 255, 255, 255, 0, 0, 0, 0, 0, 255, 255]
	image := decode_rgba(source, 2, 2, 1, 1) or { panic('decode') }
	assert image.pixels == [u8(0), 0, 127, 127]
}

fn test_odd_mip_dimensions_filter_the_final_source_row_and_column() {
	mut pixels := []u8{len: 3 * 3 * 4}
	for y in 0 .. 3 {
		for x in 0 .. 3 {
			pixels[(y * 3 + x) * 4] = u8(y * 30 + x * 10)
			pixels[(y * 3 + x) * 4 + 3] = 255
		}
	}
	image := decode_rgba(pixels, 3, 3, 1, 1) or { panic('decode') }
	assert image.pixels == [u8(40), 0, 0, 255]
	levels := mip_chain(Image{ width: 3, height: 3, pixels: pixels }) or { panic('mips') }
	assert levels.len == 2
	assert levels[1].pixels == image.pixels
	assert mip_chain(Image{ width: 3, height: 3, pixels: [] }) == none
}
