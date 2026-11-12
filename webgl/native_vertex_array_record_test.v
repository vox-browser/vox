// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_vertex_array_binding_returns_actual_record_without_driver_substitution() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut array := context.create_vertex_array()
	context.bind_vertex_array(array)
	assert C.vox_gl_is_vertex_array(array.object.native_handle_, 0) == 1
	C.vox_gl_delete_object(6, array.object.native_handle_)
	mut actual := i32(-1)
	C.vox_gl_int_parameter(vertex_array_binding, &actual)
	assert actual == 0
	result := context.get_parameter(vertex_array_binding)
	assert result.kind == .object
	assert result.vertex_array? == array
	assert result.object == array.object.bookkeeping_id()
	assert result.vertex_array_oes == none
	context.delete_vertex_array(mut array)
	assert context.get_parameter(vertex_array_binding).kind == .none
	assert context.get_error() == no_error
}

fn test_source_oes_vertex_array_binding_returns_actual_record_and_preserves_extension_gate() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	assert context.get_parameter(vertex_array_binding).kind == .none
	assert context.get_error() == invalid_enum
	context.get_extension('OES_vertex_array_object', false) or { panic('OES VAO') }
	array := context.create_vertex_array_oes()
	context.bind_vertex_array_oes(array)
	assert C.vox_gl_is_vertex_array(array.object.native_handle_, 1) == 1
	C.vox_gl_delete_object(7, array.object.native_handle_)
	mut actual := i32(-1)
	C.vox_gl_int_parameter(vertex_array_binding, &actual)
	assert actual == 0
	result := context.get_parameter(vertex_array_binding)
	assert result.kind == .object
	assert result.vertex_array_oes? == array
	assert result.object == array.object.bookkeeping_id()
	assert result.vertex_array == none
	context.delete_vertex_array_oes(array)
	assert context.get_parameter(vertex_array_binding).kind == .none
	assert context.get_error() == no_error
}
