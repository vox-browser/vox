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

fn test_missing_mipmap_levels_preserve_the_native_cpu_accessor_fallback() {
	mut pixels := []u8{len: 4 * 4 * 4}
	for y in 0 .. 4 {
		for x in 0 .. 4 {
			i := (y * 4 + x) * 4
			pixels[i] = u8(x * 64)
			pixels[i + 1] = u8(y * 64)
			pixels[i + 2] = u8((x + y) * 32)
			pixels[i + 3] = 255
		}
	}
	bitmap := CanvasBitmap{pixels: pixels, width: 4, height: 4, pitch: 16, premultiplied: true}
	for mode in 1 .. 3 {
		for scale in [f32(.125), .1, .05, .025] {
			total := affine_scale(scale, scale)
			shader := if mode == 1 { new_mipmap_image_shader(bitmap, .clamp, .clamp, true, total) }
				else { new_linear_mipmap_image_shader(bitmap, .clamp, .clamp, total, true) }
			mut output := []u8{len: 16}
			mut blitter := canvas_paint_blitter_for_surface(mut output, 8, 0xff000000, shader,
				1, .src, Rect{0, 0, 2, 2}, false) or { panic('mipmap shader') }
			blitter.blit_rect(0, 0, 2, 2)
			// Frozen oracle_mipmap_shader output: missing upper levels read
			// the base's 192 edge; missing lower levels keep the 96 average.
			channel := if mode == 2 && scale >= f32(.1) { u8(96) } else { u8(192) }
			assert output == [channel, channel, channel, u8(255)].repeat(4), 'mode ${mode}, scale ${scale}'
		}
	}
}
