// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_buffer_uploads_forward_without_retained_bindings_and_select_the_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		buffer := owner.create_buffer()
		// The driver binding deliberately bypasses the retained source slots.
		C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
		assert array_buffer !in owner.bound_buffers
		other.native.make_current()
		owner.buffer_data(array_buffer, [u8(1), 2, 3, 4], GLenum(0x88e4))
		mut actual_viewport := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &actual_viewport[0])
		assert actual_viewport == [i32(1), 2, 3, 4]!
		assert owner.get_buffer_parameter(array_buffer, buffer_size).integer == 4
		assert owner.get_buffer_parameter(array_buffer, buffer_usage).integer == 0x88e4
		assert owner.get_error() == no_error
		owner.buffer_sub_data(array_buffer, 1, [u8(9), 8])
		assert owner.get_error() == no_error
		if version == .webgl2 {
			mut bytes := []u8{len: 4}
			read := C.vox_gl_read_buffer_sub_data(array_buffer, 0, 4, bytes.data)
			assert read == 1
			assert bytes == [u8(1), 9, 8, 4]
		}
		other.native.make_current()
		owner.buffer_data_size(array_buffer, 7, GLenum(0x88e8))
		C.vox_gl_int_parameter(viewport, &actual_viewport[0])
		assert actual_viewport == [i32(1), 2, 3, 4]!
		assert owner.get_buffer_parameter(array_buffer, buffer_size).integer == 7
		assert owner.get_buffer_parameter(array_buffer, buffer_usage).integer == 0x88e8
		assert owner.get_error() == no_error
		owner.buffer_data(GLenum(0xbad), [u8(1)], GLenum(0x88e4))
		assert owner.get_error() == invalid_enum
		owner.buffer_data_size(GLenum(0xbad), -1, GLenum(0x88e4))
		assert owner.get_error() == invalid_value
		owner.buffer_sub_data(GLenum(0xbad), -1, [u8(1)])
		assert owner.get_error() == invalid_value
		other.native.make_current()
		owner.buffer_sub_data(array_buffer, -1, [u8(1)])
		C.vox_gl_int_parameter(viewport, &actual_viewport[0])
		assert actual_viewport == [i32(1), 2, 3, 4]!
		assert owner.get_error() == invalid_value
		C.vox_gl_bind_buffer(array_buffer, 0)
		owner.buffer_data(array_buffer, [u8(1)], GLenum(0x88e4))
		assert owner.get_error() == invalid_operation
	}
}
