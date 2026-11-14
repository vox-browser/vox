module imageraster

import math
import cpuraster

pub struct Image {
pub:
	width  int
	height int
	pixels []u8
}

// Decode requests use a power-of-two size, rounded up in each dimension.
// The CPU resize chooses its own mip from that rounded size before filtering.
pub fn decode_size(width int, height int, target_width f64, target_height f64) ?(int, int) {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || target_width <= 0 || target_height <= 0
		|| math.is_nan(target_width) || math.is_nan(target_height)
		|| math.is_inf(target_width, 0) || math.is_inf(target_height, 0) {
		return none
	}
	ratio := math.max(f64(width) / target_width, f64(height) / target_height)
	if ratio <= 1 { return none }
	mut divisor := 1
	for divisor < 4096
		&& f64((width + divisor * 2 - 1) / (divisor * 2)) >= target_width
		&& f64((height + divisor * 2 - 1) / (divisor * 2)) >= target_height {
		divisor *= 2
	}
	return math.max(1, (width + divisor - 1) / divisor), math.max(1, (height + divisor - 1) / divisor)
}

// Retain the complete CPU mip chain for the image shader's trilinear filter.
pub fn mip_chain(source Image) ?[]Image {
	if source.width <= 0 || source.height <= 0 || source.width > 4096 || source.height > 4096
		|| source.width * source.height > 4 * 1024 * 1024 || source.pixels.len != source.width * source.height * 4 {
		return none
	}
	mut levels := [source]
	for levels.last().width > 1 || levels.last().height > 1 { levels << halve(levels.last()) }
	return levels
}

pub fn decode_rgba(source []u8, width int, height int, decoded_width int, decoded_height int) ?Image {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || source.len != width * height * 4
		|| decoded_width <= 0 || decoded_height <= 0
		|| decoded_width > width || decoded_height > height {
		return none
	}
	mut pixels := source.clone()
	for i in 0 .. width * height {
		for c in 0 .. 3 {
			pixels[i * 4 + c] = u8((u32(pixels[i * 4 + c]) * pixels[i * 4 + 3] + 127) / 255)
		}
	}
	mut image := Image{ width: width, height: height, pixels: pixels }
	ratio := math.max(f64(width) / decoded_width, f64(height) / decoded_height)
	mut divisor := 1
	for f64(divisor * 2) <= ratio && divisor < 4096 {
		image = halve(image)
		divisor *= 2
	}
	return resize(image, decoded_width, decoded_height)
}

fn halve(source Image) Image {
	width, height := math.max(1, source.width / 2), math.max(1, source.height / 2)
	wx := if source.width == 1 {
		[1]
	} else if source.width % 2 != 0 {
		[1, 2, 1]
	} else {
		[1, 1]
	}
	wy := if source.height == 1 {
		[1]
	} else if source.height % 2 != 0 {
		[1, 2, 1]
	} else {
		[1, 1]
	}
	mut denominator := 0
	for x in wx {
		for y in wy { denominator += x * y }
	}
	mut output := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			for c in 0 .. 4 {
				mut value := 0
				for dy, yy in wy {
					for dx, xx in wx {
						value += int(source.pixels[((2 * y + dy) * source.width + 2 * x + dx) * 4 + c]) * xx * yy
					}
				}
				output[(y * width + x) * 4 + c] = u8(value / denominator)
			}
		}
	}
	return Image{ width: width, height: height, pixels: output }
}

fn resize(source Image, width int, height int) Image {
	if source.width == width && source.height == height { return source }
	output := cpuraster.resize_premultiplied_rgba(source.pixels, source.width, source.height, width, height) or { return Image{} }
	return Image{ width: width, height: height, pixels: output }
}
