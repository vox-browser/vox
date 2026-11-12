// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glGetProgramivRobustANGLE(u32, u32, int, voidptr, &i32)

fn test_source_program_parameter_matches_exact_one_element_robust_driver_query() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		program := owner.create_program()
		owner.native.make_current()
		C.vox_gl_link_program(program.object.native_name())
		assert C.vox_gl_program_parameter(program.object.native_name(), GLenum(0x8b84)) > 1
		for pname in [attached_shaders, active_attributes, active_uniforms, link_status, delete_status,
			validate_status, transform_feedback_buffer_mode, transform_feedback_varyings,
			active_uniform_blocks, GLenum(0x8b84), GLenum(0xbad)] {
			owner.native.make_current()
			mut expected := i32(0)
			C.glGetProgramivRobustANGLE(program.object.native_name(), pname, 1, unsafe { nil }, &expected)
			expected_error := C.vox_gl_get_error()
			other.native.make_current()
			actual := owner.get_program_parameter(program, pname)
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			numeric := pname in [attached_shaders, active_attributes, active_uniforms] || (version == .webgl2 && pname in [
				transform_feedback_buffer_mode,
				transform_feedback_varyings,
				active_uniform_blocks,
			])
			boolean := pname in [link_status, delete_status, validate_status]
			if numeric {
				assert actual.kind == .integer
				assert actual.integer == expected
			} else if boolean {
				assert actual.kind == .boolean
				assert actual.boolean == (expected == 1)
			} else {
				assert actual.kind == .none
			}
			if expected_error != no_error {
				assert owner.get_error() == expected_error
			}
			if !numeric && !boolean {
				assert owner.get_error() == invalid_enum
			}
			assert owner.get_error() == no_error
		}
		owner.native.make_current()
		C.vox_gl_delete_program(program.object.native_name())
		assert owner.owns(&program.object)
		mut rejected := i32(0)
		C.glGetProgramivRobustANGLE(program.object.native_name(), link_status, 1, unsafe { nil }, &rejected)
		expected_error := C.vox_gl_get_error()
		assert expected_error != no_error
		other.native.make_current()
		assert owner.get_program_parameter(program, link_status).boolean == (rejected == 1)
		assert owner.get_error() == expected_error
		assert owner.get_error() == no_error
	}
}
