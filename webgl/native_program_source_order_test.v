// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_owned_program_use_and_uniform_location_rely_on_native_link_status() {
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
	assert !context.get_program_parameter(program, link_status).boolean
	context.native.make_current()
	C.vox_gl_link_program(program.object.native_handle_)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	assert context.get_error() == no_error
	assert context.current_program or { panic('current') } == program
	assert context.get_uniform_location(mut program, 'position') != none
	assert context.get_error() == no_error
	unlinked := context.create_program()
	context.use_program(unlinked)
	assert context.get_error() == invalid_operation
	assert context.get_parameter(current_program).object == unlinked.object.handle_
	// The source writes its retained slot after glUseProgram even after rejection.
	mut actual := i32(0)
	C.vox_gl_int_parameter(current_program, &actual)
	assert u32(actual) == program.object.native_handle_
	mut foreign := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	foreign.use_program(program)
	assert foreign.current_program == none
	assert foreign.get_error() == invalid_operation
}

fn test_source_detach_clears_typed_retained_slot_after_native_rejection() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	other := context.create_shader(vertex_shader) or { panic('other') }
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.detach_shader(mut program, other)
	assert context.get_error() == invalid_operation
	assert (context.get_attached_shaders(program) or { panic('source slots') }).len == 0
	assert context.get_program_parameter(program, attached_shaders).integer == 1
	// The actual attached shader can still be detached despite the cleared slot.
	context.detach_shader(mut program, vertex)
	assert context.get_error() == no_error
	assert context.get_program_parameter(program, attached_shaders).integer == 0
}
