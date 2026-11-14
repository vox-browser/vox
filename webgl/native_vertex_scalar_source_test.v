// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import math

fn test_scalar_vertex_attributes_use_source_gl_entry_points_and_actual_driver_defaults() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		mut limit := i32(0)
		C.vox_gl_int_parameter(GLenum(0x8869), &limit)
		assert limit > 0
		for values in [
			[f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(math.copysign(0, -1))],
			[f32(math.copysign(0, -1)), f32(0.25), f32(0.5), f32(0.75)],
		] {
			for components in 1 .. 5 {
				for index in [GLuint(0), GLuint(limit - 1), GLuint(limit)] {
					context.native.make_current()
					if index < GLuint(limit) { C.vox_gl_vertex_attrib4f(index, 9, 10, 11, 12) }
					match components {
						1 { C.vox_gl_vertex_attrib1f(index, values[0]) }
						2 { C.vox_gl_vertex_attrib2f(index, values[0], values[1]) }
						3 { C.vox_gl_vertex_attrib3f(index, values[0], values[1], values[2]) }
						else {
							C.vox_gl_vertex_attrib4f(index, values[0], values[1], values[2], values[3])
						}
					}
					expected_error := C.vox_gl_get_error()
					mut expected := [f32(0), 0, 0, 0]!
					if index < GLuint(limit) {
						C.vox_gl_vertex_attrib_float_parameter(index, &expected[0])
						C.vox_gl_vertex_attrib4f(index, 9, 10, 11, 12)
					}
					assert C.vox_gl_get_error() == no_error
					context.set_error(invalid_operation)
					other.native.make_current()
					match components {
						1 { context.vertex_attrib1f(index, values[0]) }
						2 { context.vertex_attrib2f(index, values[0], values[1]) }
						3 { context.vertex_attrib3f(index, values[0], values[1], values[2]) }
						else {
							context.vertex_attrib4f(index, values[0], values[1], values[2], values[3])
						}
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
						actual := context.get_vertex_attrib(index, current_vertex_attrib).numbers
						assert actual.len == 4
						for slot, value in expected {
							assert actual[slot] == f64(value) || (math.is_nan(actual[slot]) && math.is_nan(value))
							if value == 0 {
								assert math.signbit(actual[slot]) == math.signbit(f64(value))
							}
						}
					}
					assert other.get_error() == no_error
				}
			}
		}
	}
}
