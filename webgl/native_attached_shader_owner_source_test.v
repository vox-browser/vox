// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_attached_shader_source_records_leave_actual_driver_owner_unchanged_on_all_paths() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut program := context.create_program()
		foreign := other.create_program()
		other.native.make_current()
		assert (context.get_attached_shaders(program) or { panic('empty source records') }).len == 0
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		vertex := context.create_shader(vertex_shader) or { panic('vertex source record') }
		fragment := context.create_shader(fragment_shader) or { panic('fragment source record') }
		context.attach_shader(mut program, fragment)
		context.attach_shader(mut program, vertex)
		context.delete_shader(vertex)
		context.delete_shader(fragment)
		context.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		other.native.make_current()
		assert context.get_attached_shaders(program) or { panic('retained source records') } == [
			vertex,
			fragment,
		]
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == no_error
		assert context.get_error() == invalid_value
		assert context.get_error() == no_error
		other.native.make_current()
		assert context.get_attached_shaders(foreign) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_operation
		context.delete_program(program)
		other.native.make_current()
		assert context.get_attached_shaders(program) == none
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert context.get_error() == invalid_operation
		assert context.get_error() == no_error
		assert other.get_error() == no_error
	}
}
