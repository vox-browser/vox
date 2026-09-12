// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL/TextureUpload.{h,cpp}.
module webgl

// TextureExportFormat is the bitmap byte layout accepted by the host-side
// texture conversion path.
pub enum TextureExportFormat {
	rgb888
	rgb565
	rgba8888
	rgba4444
	rgba5551
	alpha8
	gray8
}

pub fn texture_export_format(format GLenum, type_ GLenum) ?TextureExportFormat {
	match format {
		rgb {
			return match type_ {
				unsigned_byte { TextureExportFormat.rgb888 }
				unsigned_short_5_6_5 { TextureExportFormat.rgb565 }
				else { none }
			}
		}
		rgba {
			return match type_ {
				unsigned_byte { TextureExportFormat.rgba8888 }
				// FIXME: This is not exactly the same as RGBA.
				unsigned_short_4_4_4_4 { TextureExportFormat.rgba4444 }
				unsigned_short_5_5_5_1 { TextureExportFormat.rgba5551 }
				else { none }
			}
		}
		alpha {
			if type_ == unsigned_byte {
				return .alpha8
			}
		}
		luminance {
			if type_ == unsigned_byte {
				return .gray8
			}
		}
		else {}
	}
	return none
}

fn component_count_for_format(format GLenum) ?u64 {
	return match format {
		alpha, luminance, red, red_integer, depth_component { u64(1) }
		luminance_alpha, rg, rg_integer { u64(2) }
		rgb, rgb_integer { u64(3) }
		rgba, rgba_integer { u64(4) }
		else { none }
	}
}

fn bytes_per_pixel(format GLenum, type_ GLenum) ?u64 {
	match type_ {
		unsigned_short_5_6_5, unsigned_short_4_4_4_4, unsigned_short_5_5_5_1 {
			return 2
		}
		unsigned_int_2_10_10_10_rev, unsigned_int_10f_11f_11f_rev, unsigned_int_5_9_9_9_rev, unsigned_int_24_8 {
			return 4
		}
		float_32_unsigned_int_24_8_rev {
			return 8
		}
		else {}
	}

	component_count := component_count_for_format(format) or { return none }
	component_size := match type_ {
		gl_byte, unsigned_byte { u64(1) }
		gl_short, unsigned_short, half_float { u64(2) }
		gl_int, unsigned_int, gl_float { u64(4) }
		else {
			return none
		}
	}
	return component_count * component_size
}

fn checked_add_u64(left u64, right u64) ?u64 {
	if left > max_u64 - right {
		return none
	}
	return left + right
}

fn checked_mul_u64(left u64, right u64) ?u64 {
	if right != 0 && left > max_u64 / right {
		return none
	}
	return left * right
}

pub fn is_valid_2d_pixel_unpack_state(width GLsizei, unpack_state PixelUnpackState) bool {
	if width < 0 {
		return true
	}
	data_store_width := if unpack_state.row_length == 0 {
		u64(width)
	} else {
		unpack_state.row_length
	}
	unpacked_row_end := checked_add_u64(unpack_state.skip_pixels, u64(width)) or {
		return false
	}
	return unpacked_row_end <= data_store_width
}

pub fn required_2d_texture_data_size(width GLsizei, height GLsizei, format GLenum, type_ GLenum, unpack_state PixelUnpackState) ?u64 {
	if width < 0 || height < 0 {
		return none
	}
	if !is_valid_2d_pixel_unpack_state(width, unpack_state) {
		return none
	}
	if width == 0 || height == 0 {
		return 0
	}

	pixel_size := bytes_per_pixel(format, type_) or { return none }
	if unpack_state.alignment !in [u64(1), 2, 4, 8] {
		return none
	}

	row_pixels := if unpack_state.row_length == 0 {
		u64(width)
	} else {
		unpack_state.row_length
	}
	row_bytes := checked_mul_u64(row_pixels, pixel_size) or { return none }
	padded_row_bytes := checked_add_u64(row_bytes, unpack_state.alignment - 1) or {
		return none
	}
	aligned_row_bytes := padded_row_bytes / unpack_state.alignment * unpack_state.alignment

	skipped_rows_size := checked_mul_u64(unpack_state.skip_rows, aligned_row_bytes) or {
		return none
	}
	skipped_pixels_size := checked_mul_u64(unpack_state.skip_pixels, pixel_size) or {
		return none
	}
	remaining_rows_size := checked_mul_u64(u64(height - 1), aligned_row_bytes) or {
		return none
	}
	final_row_size := checked_mul_u64(u64(width), pixel_size) or { return none }

	mut required_size := checked_add_u64(skipped_rows_size, skipped_pixels_size) or {
		return none
	}
	required_size = checked_add_u64(required_size, remaining_rows_size) or { return none }
	return checked_add_u64(required_size, final_row_size)
}
