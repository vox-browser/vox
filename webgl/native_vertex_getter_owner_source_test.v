// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_vertex_getters_preserve_source_early_gate_and_real_sync_owner_selection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut early_names := [GLenum(0xffff)]
		if version == .webgl1 {
			early_names << vertex_attrib_array_integer
			early_names << vertex_attrib_array_divisor
		}
		for pname in early_names {
			context.native.make_current()
			C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
			other.native.make_current()
			result := context.get_vertex_attrib(0xffff_ffff, pname)
			assert result.kind == .none
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == no_error
			assert context.get_error() == invalid_value
			assert context.get_error() == invalid_enum
			assert context.get_error() == no_error
		}
		other.native.make_current()
		assert context.get_vertex_attrib_offset(0xffff_ffff, GLenum(0xffff)) == 0
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_enum
		buffer := context.create_buffer()
		context.bind_buffer(array_buffer, buffer)
		context.buffer_data_size(array_buffer, 64, GLenum(0x88e4))
		context.vertex_attrib_pointer(2, 2, unsigned_byte, true, 8, 4)
		context.enable_vertex_attrib_array(2)
		context.vertex_attrib4f(2, 1, 2, 3, 4)
		mut names := [vertex_attrib_array_size, vertex_attrib_array_stride, vertex_attrib_array_type,
			vertex_attrib_array_enabled, vertex_attrib_array_normalized]
		if version == .webgl2 {
			context.vertex_attrib_divisor(2, 17)
			names << vertex_attrib_array_integer
			names << vertex_attrib_array_divisor
		}
		for pname in names {
			context.native.make_current()
			expected := C.vox_gl_vertex_attrib_parameter(2, pname)
			other.native.make_current()
			result := context.get_vertex_attrib(2, pname)
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			if pname in [vertex_attrib_array_enabled, vertex_attrib_array_normalized,
				vertex_attrib_array_integer] {
				assert result.kind == .boolean
				assert result.boolean == (expected == 1)
			} else {
				assert result.kind == .integer
				assert result.integer == i64(expected)
			}
		}
		other.native.make_current()
		assert context.get_vertex_attrib(2, current_vertex_attrib).numbers == [f64(1), 2, 3, 4]
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		other.native.make_current()
		assert context.get_vertex_attrib_offset(2, vertex_attrib_array_pointer) == 4
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		first := context.get_vertex_attrib(2, vertex_attrib_array_buffer_binding).buffer or { panic('first source buffer') }
		second := context.get_vertex_attrib(2, vertex_attrib_array_buffer_binding).buffer or { panic('second source buffer') }
		assert first != second
		assert first != buffer
		assert first.object.native_handle_ == buffer.object.native_handle_
		assert second.object.native_handle_ == buffer.object.native_handle_
		assert context.get_error() == no_error
	}
}
