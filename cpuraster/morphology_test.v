module cpuraster

import math
import os

fn morphology_test_image(width int, height int) BlurImage {
	pixels := []u8{len: width * height * 4, init: u8((index * 37 + index / 131) & 255)}
	return BlurImage{pixels, width, height}
}

// Evaluate the rectangular neighborhood directly, including the decal border.
fn morphology_test_reference(image BlurImage, rx int, ry int, dilate bool) []u8 {
	mut result := []u8{len: image.pixels.len}
	for y in 0 .. image.height {
		for x in 0 .. image.width {
			for channel in 0 .. 4 {
				mut value := if dilate { u8(0) } else { u8(255) }
				for sy in y - ry .. y + ry + 1 {
					for sx in x - rx .. x + rx + 1 {
						inside := sx >= 0 && sx < image.width && sy >= 0 && sy < image.height
						sample := if inside {
							image.pixels[(sy * image.width + sx) * 4 + channel]
						} else {
							u8(0)
						}
						value = if dilate {
							math.max(value, sample)
						} else {
							math.min(value, sample)
						}
					}
				}
				result[(y * image.width + x) * 4 + channel] = value
			}
		}
	}
	return result
}

fn test_morphology_matches_rectangular_reference() {
	// The ascending runs keep minimum candidates in the queue long enough
	// for its head and tail to wrap on either axis.
	ramp := []u8{len: 1301 * 4, init: u8(index / 4 + index % 4)}
	for image in [morphology_test_image(13, 9), BlurImage{ramp, 1301, 1}, BlurImage{ramp, 1, 1301}] {
		for radii in [[0, 0]!, [0, 4]!, [3, 0]!, [2, 3]!] {
			for dilate in [true, false] {
				expected := morphology_test_reference(image, radii[0], radii[1], dilate)
				actual := general_morphology(image, radii[0], radii[1], dilate)
				pixels_match := actual.pixels == expected
				assert pixels_match
			}
		}
	}
	image := morphology_test_image(529, 1)
	for dilate in [true, false] {
		expected := morphology_test_reference(image, 256, 0, dilate)
		pixels_match := general_morphology(image, 300, -1, dilate).pixels == expected
		assert pixels_match
	}
}

fn test_parallel_morphology_matches_serial() {
	serial_setting := 'VOX_SERIAL_CPU_RASTER'
	previous := os.getenv_opt(serial_setting)
	defer {
		if value := previous {
			os.setenv(serial_setting, value, true)
		} else {
			os.unsetenv(serial_setting)
		}
	}

	image := morphology_test_image(1051, 509)
	original := image.pixels.clone()
	for dilate in [true, false] {
		assert os.setenv(serial_setting, '1', true) == 0
		serial := general_morphology(image, 7, 9, dilate)
		assert os.unsetenv(serial_setting) == 0
		parallel := general_morphology(image, 7, 9, dilate)
		pixels_match := parallel.pixels == serial.pixels
		assert pixels_match
	}
	input_unchanged := image.pixels == original
	assert input_unchanged
}
