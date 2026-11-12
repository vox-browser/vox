// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_texture_parameters_use_actual_driver_binding_and_validation() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		texture := context.create_texture()
		C.vox_gl_bind_texture(texture_2d, texture.object.native_handle_)
		assert texture_2d !in context.bound_texture_objects
		other.native.make_current()
		context.tex_parameteri(texture_2d, texture_min_filter, 0x2600)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_tex_parameter(texture_2d, texture_min_filter).integer == 0x2600
		assert context.get_error() == no_error
		other.native.make_current()
		context.tex_parameterf(texture_2d, texture_wrap_s, f32(0x812f))
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_tex_parameter(texture_2d, texture_wrap_s).integer == 0x812f
		assert context.get_error() == no_error
		C.vox_gl_tex_parameteri(0xbad, 0xbad, -1)
		expected_int := C.vox_gl_get_error()
		other.native.make_current()
		context.tex_parameteri(0xbad, 0xbad, -1)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_int
		C.vox_gl_tex_parameterf(0xbad, 0xbad, -1)
		expected_float := C.vox_gl_get_error()
		other.native.make_current()
		context.tex_parameterf(0xbad, 0xbad, -1)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == expected_float
		context.tex_parameteri(texture_2d, texture_min_filter, 0x2601)
		assert context.get_tex_parameter(texture_2d, texture_min_filter).integer == 0x2601
		assert context.get_error() == no_error
	}
}
