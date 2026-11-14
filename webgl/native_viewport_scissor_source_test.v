// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn viewport_scissor_source_state(pname GLenum) [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(pname, &value[0])
	return value
}

fn test_source_viewport_scissor_select_owner_and_delegate_dimensions_to_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for pname in [viewport, scissor_box] {
			for width in [0, -1, max_int] {
				context.native.make_current()
				// The oracle and translated command start from the same driver state.
				if pname == viewport {
					C.vox_gl_viewport(1, 2, 3, 4)
				} else {
					C.vox_gl_scissor(1, 2, 3, 4)
				}
				assert C.vox_gl_get_error() == no_error
				if pname == viewport {
					C.vox_gl_viewport(-5, 7, width, 2)
				} else {
					C.vox_gl_scissor(-5, 7, width, 2)
				}
				expected_error := C.vox_gl_get_error()
				expected_state := viewport_scissor_source_state(pname)
				// Reset to a distinct valid baseline before the translated command.
				if pname == viewport {
					C.vox_gl_viewport(1, 2, 3, 4)
				} else {
					C.vox_gl_scissor(1, 2, 3, 4)
				}
				assert C.vox_gl_get_error() == no_error
				other.native.make_current()
				if pname == viewport {
					context.viewport(-5, 7, width, 2)
				} else {
					context.scissor(-5, 7, width, 2)
				}
				assert context.get_error() == expected_error
				assert viewport_scissor_source_state(pname) == expected_state
				assert context.get_parameter(pname).integers == expected_state[..].map(i64(it))
				assert context.get_error() == no_error
			}
		}
		// The native rejection precedes the retained source validation error.
		for pname in [viewport, scissor_box] {
			context.set_error(invalid_operation)
			other.native.make_current()
			if pname == viewport {
				context.viewport(0, 0, -1, 1)
			} else {
				context.scissor(0, 0, -1, 1)
			}
			assert viewport_scissor_source_state(viewport) != [i32(9), 10, 11, 12]!
			assert context.get_error() == invalid_value
			assert context.get_error() == invalid_operation
			assert context.get_error() == no_error
		}
		other.native.make_current()
		assert viewport_scissor_source_state(viewport) == [i32(9), 10, 11, 12]!
		assert other.get_error() == no_error
	}
}

fn test_source_scissor_rejection_preserves_actual_clear_pixels() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(2, 2)
		context.clear_color(0, 0, 1, 1)
		context.clear(0x4000)
		context.enable(scissor_test)
		context.scissor(0, 0, 1, 1)
		context.scissor(0, 0, -1, 2)
		assert context.get_error() == invalid_value
		context.clear_color(1, 0, 0, 1)
		context.clear(0x4000)
		context.disable(scissor_test)
		assert context.read_pixels(0, 0, 2, 2, rgba, unsigned_byte) == [u8(255), 0, 0, 255, 0,
			0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255]
		assert context.get_error() == no_error
	}
}
