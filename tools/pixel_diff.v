module main

import math
import os
import strconv
import stbi

fn absolute_byte_difference(a u8, b u8) u8 {
	return if a >= b { a - b } else { b - a }
}

fn main() {
	if os.args.len != 4 && os.args.len != 5 && os.args.len != 6 && os.args.len != 8 {
		eprintln('usage: pixel_diff EXPECTED.png ACTUAL.png DIFF.png [mismatch | MAX_CHANNEL_ERROR MAX_DIFFERENT_PIXELS [SPARSE_MAX_CHANNEL_ERROR SPARSE_OUTLIER_PIXELS]]')
		exit(2)
	}
	is_mismatch := os.args.len == 5 && os.args[4] == 'mismatch'
	if os.args.len == 5 && !is_mismatch {
		eprintln('invalid comparison relation: ${os.args[4]}')
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
	mut minimum_x := expected.width
	mut minimum_y := expected.height
	mut maximum_x := -1
	mut maximum_y := -1
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
				x := pixel % expected.width
				y := pixel / expected.width
				minimum_x = math.min(minimum_x, x)
				minimum_y = math.min(minimum_y, y)
				maximum_x = math.max(maximum_x, x)
				maximum_y = math.max(maximum_y, y)
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
	if different_pixels > 0 {
		println('difference_bounds: ${minimum_x},${minimum_y} ${maximum_x - minimum_x + 1}x${maximum_y - minimum_y + 1}')
		mut reported := 0
		unsafe {
			for pixel in 0 .. pixel_count {
				if reported >= 8 {
					break
				}
				offset := pixel * 4
				mut pixel_error := u8(0)
				for channel in 0 .. 4 {
					pixel_error = math.max(pixel_error, absolute_byte_difference(expected.data[offset + channel], actual.data[offset + channel]))
				}
				if pixel_error == maximum_error {
					x := pixel % expected.width
					y := pixel / expected.width
					println('maximum_error_pixel: ${x},${y} expected=${expected.data[offset]},${expected.data[offset + 1]},${expected.data[offset + 2]},${expected.data[offset + 3]} actual=${actual.data[offset]},${actual.data[offset + 1]},${actual.data[offset + 2]},${actual.data[offset + 3]}')
					reported++
				}
			}
		}
	}
	println('pixels_over_3: ${pixels_over_3} (${f64(pixels_over_3) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_10: ${pixels_over_10} (${f64(pixels_over_10) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_25: ${pixels_over_25} (${f64(pixels_over_25) * 100.0 / f64(pixel_count):.4f}%)')
	println('pixels_over_50: ${pixels_over_50} (${f64(pixels_over_50) * 100.0 / f64(pixel_count):.4f}%)')
	println('maximum_channel_error: ${maximum_error}')
	println('mean_absolute_error: ${mean_absolute_error:.4f}')
	println('rmse: ${rmse:.4f}')
	println('diff: ${diff_path}')
	if is_mismatch {
		if different_pixels == 0 {
			eprintln('FAIL: mismatch reference rendered identically')
			exit(1)
		}
		println('PASS: mismatch reference differs by ${different_pixels} pixels')
		return
	}
	if os.args.len == 6 || os.args.len == 8 {
		allowed_maximum_error := strconv.atoi(os.args[4]) or {
			eprintln('invalid maximum channel error: ${os.args[4]}')
			exit(2)
		}
		allowed_different_pixels := strconv.atoi(os.args[5]) or {
			eprintln('invalid maximum different-pixel count: ${os.args[5]}')
			exit(2)
		}
		mut outlier_pixels := 0
		if int(maximum_error) > allowed_maximum_error {
			mut reported := 0
			unsafe {
				for pixel in 0 .. pixel_count {
					offset := pixel * 4
					mut pixel_error := u8(0)
					for channel in 0 .. 4 {
						pixel_error = math.max(pixel_error, absolute_byte_difference(expected.data[offset + channel], actual.data[offset + channel]))
					}
					if int(pixel_error) > allowed_maximum_error {
						outlier_pixels++
						if reported < 32 {
							x := pixel % expected.width
							y := pixel / expected.width
							println('out_of_tolerance_pixel: ${x},${y} error=${pixel_error} expected=${expected.data[offset]},${expected.data[offset + 1]},${expected.data[offset + 2]},${expected.data[offset + 3]} actual=${actual.data[offset]},${actual.data[offset + 1]},${actual.data[offset + 2]},${actual.data[offset + 3]}')
							reported++
						}
					}
				}
			}
		}
		mut sparse_maximum_error := allowed_maximum_error
		mut sparse_outlier_pixels := 0
		if os.args.len == 8 {
			sparse_maximum_error = strconv.atoi(os.args[6]) or {
				eprintln('invalid sparse maximum channel error: ${os.args[6]}')
				exit(2)
			}
			sparse_outlier_pixels = strconv.atoi(os.args[7]) or {
				eprintln('invalid sparse outlier-pixel count: ${os.args[7]}')
				exit(2)
			}
		}
		sparse_variance_ok := int(maximum_error) <= sparse_maximum_error
			&& outlier_pixels <= sparse_outlier_pixels
			&& different_pixels <= allowed_different_pixels + sparse_outlier_pixels
		if (int(maximum_error) > allowed_maximum_error
			|| different_pixels > allowed_different_pixels) && !sparse_variance_ok {
			eprintln('FAIL: allowed maximum_channel_error=${allowed_maximum_error}, different_pixels=${allowed_different_pixels}')
			if os.args.len == 8 {
				eprintln('FAIL: sparse allowance maximum_channel_error=${sparse_maximum_error}, outlier_pixels=${sparse_outlier_pixels}; observed outlier_pixels=${outlier_pixels}')
			}
			exit(1)
		}
		if int(maximum_error) <= allowed_maximum_error
			&& different_pixels <= allowed_different_pixels {
			println('PASS: within maximum_channel_error=${allowed_maximum_error}, different_pixels=${allowed_different_pixels}')
		} else {
			println('PASS: within sparse maximum_channel_error=${sparse_maximum_error}, outlier_pixels=${sparse_outlier_pixels}; observed outlier_pixels=${outlier_pixels}')
		}
	}
}
