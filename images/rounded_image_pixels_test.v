module main

import crypto.sha256

#flag darwin -DVOX_TEST_ROUNDED_IMAGE_PIXELS

fn C.vox_test_small_rounded_image_pixels(&u8, &u8, i32) i32

fn test_small_rounded_image_preserves_color_through_the_native_raster_boundary() {
	$if macos {
		mut source := []u8{}
		for y in 0 .. 16 {
			for x in 0 .. 16 {
				source << [u8(35 + x * 11), u8(40 + y * 10), u8(190 - x * 5), u8(255)]
			}
		}
		mut pixels := []u8{len: 16 * 16 * 4}
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 1) == 1
		// Exact colored-avatar crop from Brave; includes all rounded boundaries.
		assert sha256.hexhash(pixels.bytestr()) == 'e7a82e63aadd6a30d875f6c404509f8eac99b7d8d0647b79fe2d61ece26ee868'
		assert C.vox_test_small_rounded_image_pixels(pixels.data, source.data, 0) == 0
		assert pixels.all(it == 255)
	}
}
