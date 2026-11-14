// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_integer_scalar_vertex_attributes_preserve_source_native_signed_unsigned_widths() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	context.native.make_current()
	mut limit := i32(0)
	C.vox_gl_int_parameter(GLenum(0x8869), &limit)
	for index in [GLuint(2), GLuint(limit - 1), GLuint(limit)] {
		for unsigned in [false, true] {
			context.native.make_current()
			if unsigned {
				C.vox_gl_vertex_attrib_i4ui(index, 0xffff_ffff, 0xfedc_ba98, 0x8000_0000, 0)
			} else {
				C.vox_gl_vertex_attrib_i4i(index, -2_147_483_648, 2_147_483_647, -2_000_000_001, 2_000_000_001)
			}
			expected_error := C.vox_gl_get_error()
			mut expected_signed := [i32(0), 0, 0, 0]!
			mut expected_unsigned := [u32(0), 0, 0, 0]!
			if index < GLuint(limit) {
				if unsigned {
					C.vox_gl_vertex_attrib_uint_parameter(index, &expected_unsigned[0])
				} else {
					C.vox_gl_vertex_attrib_int_parameter(index, &expected_signed[0])
				}
				C.vox_gl_vertex_attrib_i4i(index, 7, 8, 9, 10)
			}
			context.set_error(invalid_operation)
			other.native.make_current()
			if unsigned {
				context.vertex_attrib_i4ui(index, 0xffff_ffff, 0xfedc_ba98, 0x8000_0000, 0)
			} else {
				context.vertex_attrib_i4i(index, -2_147_483_648, 2_147_483_647, -2_000_000_001, 2_000_000_001)
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			if expected_error != no_error {
				assert context.get_error() == expected_error
			}
			assert context.get_error() == invalid_operation
			assert context.get_error() == no_error
			if index < GLuint(limit) {
				if unsigned {
					mut actual := [u32(0), 0, 0, 0]!
					C.vox_gl_vertex_attrib_uint_parameter(index, &actual[0])
					assert actual == expected_unsigned
				} else {
					mut actual := [i32(0), 0, 0, 0]!
					C.vox_gl_vertex_attrib_int_parameter(index, &actual[0])
					assert actual == expected_signed
				}
			}
			assert other.get_error() == no_error
		}
	}
}
