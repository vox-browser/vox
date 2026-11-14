// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_renderbuffer_parameter_source_name_gate_precedes_actual_sync_owner_selection() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		assert context.get_renderbuffer_parameter(GLenum(0xffff), GLenum(0xffff)).kind == .none
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == no_error
		assert context.get_error() == invalid_value
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
		context.native.make_current()
		native_buffer := C.vox_gl_gen_object(2)
		C.vox_gl_bind_renderbuffer(renderbuffer, native_buffer)
		C.vox_gl_renderbuffer_storage(renderbuffer, 0x8056, 5, 7)
		assert context.bound_renderbuffer_object == none
		assert C.vox_gl_get_error() == no_error
		for target in [renderbuffer, GLenum(0xffff)] {
			for pname in [GLenum(0x8d42), 0x8d43, 0x8d44, 0x8d50, 0x8d51, 0x8d52, 0x8d53, 0x8d54,
				0x8cab, 0x8d55] {
				context.native.make_current()
				expected := C.vox_gl_renderbuffer_parameter(target, pname)
				expected_error := C.vox_gl_get_error()
				context.set_error(invalid_operation)
				other.native.make_current()
				result := context.get_renderbuffer_parameter(target, pname)
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert result.kind == .integer
				assert result.integer == i64(expected)
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_operation
				assert context.get_error() == no_error
			}
		}
		context.native.make_current()
		C.vox_gl_bind_renderbuffer(renderbuffer, 0)
		expected_unbound := C.vox_gl_renderbuffer_parameter(renderbuffer, 0x8d42)
		expected_error := C.vox_gl_get_error()
		other.native.make_current()
		assert context.get_renderbuffer_parameter(renderbuffer, 0x8d42).integer == expected_unbound
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_error
		C.vox_gl_delete_object(2, native_buffer)
	}
}
