// Skia-free CPU raster operations. Each function reproduces the bytes of the
// LibWeb Skia call it replaces; tools/gg_migration/test_cpu_raster.sh compares
// them with that Skia build.
module cpuraster

import math

// 1.0f / 255.0f
const inv_255 = math.f32_from_bits(0x3b808081)
const max_dimension = max_i32 >> 2

// SkBitmap::readPixels() from an sRGB RGBA_8888 bitmap (premultiplied when
// alpha_type is 2, otherwise unpremultiplied) into unpremultiplied sRGB
// RGBA_8888: SkBitmap::setInfo(), SkReadPixelsRec::trim() and SkConvertPixels'
// rect_memcpy() and NEON rgbA_to_RGBA() paths. Pixels outside the source stay
// untouched.
pub fn read_pixels(source []u8, width int, height int, pitch int, alpha_type int, mut destination []u8, destination_width int, destination_height int, destination_pitch int, x int, y int) bool {
	if width <= 0 || height <= 0 || width > max_dimension || height > max_dimension {
		return false
	}
	if destination_width <= 0 || destination_height <= 0 || destination_width > max_dimension
		|| destination_height > max_dimension {
		return false
	}
	// SkBitmap::installPixels() validates a zero pitch as the minimum row bytes
	// but keeps zero in its pixel ref, so every row then reads the first row.
	if pitch != 0 && (pitch < width * 4 || pitch % 4 != 0) {
		return false
	}
	if destination_pitch < destination_width * 4 || destination_pitch % 4 != 0 {
		return false
	}
	if x == min_i32 || y == min_i32 {
		return false
	}
	left := if x > 0 { x } else { 0 }
	top := if y > 0 { y } else { 0 }
	right := math.min(saturating_add(x, destination_width), width)
	bottom := math.min(saturating_add(y, destination_height), height)
	if left >= right || top >= bottom {
		return false
	}
	columns := right - left
	rows := bottom - top
	destination_x := if x < 0 { -x } else { 0 }
	destination_y := if y < 0 { -y } else { 0 }
	source_end := i64(pitch) * i64(bottom - 1) + i64(right) * 4
	destination_end := i64(destination_pitch) * i64(destination_y + rows - 1) +
		i64(destination_x + columns) * 4
	if source_end > i64(source.len) || destination_end > i64(destination.len) {
		return false
	}
	for row in 0 .. rows {
		source_offset := (top + row) * pitch + left * 4
		destination_offset := (destination_y + row) * destination_pitch + destination_x * 4
		if alpha_type != 2 {
			unsafe { vmemcpy(&destination[destination_offset], &source[source_offset], columns * 4) }
			continue
		}
		for column in 0 .. columns {
			offset := column * 4
			unpremultiply_pixel(source, source_offset + offset, mut destination, destination_offset +
				offset)
		}
	}
	return true
}

fn saturating_add(a int, b int) int {
	sum := i64(a) + i64(b)
	return if sum > max_i32 { max_i32 } else if sum < min_i32 { min_i32 } else { int(sum) }
}

// SkSwizzler_opts' rgbA_to_CCCA() with !kFastUnpremul. Its NEON block of eight
// pixels performs the same float operations, saturating instead of clamping.
@[inline]
fn unpremultiply_pixel(source []u8, source_offset int, mut destination []u8, destination_offset int) {
	alpha := source[source_offset + 3]
	normalized_alpha := f32(alpha) * inv_255
	reciprocal := if alpha == 0 { f32(0) } else { f32(1) / normalized_alpha }
	for channel in 0 .. 3 {
		destination[destination_offset + channel] = unpremultiply_channel(source[source_offset +
			channel], reciprocal)
	}
	destination[destination_offset + 3] = alpha
}

@[inline]
fn unpremultiply_channel(value u8, reciprocal_alpha f32) u8 {
	normalized := f32(value) * inv_255
	divided := normalized * reciprocal_alpha
	answer := math.min(f32(255), divided * f32(255))
	return u8(round_half_even(answer))
}

// vrndns_f32() and vcvtnq_u32_f32(): round to nearest, ties to even.
@[inline]
fn round_half_even(value f32) f32 {
	return f32(math.round_to_even(f64(value)))
}
