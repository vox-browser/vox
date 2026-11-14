// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn pixel_store_source_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &value[0])
	return value
}

fn test_source_pixel_store_early_client_branches_do_not_dispatch_to_actual_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.pixel_storei(unpack_alignment, 3)
		assert pixel_store_source_viewport() == [i32(9), 10, 11, 12]!
		assert context.unpack_state_.alignment == 4
		assert C.vox_gl_get_error() == no_error
		assert context.get_error() == invalid_value
		for pname in [unpack_flip_y_webgl, unpack_premultiply_alpha_webgl,
			unpack_colorspace_conversion_webgl] {
			other.native.make_current()
			context.pixel_storei(pname, -1)
			assert pixel_store_source_viewport() == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == no_error
		}
		assert context.unpack_flip_y_
		assert context.unpack_premultiply_alpha_
		assert context.unpack_colorspace_conversion_ == u32(-1)
		assert context.get_error() == no_error
		assert other.get_error() == no_error
	}
}

fn test_source_pixel_store_remaining_names_values_and_version_checks_belong_to_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for pname in [pack_alignment, unpack_alignment, pack_row_length, pack_skip_rows,
			pack_skip_pixels, unpack_row_length, unpack_skip_rows, unpack_skip_pixels,
			unpack_skip_images, unpack_image_height, GLenum(0xbad)] {
			for parameter in [-1, 3, 8] {
				// The only source early validation is UNPACK_ALIGNMENT.
				if pname == unpack_alignment && parameter !in [1, 2, 4, 8] { continue }
				context.native.make_current()
				C.vox_gl_pixel_storei(pname, parameter)
				expected_error := C.vox_gl_get_error()
				context.set_error(invalid_operation)
				other.native.make_current()
				context.pixel_storei(pname, parameter)
				assert pixel_store_source_viewport() == [i32(1), 2, 3, 4]!
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_operation
				assert context.get_error() == no_error
			}
		}
		// Source changes only nonnegative WebGL2 row/skip client values.
		if version == .webgl2 {
			for pname in [unpack_row_length, unpack_skip_rows, unpack_skip_pixels] {
				context.pixel_storei(pname, 2)
				context.pixel_storei(pname, -1)
				assert context.get_error() == invalid_value
			}
			assert context.unpack_state_.row_length == 2
			assert context.unpack_state_.skip_rows == 2
			assert context.unpack_state_.skip_pixels == 2
		}
		assert other.get_error() == no_error
	}
}

fn test_native_convenience_readback_uses_actual_driver_pack_alignment() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(1, 2)
		context.clear_color(1, 0.25, 0, 1)
		context.clear(0x4000)
		C.vox_gl_pixel_storei(pack_alignment, 8)
		other.native.make_current()
		pixels := context.read_pixels(0, 0, 1, 2, rgba, unsigned_byte)
		assert pixels.len == 12
		assert pixels[..4] == [u8(255), 64, 0, 255]
		assert pixels[8..] == [u8(255), 64, 0, 255]
		assert context.get_error() == no_error
	}
}
