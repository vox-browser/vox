// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_uniform_location_queries_create_fresh_records_and_requery_native_links() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, 'uniform vec4 position; void main(){gl_Position=position;}')
	context.shader_source(mut fragment, 'precision mediump float; void main(){gl_FragColor=vec4(1);}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	context.use_program(program)
	first := context.get_uniform_location(mut program, 'position') or { panic('first') }
	second := context.get_uniform_location(mut program, 'position') or { panic('second') }
	assert voidptr(first) != voidptr(second)
	assert first.handle_ == second.handle_
	assert first.parent_program or { panic('parent') } == program
	assert second.parent_program or { panic('parent') } == program
	context.uniform4f(first, 1, 2, 3, 4)
	context.uniform4f(second, 4, 3, 2, 1)
	assert context.get_error() == no_error
	assert context.get_uniform_location(mut program, 'missing') == none
	assert context.get_error() == no_error
	// Native link changes cannot be hidden by a retained per-name location map.
	context.native.make_current()
	C.vox_gl_detach_shader(program.object.native_handle_, vertex.object.native_handle_)
	C.vox_gl_detach_shader(program.object.native_handle_, fragment.object.native_handle_)
	C.vox_gl_link_program(program.object.native_handle_)
	assert program.linked_
	assert !context.get_program_parameter(program, link_status).boolean
	assert context.get_uniform_location(mut program, 'position') == none
	assert context.get_error() == invalid_operation
}
