// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn shader_program_owner_and_error(mut context WebGLRenderingContext, expected GLenum) {
	shader_program_owner_and_error_selected(mut context, expected, [i32(1), 2, 3, 4]!)
}

fn shader_program_owner_and_error_selected(mut context WebGLRenderingContext, expected GLenum, expected_owner [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == expected_owner
	actual := context.get_error()
	assert actual == expected
}

fn test_source_shader_program_mutations_select_owner_before_early_returns() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut foreign_shader := other.create_shader(vertex_shader) or { panic('foreign shader') }
		mut foreign_program := other.create_program()
		mut shader := context.create_shader(vertex_shader) or { panic('shader') }
		mut program := context.create_program()
		other.native.make_current()
		invalid_shader := context.create_shader(0xbad)
		assert invalid_shader == none
		mut invalid_type_owner := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &invalid_type_owner[0])
		assert invalid_type_owner == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_enum
		other.native.make_current()
		context.shader_source(mut foreign_shader, 'void main(){}')
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.compile_shader(mut foreign_shader)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.link_program(mut foreign_program)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.validate_program(mut foreign_program)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.attach_shader(mut program, foreign_shader)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		context.attach_shader(mut program, shader)
		other.native.make_current()
		context.attach_shader(mut program, shader)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.bind_attrib_location(foreign_program, 0xffffffff, 'gl_reserved')
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		name := 'gl_reserved'
		context.native.make_current()
		C.vox_gl_bind_attrib_location(program.object.native_handle_, 0xffffffff, name.str)
		expected_binding_error := C.vox_gl_get_error()
		other.native.make_current()
		context.bind_attrib_location(program, 0xffffffff, name)
		shader_program_owner_and_error(mut context, expected_binding_error)
		other.native.make_current()
		context.delete_shader(foreign_shader)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.delete_program(foreign_program)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.delete_shader(none)
		shader_program_owner_and_error_selected(mut context, no_error, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.delete_program(none)
		shader_program_owner_and_error_selected(mut context, no_error, [i32(9), 10, 11, 12]!)
		context.delete_shader(shader)
		other.native.make_current()
		context.delete_shader(shader)
		shader_program_owner_and_error_selected(mut context, no_error, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.compile_shader(mut shader)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
		context.delete_program(program)
		other.native.make_current()
		context.delete_program(program)
		shader_program_owner_and_error_selected(mut context, no_error, [i32(9), 10, 11, 12]!)
		other.native.make_current()
		context.link_program(mut program)
		shader_program_owner_and_error_selected(mut context, invalid_operation, [i32(9), 10, 11, 12]!)
	}
}

fn test_source_attach_retains_shader_after_owned_native_program_rejection() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut program := context.create_program()
	shader := context.create_shader(vertex_shader) or { panic('shader') }
	C.vox_gl_delete_program(program.object.native_handle_)
	C.vox_gl_attach_shader(program.object.native_handle_, shader.object.native_handle_)
	expected := C.vox_gl_get_error()
	context.attach_shader(mut program, shader)
	actual := context.get_error()
	assert actual == expected
	assert program.attached_vertex_shader or { panic('source retained shader') } == shader
}
