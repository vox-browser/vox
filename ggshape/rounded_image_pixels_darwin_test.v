module ggshape

import crypto.sha256

fn test_colored_rounded_image_keeps_unquantized_clip_coverage() {
	mut source := []u8{}
	for y in 0 .. 16 {
		for x in 0 .. 16 { source << [u8(35 + x * 11), u8(40 + y * 10), u8(190 - x * 5), u8(255)] }
	}
	mut pixels := []u8{len: 16 * 16 * 4, init: 255}
	assert draw_rounded_image_pixels(pixels.data, 16, 16, 64, source, 16, 16, 0, 0, 8)
	for i in 0 .. 256 {
		r := pixels[i * 4]
		pixels[i * 4] = pixels[i * 4 + 2]
		pixels[i * 4 + 2] = r
	}
	assert sha256.hexhash(pixels.bytestr()) == 'e7a82e63aadd6a30d875f6c404509f8eac99b7d8d0647b79fe2d61ece26ee868'
}

fn test_rounded_image_scissors_preserve_the_crop_inside_a_padded_raster() {
	mut source := []u8{}
	for y in 0 .. 16 {
		for x in 0 .. 16 { source << [u8(35 + x * 11), u8(40 + y * 10), u8(190 - x * 5), u8(255)] }
	}
	mut pixels := []u8{len: 20 * 20 * 4, init: 255}
	assert draw_rounded_image_pixels(pixels.data, 20, 20, 80, source, 16, 16, 2, 2, 8)
	mut cropped := []u8{}
	for y in 0 .. 20 {
		for x in 0 .. 20 {
			i := (y * 20 + x) * 4
			if x >= 2 && x < 18 && y >= 2 && y < 18 {
				cropped << [pixels[i + 2], pixels[i + 1], pixels[i], pixels[i + 3]]
			} else {
				assert pixels[i..i + 4] == [u8(255), 255, 255, 255]
			}
		}
	}
	assert sha256.hexhash(cropped.bytestr()) == 'e7a82e63aadd6a30d875f6c404509f8eac99b7d8d0647b79fe2d61ece26ee868'
}
