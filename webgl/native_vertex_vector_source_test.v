// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import math

fn call_vertex_vector_source(mut context WebGLRenderingContext, components int, index GLuint, values []f32) {
	match components {
		1 { context.vertex_attrib1fv(index, values) }
		2 { context.vertex_attrib2fv(index, values) }
		3 { context.vertex_attrib3fv(index, values) }
		else { context.vertex_attrib4fv(index, values) }
	}
}

fn test_vertex_vectors_preserve_source_minimum_span_gate_and_exact_driver_calls() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		mut limit := i32(0)
		C.vox_gl_int_parameter(GLenum(0x8869), &limit)
		values := [f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(math.copysign(0, -1)),
			f32(13), f32(14)]
		for components in 1 .. 5 {
			for length in 0 .. components {
				other.native.make_current()
				call_vertex_vector_source(mut context, components, GLuint(limit), values[..length])
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [i32(9), 10, 11, 12]!
				assert context.error_ == invalid_value
				assert context.get_error() == invalid_value
				assert other.get_error() == no_error
			}
			for index in [GLuint(2), GLuint(limit)] {
				context.native.make_current()
				if index < GLuint(limit) { C.vox_gl_vertex_attrib4f(index, 9, 10, 11, 12) }
				match components {
					1 { C.vox_gl_vertex_attrib1fv(index, values.data) }
					2 { C.vox_gl_vertex_attrib2fv(index, values.data) }
					3 { C.vox_gl_vertex_attrib3fv(index, values.data) }
					else { C.vox_gl_vertex_attrib_floats(index, values.data) }
				}
				expected_error := C.vox_gl_get_error()
				mut expected := [f32(0), 0, 0, 0]!
				if index < GLuint(limit) {
					C.vox_gl_vertex_attrib_float_parameter(index, &expected[0])
					C.vox_gl_vertex_attrib4f(index, 9, 10, 11, 12)
				}
				context.set_error(invalid_operation)
				other.native.make_current()
				call_vertex_vector_source(mut context, components, index, values[..components + 2])
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
