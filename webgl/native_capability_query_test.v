// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_is_enabled_reads_actual_driver_state_and_rejects_non_capability_enums() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		assert context.is_enabled(dither)
		assert !context.is_enabled(blend)
		context.native.dispatch('enable', blend)
		assert C.vox_gl_is_enabled(blend) == 1
		other.native.make_current()
		assert context.is_enabled(blend)
		assert !other.is_enabled(blend)
		context.enable(blend)
		context.native.dispatch('disable', blend)
		assert C.vox_gl_is_enabled(blend) == 0
		assert !context.is_enabled(blend)
		assert context.get_error() == no_error
		assert other.get_error() == no_error
		// COLOR_CLEAR_VALUE is a valid getParameter pname but not a capability.
		assert !context.is_enabled(color_clear_value)
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
		context.enable(GLenum(0xbad))
		assert context.get_error() == invalid_enum
		assert !context.is_enabled(GLenum(0xbad))
		assert context.get_error() == invalid_enum
		assert context.get_error() == no_error
	}
}

fn test_vertex_attribute_enable_disable_remains_actual_driver_state() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		context.native.make_current()
		mut limit := i32(0)
		C.vox_gl_int_parameter(GLenum(0x8869), &limit) // GL_MAX_VERTEX_ATTRIBS
		assert limit > 0
		for index in [GLuint(0), GLuint(limit - 1), GLuint(limit), GLuint(0xffff_ffff)] {
			for enabled in [true, false] {
				context.native.make_current()
				if index < GLuint(limit) { C.vox_gl_vertex_attrib_enable(index, int(!enabled)) }
				C.vox_gl_vertex_attrib_enable(index, int(enabled))
				expected_error := C.vox_gl_get_error()
				if index < GLuint(limit) { C.vox_gl_vertex_attrib_enable(index, int(!enabled)) }
				assert C.vox_gl_get_error() == no_error
				context.set_error(invalid_operation)
				other.native.make_current()
				if enabled {
					context.enable_vertex_attrib_array(index)
				} else {
					context.disable_vertex_attrib_array(index)
				}
				mut actual_owner := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(viewport, &actual_owner[0])
				assert actual_owner == [i32(1), 2, 3, 4]!
				if expected_error != no_error {
					assert context.get_error() == expected_error
				}
				assert context.get_error() == invalid_operation
				assert context.get_error() == no_error
				if index < GLuint(limit) {
					assert C.vox_gl_vertex_attrib_parameter(index, vertex_attrib_array_enabled) == int(enabled)
					assert context.get_vertex_attrib(index, vertex_attrib_array_enabled).boolean == enabled
				}
				assert other.get_error() == no_error
			}
		}
	}
}
