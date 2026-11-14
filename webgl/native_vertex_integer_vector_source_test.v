// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_integer_vertex_vectors_preserve_source_minimum_spans_and_exact_native_pointers() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	context.native.make_current()
	mut limit := i32(0)
	C.vox_gl_int_parameter(GLenum(0x8869), &limit)
	signed := [-2_147_483_648, 2_147_483_647, -2_000_000_001, 2_000_000_001, 13, 14]
	unsigned := [u32(0xffff_ffff), 0xfedc_ba98, 0x8000_0000, 0, 13, 14]
	for unsigned_call in [false, true] {
		for length in 0 .. 4 {
			other.native.make_current()
			if unsigned_call {
				context.vertex_attrib_i4uiv(GLuint(limit), unsigned[..length])
			} else {
				context.vertex_attrib_i4iv(GLuint(limit), signed[..length])
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert context.error_ == invalid_value
			assert context.get_error() == invalid_value
			assert context.get_error() == no_error
			assert other.get_error() == no_error
		}
		for length in [4, 6] {
			for index in [GLuint(2), GLuint(limit - 1), GLuint(limit), GLuint(0xffff_ffff)] {
				context.native.make_current()
				if unsigned_call {
					C.vox_gl_vertex_attrib_uints(index, unsigned.data)
				} else {
					native_signed := signed.map(i32(it))
					C.vox_gl_vertex_attrib_ints(index, native_signed.data)
				}
				expected_error := C.vox_gl_get_error()
				mut expected_signed := [i32(0), 0, 0, 0]!
				mut expected_unsigned := [u32(0), 0, 0, 0]!
				if index < GLuint(limit) {
					if unsigned_call {
						C.vox_gl_vertex_attrib_uint_parameter(index, &expected_unsigned[0])
					} else {
						C.vox_gl_vertex_attrib_int_parameter(index, &expected_signed[0])
					}
					C.vox_gl_vertex_attrib_i4i(index, 7, 8, 9, 10)
				}
				context.set_error(invalid_operation)
				other.native.make_current()
				if unsigned_call {
					context.vertex_attrib_i4uiv(index, unsigned[..length])
				} else {
					context.vertex_attrib_i4iv(index, signed[..length])
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
					if unsigned_call {
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
}
