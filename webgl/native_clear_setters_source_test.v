// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import math

fn test_source_clear_float_setters_delegate_unrestricted_float_values_and_queries() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		for color in [[f32(-1), 0.5, 2, 1]!,
			[f32(math.inf(-1)), f32(math.inf(1)), f32(math.nan()), f32(-0.0)]!] {
			context.native.make_current()
			C.vox_gl_clear_color(color[0], color[1], color[2], color[3])
			expected_error := C.vox_gl_get_error()
			mut expected := [f32(0), 0, 0, 0]!
			C.vox_gl_float_parameter(color_clear_value, &expected[0])
			C.vox_gl_clear_color(0.1, 0.2, 0.3, 0.4)
			other.native.make_current()
			context.clear_color(color[0], color[1], color[2], color[3])
			assert context.get_error() == expected_error
			actual := context.get_parameter(color_clear_value).numbers
			for index, value in expected {
				assert actual[index] == f64(value) || (math.is_nan(actual[index]) && math.is_nan(value))
			}
		}
		for depth in [f32(-1), f32(2), f32(0.1), f32(math.inf(-1)), f32(math.inf(1)), f32(math.nan())] {
			context.native.make_current()
			C.vox_gl_clear_depth(depth)
			expected_error := C.vox_gl_get_error()
			mut expected := f32(0)
			C.vox_gl_float_parameter(depth_clear_value, &expected)
			C.vox_gl_clear_depth(0.5)
			other.native.make_current()
			context.clear_depth(depth)
			assert context.get_error() == expected_error
			actual := context.get_parameter(depth_clear_value).number
			assert actual == f64(expected) || (math.is_nan(actual) && math.is_nan(expected))
		}
		// Queries also reflect writes made directly to the actual driver.
		C.vox_gl_clear_stencil(-1)
		C.vox_gl_color_mask(1, 0, 1, 0)
		C.vox_gl_depth_mask(0)
		assert context.get_parameter(stencil_clear_value).integer == -1
		assert context.get_parameter(color_writemask).booleans == [true, false, true, false]
		assert !context.get_parameter(depth_writemask).boolean
	}
}

fn test_source_clear_setters_and_masks_control_actual_depth_stencil_and_color_pixels() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{ stencil: true }, [])
		context.set_size(1, 1)
		mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
		mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
		context.shader_source(mut vertex, 'void main(){gl_Position=vec4(0,0,0,1);gl_PointSize=1.0;}')
		context.shader_source(mut fragment, 'precision mediump float;void main(){gl_FragColor=vec4(1,0,0,1);}')
		context.compile_shader(mut vertex)
		context.compile_shader(mut fragment)
		mut program := context.create_program()
		context.attach_shader(mut program, vertex)
		context.attach_shader(mut program, fragment)
		context.link_program(mut program)
		assert context.get_program_parameter(program, link_status).boolean
		context.use_program(program)
		C.vox_gl_enable(0xbad)
		context.clear_color(0, 0, 1, 1)
		context.clear_depth(0.25)
		context.clear_stencil(0x1ab)
		context.clear(0x4500)
		context.depth_mask(false)
		context.clear_depth(1)
		context.stencil_mask(0)
		context.clear_stencil(0)
		context.clear(0x0500)
		context.enable(depth_test)
		context.depth_func(greater)
		context.enable(stencil_test)
		context.stencil_func(equal, 0xab, 0xff)
		context.color_mask(true, true, false, true)
		context.draw_arrays(0, 0, 1)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 255, 255]
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
	}
}
