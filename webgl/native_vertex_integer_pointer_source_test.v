// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn integer_pointer_source_driver_state() []i64 {
	mut result := []i64{}
	for pname in [vertex_attrib_array_size, vertex_attrib_array_type, vertex_attrib_array_stride,
		vertex_attrib_array_integer, vertex_attrib_array_buffer_binding] {
		result << i64(C.vox_gl_vertex_attrib_parameter(0, pname))
	}
	result << C.vox_gl_vertex_attrib_offset(0)
	return result
}

fn test_integer_vertex_pointer_forwards_all_source_arguments_to_actual_driver() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	buffer := context.create_buffer()
	cases := [[i64(0), 2, 0x1404, 0, 0], [i64(0), 4, 0x1401, 16, 4], [i64(0), 0, 0x1404, 0, 0],
		[i64(0), 5, 0x1404, 0, 0], [i64(0), 2, 0x1404, -1, 0], [i64(0), 2, 0x1404, 256, 0],
		[i64(0), 2, 0x1404, 0, -1], [i64(0), 2, 0x1404, 0, 1], [i64(0), 0, 0x1404, -1, 4],
		[i64(0), 2, 0xffff, 0, 0], [i64(0xffff_ffff), 2, 0x1404, 0, 0]]
	for bound in [false, true] {
		if bound {
			context.bind_buffer(array_buffer, buffer)
		} else {
			context.bind_buffer(array_buffer, none)
		}
		for item in cases {
			context.native.make_current()
			C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
			C.vox_gl_vertex_attrib_pointer(0, 4, gl_float, 0, 0, 0)
			C.vox_gl_bind_buffer(array_buffer, if bound { buffer.object.native_handle_ } else { 0 })
			C.vox_gl_vertex_attrib_i_pointer(u32(item[0]), int(item[1]), u32(item[2]), int(item[3]), item[4])
			expected_error := C.vox_gl_get_error()
			expected := integer_pointer_source_driver_state()
			C.vox_gl_bind_buffer(array_buffer, buffer.object.native_handle_)
			C.vox_gl_vertex_attrib_pointer(0, 4, gl_float, 0, 0, 0)
			C.vox_gl_bind_buffer(array_buffer, if bound { buffer.object.native_handle_ } else { 0 })
			context.set_error(invalid_operation)
			other.native.make_current()
			context.vertex_attrib_i_pointer(GLuint(item[0]), int(item[1]), GLenum(item[2]), int(item[3]), item[4])
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert integer_pointer_source_driver_state() == expected
			if expected_error != no_error {
				assert context.get_error() == expected_error
			}
			assert context.get_error() == invalid_operation
			assert context.get_error() == no_error
			assert other.get_error() == no_error
		}
	}
}
