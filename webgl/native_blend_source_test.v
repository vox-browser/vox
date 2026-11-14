// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

import math

struct BlendSourceCase {
	method string
	args   []GLenum
}

fn blend_source_reset() {
	C.vox_gl_blend_equation(func_add)
	C.vox_gl_blend_func(gl_one, gl_zero)
}

fn blend_source_direct(operation BlendSourceCase) {
	a := operation.args
	match operation.method {
		'equation' { C.vox_gl_blend_equation(a[0]) }
		'equation_separate' { C.vox_gl_blend_equation_separate(a[0], a[1]) }
		'func' { C.vox_gl_blend_func(a[0], a[1]) }
		else { C.vox_gl_blend_func_separate(a[0], a[1], a[2], a[3]) }
	}
}

fn blend_source_state() []i64 {
	mut result := []i64{}
	for pname in [blend_equation_rgb, blend_equation_alpha, blend_src_rgb, blend_dst_rgb,
		blend_src_alpha, blend_dst_alpha] {
		mut value := i32(0)
		C.vox_gl_int_parameter(pname, &value)
		result << i64(value)
	}
	return result
}

fn test_source_blend_enums_use_driver_validation_state_and_error_priority() {
	operations := [
		BlendSourceCase{'equation', [func_subtract]},
		BlendSourceCase{'equation', [gl_min]},
		BlendSourceCase{'equation', [gl_max]},
		BlendSourceCase{'equation', [GLenum(0xbad)]},
		BlendSourceCase{'equation_separate', [func_subtract, func_reverse_subtract]},
		BlendSourceCase{'equation_separate', [gl_min, gl_max]},
		BlendSourceCase{'equation_separate', [GLenum(0xbad), func_add]},
		BlendSourceCase{'equation_separate', [func_add, GLenum(0xbad)]},
		BlendSourceCase{'func', [src_alpha, one_minus_src_alpha]},
		BlendSourceCase{'func', [constant_color, constant_alpha]},
		BlendSourceCase{'func', [src_alpha_saturate, src_alpha_saturate]},
		BlendSourceCase{'func', [GLenum(0xbad), gl_one]},
		BlendSourceCase{'func_separate', [src_alpha, one_minus_src_alpha, gl_one, gl_zero]},
		BlendSourceCase{'func_separate', [constant_color, constant_alpha, gl_one, gl_zero]},
		BlendSourceCase{'func_separate', [gl_one, gl_zero, constant_color, constant_alpha]},
		BlendSourceCase{'func_separate', [gl_one, gl_zero, GLenum(0xbad), gl_one]},
	]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for extension_requested in [false, true] {
			if extension_requested && version == .webgl1 {
				context.get_extension('EXT_blend_minmax', false) or { panic('native blend extension') }
			}
			for operation in operations {
				context.native.make_current()
				blend_source_reset()
				assert C.vox_gl_get_error() == no_error
				blend_source_direct(operation)
				expected_error := C.vox_gl_get_error()
				expected_state := blend_source_state()
				blend_source_reset()
				assert C.vox_gl_get_error() == no_error
				context.set_error(invalid_value)
				other.native.make_current()
				a := operation.args
				match operation.method {
					'equation' { context.blend_equation(a[0]) }
					'equation_separate' { context.blend_equation_separate(a[0], a[1]) }
					'func' { context.blend_func(a[0], a[1]) }
					else { context.blend_func_separate(a[0], a[1], a[2], a[3]) }
				}
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert blend_source_state() == expected_state
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_value
				assert context.get_error() == no_error
			}
		}
		assert other.get_error() == no_error
	}
}

fn test_source_blend_color_passes_unrestricted_float_values_to_actual_driver() {
	colors := [[f32(-1), 0.5, 2, 1]!,
		[f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(-0.0)]!]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		for color in colors {
			context.native.make_current()
			C.vox_gl_blend_color(color[0], color[1], color[2], color[3])
			expected_error := C.vox_gl_get_error()
			mut expected := [f32(0), 0, 0, 0]!
			C.vox_gl_float_parameter(blend_color, &expected[0])
			C.vox_gl_blend_color(0.1, 0.2, 0.3, 0.4)
			other.native.make_current()
			context.blend_color(color[0], color[1], color[2], color[3])
			assert context.get_error() == expected_error
			actual := context.get_parameter(blend_color).numbers
			for index, value in expected {
				assert actual[index] == f64(value) || (math.is_nan(actual[index]) && math.is_nan(value))
			}
		}
	}
}

fn test_source_blend_commands_preserve_actual_draw_pixels_despite_prior_driver_error() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(1, 1)
		mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
		mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
		context.shader_source(mut vertex, 'void main(){gl_Position=vec4(0,0,0,1);gl_PointSize=1.0;}')
		context.shader_source(mut fragment, 'precision mediump float;void main(){gl_FragColor=vec4(0.25,0,0,1);}')
		context.compile_shader(mut vertex)
		context.compile_shader(mut fragment)
		mut program := context.create_program()
		context.attach_shader(mut program, vertex)
		context.attach_shader(mut program, fragment)
		context.link_program(mut program)
		assert context.get_program_parameter(program, link_status).boolean
		context.use_program(program)
		context.enable(blend)
		context.clear_color(0, 0, 0.25, 1)
		context.clear(0x4000)
		C.vox_gl_blend_color(0.5, 0.5, 0.5, 1)
		C.vox_gl_blend_equation(func_add)
		C.vox_gl_blend_func(gl_one, gl_one)
		C.vox_gl_draw_arrays(0, 0, 1)
		expected := context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte)
		assert expected == [u8(64), 0, 64, 255]
		context.clear(0x4000)
		C.vox_gl_enable(0xbad)
		context.blend_color(0.5, 0.5, 0.5, 1)
		context.blend_equation(func_subtract)
		context.blend_equation_separate(func_add, func_add)
		context.blend_func(gl_zero, gl_zero)
		context.blend_func_separate(gl_one, gl_one, gl_one, gl_one)
		context.draw_arrays(0, 0, 1)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == expected
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
	}
}
