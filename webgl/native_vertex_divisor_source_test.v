// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_vertex_divisor_forwards_source_unsigned_widths_and_driver_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	context.native.make_current()
	mut limit := i32(0)
	C.vox_gl_int_parameter(GLenum(0x8869), &limit)
	for index in [GLuint(0), GLuint(limit - 1), GLuint(limit), GLuint(0xffff_ffff)] {
		for divisor in [GLuint(0), GLuint(1), GLuint(17), GLuint(0x8000_0000), GLuint(0xffff_ffff)] {
			context.native.make_current()
			if index < GLuint(limit) {
				C.vox_gl_vertex_attrib_divisor(index, 7, 3)
			}
			C.vox_gl_vertex_attrib_divisor(index, divisor, 3)
			expected_error := C.vox_gl_get_error()
			mut expected := 0
			if index < GLuint(limit) {
				expected = C.vox_gl_vertex_attrib_parameter(index, vertex_attrib_array_divisor)
				C.vox_gl_vertex_attrib_divisor(index, 7, 3)
			}
			context.set_error(invalid_operation)
			other.native.make_current()
			context.vertex_attrib_divisor(index, divisor)
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			if index < GLuint(limit) {
				assert C.vox_gl_vertex_attrib_parameter(index, vertex_attrib_array_divisor) == expected
			}
			if expected_error != no_error {
				assert context.get_error() == expected_error
			}
			assert context.get_error() == invalid_operation
			assert context.get_error() == no_error
			assert other.get_error() == no_error
		}
	}
}
