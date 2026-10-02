// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2025, Undefine <undefine@undefine.pl>
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_native_uniform_reflection_invalid_program_and_empty_result_shapes() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut foreign := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut vertex := context.create_shader(vertex_shader) or { panic('vertex') }
	mut fragment := context.create_shader(fragment_shader) or { panic('fragment') }
	context.shader_source(mut vertex, '#version 300 es\nvoid main(){gl_Position=vec4(0.0);}')
	context.shader_source(mut fragment, '#version 300 es\nprecision mediump float;uniform vec4 tint;out vec4 color;void main(){color=tint;}')
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	mut program := context.create_program()
	context.attach_shader(mut program, vertex)
	context.attach_shader(mut program, fragment)
	context.link_program(mut program)
	assert program.linked_
	assert context.get_uniform_indices_nullable(program, [])? == []GLuint{}
	assert context.get_error() == no_error
	assert foreign.get_uniform_indices_nullable(program, ['tint']) == none
	assert foreign.get_error() == invalid_operation
	assert foreign.get_active_uniforms(program, [], uniform_type).kind == .undefined_
	assert foreign.get_error() == invalid_operation
	indices := context.get_uniform_indices_nullable(program, ['tint'])?
	assert indices.len == 1
	assert context.get_active_uniforms(program, [], 0xdead).kind == .integers
	assert context.get_active_uniforms(program, [], uniform_is_row_major).booleans.len == 0
	assert context.get_error() == invalid_enum
	assert context.get_active_uniforms(program, indices, 0xdead).kind == .none
	assert context.get_error() == invalid_enum
	// Source get_error_value returns the native error before the separate
	// per-element local validation error.
	assert context.get_error() == invalid_enum
	assert context.get_error() == no_error
	context.delete_program(program)
	assert context.get_uniform_indices_nullable(program, []) == none
	assert context.get_error() == invalid_operation
	assert context.get_active_uniforms(program, [], uniform_type).kind == .undefined_
	assert context.get_error() == invalid_operation
}
