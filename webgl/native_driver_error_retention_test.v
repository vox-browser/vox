// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn driver_error_retention_generate_direct(version WebGLVersion, program &WebGLProgram) {
	if version == .webgl1 {
		C.vox_gl_active_texture(0xbad)
		C.vox_gl_bind_attrib_location(program.object.native_handle_, u32(-1), c'position')
	} else {
		C.vox_gl_bind_sampler(u32(-1), 0)
		C.vox_gl_bind_transform_feedback(0xbad, 0)
	}
}

fn driver_error_retention_direct_errors(version WebGLVersion, program &WebGLProgram) []GLenum {
	driver_error_retention_generate_direct(version, program)
	mut errors := []GLenum{}
	for _ in 0 .. 3 { errors << GLenum(C.vox_gl_get_error()) }
	assert errors.filter(it != no_error).len == 2
	assert invalid_enum in errors && invalid_value in errors
	assert errors[2] == no_error
	return errors
}

fn driver_error_retention_translated_errors(mut context WebGLRenderingContext, program &WebGLProgram) {
	if context.version == .webgl1 {
		context.active_texture(0xbad)
		context.bind_attrib_location(program, u32(-1), 'position')
	} else {
		context.bind_sampler(u32(-1), none)
		context.bind_transform_feedback(0xbad, none)
	}
}

fn test_source_commands_and_queries_leave_actual_driver_errors_in_driver_order() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		program := context.create_program()
		expected := driver_error_retention_direct_errors(version, program)
		other.native.make_current()
		driver_error_retention_translated_errors(mut context, program)
		// A source GL query must not consume an unrelated driver's error flag.
		assert context.get_parameter(active_texture).integer == texture0
		buffer := context.create_buffer()
		assert buffer.object.native_handle_ != 0
		shader := context.create_shader(vertex_shader) or { panic('real vertex shader') }
		assert context.get_shader_source(shader)? == ''
		assert context.get_program_info_log(program)? == ''
		mut observed := []GLenum{}
		for _ in 0 .. 3 { observed << context.get_error() }
		assert observed == expected
		assert other.get_error() == no_error
		// Local transport errors remain distinct and precede native GL flags.
		// Source m_error still holds only its first error (the upstream TODO).
		other.native.make_current()
		driver_error_retention_translated_errors(mut context, program)
		context.native.set_pending_local_error(out_of_memory)
		context.set_error(invalid_operation)
		context.set_error(invalid_value)
		assert context.get_error() == out_of_memory
		assert context.get_error() == expected[0]
		assert context.get_error() == expected[1]
		assert context.get_error() == invalid_operation
		assert context.get_error() == no_error
		assert other.get_error() == no_error
	}
}

fn test_source_cpu_readback_does_not_fail_or_consume_unrelated_driver_errors() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.set_size(2, 2)
		context.clear_color(1, 0.25, 0.5, 1)
		context.clear(GLenum(0x4000))
		program := context.create_program()
		expected := driver_error_retention_direct_errors(version, program)
		driver_error_retention_generate_direct(version, program)
		frame := context.native.read_back_drawing_buffer() or { panic('actual CPU readback') }
		assert frame.pixels == [u8(255), 64, 128, 255].repeat(4)
		mut observed := []GLenum{}
		for _ in 0 .. 3 { observed << context.get_error() }
		assert observed == expected
		// Presentation retains its actual status/surface guards and pixels.
		driver_error_retention_generate_direct(version, program)
		assert context.native.present_with_preserved_buffer(true)
		surface := context.native.painting_surface() or { panic('actual painting surface') }
		assert surface.pixels == frame.pixels
		observed.clear()
		for _ in 0 .. 3 { observed << context.get_error() }
		assert observed == expected
	}
}

fn test_source_extension_request_does_not_consume_prior_actual_driver_flags() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		program := context.create_program()
		extensions := context.native.get_supported_opengl_extensions()
		assert extensions.len > 0
		extension := extensions[0]
		driver_error_retention_generate_direct(version, program)
		C.vox_gl_request_extension(extension.str)
		mut expected := []GLenum{}
		for _ in 0 .. 4 { expected << GLenum(C.vox_gl_get_error()) }
		assert invalid_enum in expected && invalid_value in expected
		driver_error_retention_generate_direct(version, program)
		context.native.request_extension(extension)
		mut observed := []GLenum{}
		for _ in 0 .. 4 { observed << context.get_error() }
		assert observed == expected
	}
}
