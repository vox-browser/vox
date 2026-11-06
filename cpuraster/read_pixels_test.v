module cpuraster

import crypto.sha256

fn premultiplied_table() []u8 {
	mut source := []u8{len: 256 * 256 * 4}
	for alpha in 0 .. 256 {
		for value in 0 .. 256 {
			offset := (alpha * 256 + value) * 4
			source[offset] = u8(value)
			source[offset + 1] = u8(255 - value)
			source[offset + 2] = u8(value ^ 0x5a)
			source[offset + 3] = u8(alpha)
		}
	}
	return source
}

// The hash covers every premultiplied channel/alpha pair, including invalid
// premultiplied values, as LibWeb's Skia unpremultiplies them.
fn test_read_pixels_unpremultiplies_like_skia() {
	source := premultiplied_table()
	mut pixels := []u8{len: source.len}
	assert read_pixels(source, 256, 256, 1024, 2, mut pixels, 256, 256, 1024, 0, 0)
	assert sha256.sum(pixels).hex() == '290b18a0efb6cfffa148ba2b39de8a8275911c2b1d5105a77a5b38fba3253427'
	assert pixels[(128 * 256 + 200) * 4..(128 * 256 + 201) * 4] == [u8(255), 110, 255, 128]
	assert pixels[(3 * 256 + 2) * 4..(3 * 256 + 3) * 4] == [u8(170), 255, 255, 3]
	assert pixels[..4] == [u8(0), 0, 0, 0]
	mut copied := []u8{len: source.len}
	assert read_pixels(source, 256, 256, 1024, 1, mut copied, 256, 256, 1024, 0, 0)
	assert copied == source
}

fn test_read_pixels_trims_to_the_source_and_keeps_other_bytes() {
	source := [u8(10), 20, 30, 255, 40, 50, 60, 255, 70, 80, 90, 255, 100, 110, 120, 255]
	mut destination := []u8{len: 3 * 3 * 4, init: 7}
	assert read_pixels(source, 2, 2, 8, 1, mut destination, 3, 3, 12, -1, 1)
	mut expected := [u8(7), 7, 7, 7, 70, 80, 90, 255, 100, 110, 120, 255]
	expected << []u8{len: 2 * 3 * 4, init: 7}
	assert destination == expected
	assert !read_pixels(source, 2, 2, 8, 1, mut destination, 1, 1, 4, 2, 0)
	assert !read_pixels(source, 2, 2, 8, 1, mut destination, 1, 1, 4, min_i32, 0)
}

fn test_read_pixels_matches_skia_row_byte_validation() {
	source := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
	mut destination := []u8{len: 16}
	assert !read_pixels(source, 2, 2, 6, 1, mut destination, 2, 2, 8, 0, 0)
	assert !read_pixels(source, 2, 2, 10, 1, mut destination, 2, 2, 8, 0, 0)
	assert !read_pixels(source, 2, 2, 8, 1, mut destination, 2, 2, 6, 0, 0)
	assert !read_pixels(source, 0, 2, 8, 1, mut destination, 2, 2, 8, 0, 0)
	// A zero source pitch keeps zero row bytes: both rows read the first row.
	assert read_pixels(source, 2, 2, 0, 1, mut destination, 2, 2, 8, 0, 0)
	assert destination == [u8(1), 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8]
}
