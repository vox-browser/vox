module main

import math
import os
import stbi

fn absolute_byte_difference(a u8, b u8) u8 {
	return if a >= b { a - b } else { b - a }
}

fn main() {
	if os.args.len != 4 {
		eprintln('usage: pixel_diff EXPECTED.png ACTUAL.png DIFF.png')
		exit(2)
	}
	expected_path := os.args[1]
	actual_path := os.args[2]
	diff_path := os.args[3]
	expected := stbi.load(expected_path) or { panic(err) }
	defer {
		expected.free()
	}
	actual := stbi.load(actual_path) or { panic(err) }
	defer {
		actual.free()
	}
	if expected.width != actual.width || expected.height != actual.height {
		eprintln('dimension mismatch: expected ${expected.width}x${expected.height}, actual ${actual.width}x${actual.height}')
		exit(2)
	}
	pixel_count := expected.width * expected.height
	mut different_pixels := 0
	mut pixels_over_3 := 0
	mut pixels_over_10 := 0
	mut pixels_over_25 := 0
	mut pixels_over_50 := 0
	mut maximum_error := u8(0)
	mut squared_error_sum := f64(0)
	mut absolute_error_sum := u64(0)
	mut diff := []u8{len: pixel_count * 4}
	unsafe {
		for pixel in 0 .. pixel_count {
			offset := pixel * 4
			mut pixel_error := u8(0)
			for channel in 0 .. 4 {
				channel_error := absolute_byte_difference(expected.data[offset + channel], actual.data[offset + channel])
				if channel_error > pixel_error {
					pixel_error = channel_error
				}
				if channel_error > maximum_error {
					maximum_error = channel_error
				}
				absolute_error_sum += channel_error
				squared_error_sum += f64(channel_error) * f64(channel_error)
			}
			if pixel_error > 0 {
				different_pixels++
			}
			if pixel_error > 3 {
				pixels_over_3++
			}
			if pixel_error > 10 {
				pixels_over_10++
			}
			if pixel_error > 25 {
				pixels_over_25++
			}
			if pixel_error > 50 {
				pixels_over_50++
			}
			// A black pixel is equal. Amplify small differences so antialiasing deltas remain visible.
			intensity := if int(pixel_error) * 4 > 255 { u8(255) } else { u8(int(pixel_error) * 4) }
			diff[offset] = intensity
			diff[offset + 1] = u8(int(pixel_error) / 4)
			diff[offset + 2] = u8(int(pixel_error) / 4)
			diff[offset + 3] = 255
		}
	}
	stbi.set_flip_vertically_on_write(false)
	stbi.stbi_write_png(diff_path, expected.width, expected.height, 4, diff.data, expected.width * 4) or { panic(err) }
	channel_count := f64(pixel_count * 4)
	mean_absolute_error := f64(absolute_error_sum) / channel_count
	rmse := math.sqrt(squared_error_sum / channel_count)
	different_percent := f64(different_pixels) * 100.0 / f64(pixel_count)
	println('pixels: ${pixel_count}')
	println('different_pixels: ${different_pixels} (${different_percent:.4f}%)')
	println('pixels_over_3: ${pixels_over_3} (${f64(pixels_over_3) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_10: ${pixels_over_10} (${f64(pixels_over_10) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_25: ${pixels_over_25} (${f64(pixels_over_25) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_50: ${pixels_over_50} (${f64(pixels_over_50) * 100.0 / f64(pixel_count):.4f}%)')
	println('maximum_channel_error: ${maximum_error}')
	println('mean_absolute_error: ${mean_absolute_error:.4f}')
	println('rmse: ${rmse:.4f}')
	println('diff: ${diff_path}')
}
