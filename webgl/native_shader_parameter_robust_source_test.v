// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glGetShaderivRobustANGLE(u32, u32, int, voidptr, &i32)

fn test_source_shader_parameter_uses_actual_one_element_robust_query() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut shader := owner.create_shader(vertex_shader) or { panic('robust parameter shader') }
		owner.shader_source(mut shader, 'this is not a shader')
		owner.compile_shader(mut shader)
		for pname in [shader_type, compile_status, delete_status, GLenum(0x8b84), GLenum(0xbad)] {
			owner.native.make_current()
			mut expected := i32(0)
			C.glGetShaderivRobustANGLE(shader.object.native_name(), pname, 1, unsafe { nil }, &expected)
			expected_error := C.vox_gl_get_error()
			other.native.make_current()
			actual := owner.get_shader_parameter(shader, pname)
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			if pname == shader_type {
				assert actual.kind == .integer
				assert actual.integer == expected
			} else if pname in [compile_status, delete_status] {
				assert actual.kind == .boolean
				assert actual.boolean == (expected == 1)
			} else {
				assert actual.kind == .none
			}
			if expected_error != no_error {
				assert owner.get_error() == expected_error
			}
			if pname !in [shader_type, compile_status, delete_status] {
				assert owner.get_error() == invalid_enum
			}
			assert owner.get_error() == no_error
		}
		// Source still owns this record while a genuine outside GL deletion makes
		// the driver's query reject it; no status mirror supplies the result.
		owner.native.make_current()
		C.vox_gl_delete_shader(shader.object.native_name())
		assert !shader.object.invalidated()
		mut rejected := i32(0)
		C.glGetShaderivRobustANGLE(shader.object.native_name(), shader_type, 1, unsafe { nil }, &rejected)
		expected_error := C.vox_gl_get_error()
		assert expected_error != no_error
		other.native.make_current()
		assert owner.get_shader_parameter(shader, shader_type).integer == rejected
		assert owner.get_error() == expected_error
		assert owner.get_error() == no_error
	}
}
