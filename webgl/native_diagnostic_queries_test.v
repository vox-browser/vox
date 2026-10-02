// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_shader_and_program_queries_validate_owner_and_nullable_result() {
	mut owner := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut vertex := owner.create_shader(vertex_shader) or { panic('vertex') }
	fragment := owner.create_shader(fragment_shader) or { panic('fragment') }
	mut program := owner.create_program()
	assert owner.get_shader_source(vertex) or { panic('source') } == ''
	assert (owner.get_attached_shaders(program) or { panic('attached') }).len == 0
	owner.attach_shader(mut program, vertex)
	owner.attach_shader(mut program, fragment)
	assert owner.get_attached_shaders(program) or { panic('attached') } == [vertex, fragment]
	assert other.get_attached_shaders(program) == none
	assert other.get_error() == invalid_operation
	assert other.get_program_info_log(program) == none
	assert other.get_error() == invalid_operation
	assert other.get_shader_source(vertex) == none
	assert other.get_error() == invalid_operation
	assert other.get_shader_info_log(vertex) == none
	assert other.get_error() == invalid_operation
	owner.shader_source(mut vertex, 'cached source')
	owner.native.make_current()
	actual := 'void main(){gl_Position=vec4(0.0);}'
	C.vox_gl_shader_source(vertex.object.native_handle_, actual.str, actual.len)
	assert vertex.source_ == 'cached source'
	assert owner.get_shader_source(vertex) or { panic('driver source') } == actual
	assert owner.get_shader_info_log(vertex) or { panic('log') } == ''
	assert owner.get_program_info_log(program) or { panic('log') } == ''
	assert owner.get_error() == no_error
	owner.delete_program(program)
	assert owner.get_attached_shaders(program) == none
	assert owner.get_error() == invalid_operation
	assert owner.get_program_info_log(program) == none
	assert owner.get_error() == invalid_operation
	owner.delete_shader(vertex)
	assert owner.get_shader_source(vertex) == none
	assert owner.get_error() == invalid_operation
	assert owner.get_shader_info_log(vertex) == none
	assert owner.get_error() == invalid_operation
}
