// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

struct StencilSourceCase {
	method string
	args   []i64
}

fn stencil_source_reset() {
	C.vox_gl_stencil_func(always, 0, u32(-1))
	C.vox_gl_stencil_mask(u32(-1))
	C.vox_gl_stencil_op(keep, keep, keep)
	assert C.vox_gl_get_error() == no_error
}

fn stencil_source_state() []int {
	mut result := []int{}
	for pname in [stencil_func, stencil_ref, stencil_value_mask, stencil_writemask, stencil_fail,
		stencil_pass_depth_fail, stencil_pass_depth_pass, stencil_back_func, stencil_back_ref,
		stencil_back_value_mask, stencil_back_writemask, stencil_back_fail,
		stencil_back_pass_depth_fail, stencil_back_pass_depth_pass] {
		mut value := i32(0)
		C.vox_gl_int_parameter(pname, &value)
		result << value
	}
	return result
}

fn stencil_source_direct(operation StencilSourceCase) {
	a := operation.args
	match operation.method {
		'func' { C.vox_gl_stencil_func(u32(a[0]), int(a[1]), u32(a[2])) }
		'func_separate' {
			C.vox_gl_stencil_func_separate(u32(a[0]), u32(a[1]), int(a[2]), u32(a[3]))
		}
		'mask' { C.vox_gl_stencil_mask(u32(a[0])) }
		'mask_separate' { C.vox_gl_stencil_mask_separate(u32(a[0]), u32(a[1])) }
		'op' { C.vox_gl_stencil_op(u32(a[0]), u32(a[1]), u32(a[2])) }
		else { C.vox_gl_stencil_op_separate(u32(a[0]), u32(a[1]), u32(a[2]), u32(a[3])) }
	}
}

fn test_source_stencil_setters_use_actual_front_back_driver_state_validation_and_owner() {
	operations := [
		StencilSourceCase{'func', [i64(0xbad), 0, 0xffffffff]},
		StencilSourceCase{'func', [i64(never), -1, 0xf0]},
		StencilSourceCase{'func', [i64(lequal), 2147483647, 0xffffffff]},
		StencilSourceCase{'func_separate', [i64(front), equal, 7, 0x0f]},
		StencilSourceCase{'func_separate', [i64(back), notequal, -1, 0xffffffff]},
		StencilSourceCase{'func_separate', [i64(0xbad), always, 1, 0xff]},
		StencilSourceCase{'func_separate', [i64(front_and_back), 0xbad, 1, 0xff]},
		StencilSourceCase{'mask', [i64(0xf0)]},
		StencilSourceCase{'mask', [i64(0xffffffff)]},
		StencilSourceCase{'mask_separate', [i64(front), 0x0f]},
		StencilSourceCase{'mask_separate', [i64(back), 0xf0]},
		StencilSourceCase{'mask_separate', [i64(front_and_back), 0xffffffff]},
		StencilSourceCase{'mask_separate', [i64(0xbad), 0xff]},
		StencilSourceCase{'op', [i64(replace), incr, decr_wrap]},
		StencilSourceCase{'op', [i64(0xbad), keep, keep]},
		StencilSourceCase{'op', [i64(keep), 0xbad, keep]},
		StencilSourceCase{'op_separate', [i64(front), invert, incr_wrap, decr]},
		StencilSourceCase{'op_separate', [i64(back), gl_zero, replace, keep]},
		StencilSourceCase{'op_separate', [i64(0xbad), keep, keep, keep]},
		StencilSourceCase{'op_separate', [i64(front_and_back), keep, keep, 0xbad]},
	]
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{ stencil: true }, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for operation in operations {
			context.native.make_current()
			stencil_source_reset()
			stencil_source_direct(operation)
			expected_error := C.vox_gl_get_error()
			expected := stencil_source_state()
			stencil_source_reset()
			context.set_error(invalid_value)
			other.native.make_current()
			a := operation.args
			match operation.method {
				'func' { context.stencil_func(u32(a[0]), int(a[1]), u32(a[2])) }
				'func_separate' {
					context.stencil_func_separate(u32(a[0]), u32(a[1]), int(a[2]), u32(a[3]))
				}
				'mask' { context.stencil_mask(u32(a[0])) }
				'mask_separate' { context.stencil_mask_separate(u32(a[0]), u32(a[1])) }
				'op' { context.stencil_op(u32(a[0]), u32(a[1]), u32(a[2])) }
				else { context.stencil_op_separate(u32(a[0]), u32(a[1]), u32(a[2]), u32(a[3])) }
			}
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert stencil_source_state() == expected
			if expected_error != no_error {
				assert context.get_error() == expected_error
			}
			assert context.get_error() == invalid_value
			assert context.get_error() == no_error
		}
		assert other.get_error() == no_error
	}
}

fn test_source_stencil_function_masks_and_operations_change_actual_point_pixels() {
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
		context.clear_color(0, 0, 1, 1)
		context.clear_stencil(0)
		context.clear(0x4400)
		context.enable(stencil_test)
		context.stencil_func(never, 1, 0xff)
		context.stencil_mask(0)
		context.stencil_op(replace, keep, keep)
		context.draw_arrays(0, 0, 1)
		context.stencil_func_separate(front_and_back, equal, 1, 0xff)
		context.stencil_op_separate(front_and_back, keep, keep, keep)
		context.draw_arrays(0, 0, 1)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(0), 0, 255, 255]
		context.stencil_mask_separate(front_and_back, 0xff)
		context.stencil_func_separate(front_and_back, never, 1, 0xff)
		context.stencil_op_separate(front_and_back, replace, keep, keep)
		context.draw_arrays(0, 0, 1)
		context.stencil_func(equal, 1, 0xff)
		context.stencil_op(keep, keep, keep)
		context.draw_arrays(0, 0, 1)
		assert context.read_pixels(0, 0, 1, 1, rgba, unsigned_byte) == [u8(255), 0, 0, 255]
		assert context.get_error() == no_error
	}
}
