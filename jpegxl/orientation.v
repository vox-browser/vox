// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub enum Orientation {
	identity = 1
	flip_horizontal
	rotate180
	flip_vertical
	transpose
	rotate90_cw
	anti_transpose
	rotate90_ccw
}

pub struct ImageRect {
pub:
	x      u32
	y      u32
	width  u32
	height u32
}

pub fn (orientation Orientation) map_size(size Size) Size {
	return if int(orientation) >= 5 { Size{ width: size.height, height: size.width } } else { size }
}

pub fn (orientation Orientation) display_row_step() (int, int) {
	return match orientation {
		.identity, .flip_vertical { 1, 0 }
		.flip_horizontal, .rotate180 { -1, 0 }
		.transpose, .rotate90_cw { 0, 1 }
		.anti_transpose, .rotate90_ccw { 0, -1 }
	}
}

pub fn (orientation Orientation) display_pixel(x u32, y u32, size Size) !(u32, u32) {
	if x >= size.width || y >= size.height { return error('JPEG XL pixel outside frame') }
	return match orientation {
		.identity { x, y }
		.flip_horizontal { size.width - 1 - x, y }
		.rotate180 { size.width - 1 - x, size.height - 1 - y }
		.flip_vertical { x, size.height - 1 - y }
		.transpose { y, x }
		.rotate90_cw { size.height - 1 - y, x }
		.anti_transpose { size.height - 1 - y, size.width - 1 - x }
		.rotate90_ccw { y, size.width - 1 - x }
	}
}

pub fn (orientation Orientation) display_rect(rect ImageRect, size Size) !ImageRect {
	if rect.x > size.width || rect.y > size.height || rect.width > size.width - rect.x || rect.height > size.height - rect.y {
		return error('JPEG XL rectangle outside frame')
	}
	return match orientation {
		.identity { rect }
		.flip_horizontal {
			ImageRect{ x: size.width - rect.width - rect.x, y: rect.y, width: rect.width, height: rect.height }
		}
		.rotate180 {
			ImageRect{ x: size.width - rect.width - rect.x, y: size.height - rect.height - rect.y, width: rect.width, height: rect.height }
		}
		.flip_vertical {
			ImageRect{ x: rect.x, y: size.height - rect.height - rect.y, width: rect.width, height: rect.height }
		}
		.transpose { ImageRect{ x: rect.y, y: rect.x, width: rect.height, height: rect.width } }
		.rotate90_cw {
			ImageRect{ x: size.height - rect.height - rect.y, y: rect.x, width: rect.height, height: rect.width }
		}
		.anti_transpose {
			ImageRect{ x: size.height - rect.height - rect.y, y: size.width - rect.width - rect.x, width: rect.height, height: rect.width }
		}
		.rotate90_ccw {
			ImageRect{ x: rect.y, y: size.width - rect.width - rect.x, width: rect.height, height: rect.width }
		}
	}
}
