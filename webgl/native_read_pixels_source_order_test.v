// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn read_pixels_source_current_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &value[0])
	return value
}

fn test_source_read_pixels_keeps_prior_driver_error_and_actual_destination_bytes() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(2, 2)
		context.clear_color(1, 0.25, 0.5, 1)
		context.clear(GLenum(0x4000))
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		mut pixels := []u8{len: 12, init: 99}
		context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut pixels, 0, 1)
		assert read_pixels_source_current_viewport() == [i32(1), 2, 3, 4]!
		assert pixels == [u8(255), 64, 128, 255, 99, 99, 99, 99, 99, 99, 99, 99]
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
		other.native.make_current()
		context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut pixels, u64(-1), 4)
		assert read_pixels_source_current_viewport() == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
		other.native.make_current()
		context.read_pixels_null()
		assert read_pixels_source_current_viewport() == if version == .webgl1 {
			[i32(1), 2, 3, 4]!
		} else {
			[i32(9), 10, 11, 12]!
		}
		assert context.get_error() == invalid_value
		if version == .webgl2 {
			other.native.make_current()
			context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 4)
			assert read_pixels_source_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_operation
			buffer := context.create_buffer()
			context.bind_buffer(pixel_pack_buffer, buffer)
			context.buffer_data(pixel_pack_buffer, []u8{len: 12, init: 99}, GLenum(0x88e4))
			context.native.make_current()
			C.vox_gl_enable(0xbad)
			other.native.make_current()
			context.read_pixels_into_pixel_pack_buffer(0, 0, 1, 1, rgba, unsigned_byte, 4)
			assert read_pixels_source_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_enum
			assert context.get_error() == no_error
			context.get_buffer_sub_data_into(pixel_pack_buffer, 0, mut pixels, 0, 0, 1)
			assert pixels == [u8(99), 99, 99, 99, 255, 64, 128, 255, 99, 99, 99, 99]
			other.native.make_current()
			context.read_pixels_into(0, 0, 1, 1, rgba, unsigned_byte, mut pixels, 0, 1)
			assert read_pixels_source_current_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == invalid_operation
		}
		assert other.get_error() == no_error
	}
}
