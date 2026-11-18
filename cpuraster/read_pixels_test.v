module cpuraster

import crypto.sha256
import os

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

fn test_large_pixel_read_matches_serial_with_clipping_and_padding() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	width, height := 1051, 533
	pitch := width * 4 + 20
	dw, dh := width + 10, height + 8
	dp := dw * 4 + 28
	for stride in [pitch, 0] {
		source_size := if stride == 0 { width * 4 } else { pitch * height }
		source := []u8{len: source_size, init: u8((index * 19 + index / 131) & 255)}
		original := source.clone()
		mut serial := []u8{len: dp * dh, init: 0x6b}
		mut parallel := serial.clone()
		assert os.setenv(serial_setting, '1', true) == 0
		assert read_pixels(source, width, height, stride, 2, mut serial, dw, dh, dp, -7, -3)
		assert os.unsetenv(serial_setting) == 0
		assert read_pixels(source, width, height, stride, 2, mut parallel, dw, dh, dp, -7, -3)
		pixels_match := parallel == serial
		source_unchanged := source == original
		assert pixels_match
		assert source_unchanged
		assert parallel[0] == 0x6b
		assert parallel[3 * dp + 7 * 4 + 3] == source[3]
		assert parallel[4 * dp - 1] == 0x6b
		assert parallel.last() == 0x6b
	}
}

fn test_overlapping_pixel_views_keep_serial_row_order() {
	width, rows := 1025, 545
	pitch := width * 4
	mut backing := []u8{len: pitch * (rows + 1), init: if index % 4 == 3 {
		u8(255)
	} else {
		u8((index / pitch + index % pitch) & 255)
	}}
	first_row := backing[..pitch].clone()
	source := unsafe { backing[..pitch * rows] }
	mut destination := unsafe { backing[pitch..] }
	assert uint(source.data) + uint(pitch) == uint(destination.data)
	assert read_pixels(source, width, rows, pitch, 2, mut destination, width, rows, pitch, 0, 0)
	// Each row reads the preceding row that the serial pass has just written.
	for row in 0 .. rows {
		pixels_match := destination[row * pitch..(row + 1) * pitch] == first_row
		assert pixels_match, 'shifted row ${row} differs'
	}
}
