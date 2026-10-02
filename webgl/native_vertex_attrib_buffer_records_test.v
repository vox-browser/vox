// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_vertex_attrib_buffer_query_creates_fresh_zero_and_native_handle_records() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		zero_one := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding)
		zero_two := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding)
		assert zero_one.kind == .object
		assert zero_two.kind == .object
		first_zero := zero_one.buffer or { panic('zero buffer') }
		second_zero := zero_two.buffer or { panic('second zero buffer') }
		assert first_zero.object.native_handle_ == 0
		assert second_zero.object.native_handle_ == 0
		assert voidptr(first_zero) != voidptr(second_zero)
		assert !context.is_buffer(first_zero)
		original := context.create_buffer()
		context.bind_buffer(array_buffer, original)
		context.buffer_data(array_buffer, [u8(1), 2, 3, 4], GLenum(0x88e4))
		context.vertex_attrib_pointer(0, 1, unsigned_byte, false, 0, 0)
		first := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or { panic('first queried buffer') }
		second := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or { panic('second queried buffer') }
		assert voidptr(first) != voidptr(original)
		assert voidptr(second) != voidptr(original)
		assert voidptr(first) != voidptr(second)
		assert first.object.native_handle_ == original.object.native_handle_
		assert second.object.native_handle_ == original.object.native_handle_
		context.bind_buffer(array_buffer, first)
		assert context.get_buffer_parameter(array_buffer, buffer_size).integer == 4
		context.buffer_sub_data(array_buffer, 1, [u8(9)])
		if version == .webgl2 {
			context.native.make_current()
			mut actual := []u8{len: 4}
			read := C.vox_gl_read_buffer_sub_data(array_buffer, 0, 4, actual.data)
			assert read == 1
			assert actual == [u8(1), 9, 3, 4]
		}
		assert context.get_error() == no_error
		invalid := context.get_vertex_attrib(0xffffffff, vertex_attrib_array_buffer_binding).buffer or { panic('source invalid-index zero record') }
		assert invalid.object.native_handle_ == 0
		assert context.get_error() == invalid_value
		assert context.get_error() == no_error
	}
}
