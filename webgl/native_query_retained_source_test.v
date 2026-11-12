// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn C.glGetQueryiv(u32, u32, &i32)

fn query_source_native_current(target GLenum) int {
	mut value := i32(0)
	C.glGetQueryiv(target, current_query, &value)
	return value
}

fn query_source_selected_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_query_slots_change_before_driver_calls_even_when_gl_rejects() {
	for target in [any_samples_passed, any_samples_passed_conservative,
		transform_feedback_primitives_written] {
		mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		mut first := context.create_query()
		mut replacement := context.create_query()
		context.begin_query(target, mut first)
		assert query_source_native_current(target) == int(first.object.native_handle_)
		assert context.get_query(target, current_query)? == first
		assert context.get_error() == no_error
		C.vox_gl_begin_query(target, replacement.object.native_handle_)
		expected_duplicate := C.vox_gl_get_error()
		assert expected_duplicate != no_error
		other.native.make_current()
		context.begin_query(target, mut replacement)
		query_source_selected_owner()
		assert context.get_query(target, current_query)? == replacement
		assert query_source_native_current(target) == int(first.object.native_handle_)
		assert context.get_error() == expected_duplicate
		// Remove the actual active query while preserving the source's slot.
		C.vox_gl_end_query(target)
		C.vox_gl_end_query(target)
		expected_missing := C.vox_gl_get_error()
		assert expected_missing != no_error
		other.native.make_current()
		context.end_query(target)
		query_source_selected_owner()
		assert context.get_query(target, current_query) == none
		assert query_source_native_current(target) == 0
		assert context.get_error() == expected_missing
		context.begin_query(target, mut first)
		C.vox_gl_bind_buffer(0xbad, 0)
		other.native.make_current()
		context.end_query(target)
		query_source_selected_owner()
		assert context.get_query(target, current_query) == none
		assert query_source_native_current(target) == 0
		assert context.get_error() == invalid_enum
		// getQuery reads the retained source slot and never selects GL.
		other.native.make_current()
		assert context.get_query(target, current_query) == none
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}

fn test_source_query_validates_only_handle_before_target_driver_errors() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut foreign := other.create_query()
	context.begin_query(0xbad, mut foreign)
	query_source_selected_owner()
	assert context.get_error() == invalid_operation
	mut owned := context.create_query()
	C.vox_gl_begin_query(0xbad, owned.object.native_handle_)
	expected_begin := C.vox_gl_get_error()
	other.native.make_current()
	context.begin_query(0xbad, mut owned)
	query_source_selected_owner()
	assert context.current_queries.len == 0
	assert context.get_error() == expected_begin
	C.vox_gl_end_query(0xbad)
	expected_end := C.vox_gl_get_error()
	other.native.make_current()
	context.end_query(0xbad)
	query_source_selected_owner()
	assert context.current_queries.len == 0
	assert context.get_error() == expected_end
	context.begin_query(any_samples_passed, mut owned)
	context.end_query(any_samples_passed)
	assert context.get_error() == no_error
	// The driver's target compatibility is not copied into WebGLQuery fields.
	C.vox_gl_begin_query(transform_feedback_primitives_written, owned.object.native_handle_)
	expected_retarget := C.vox_gl_get_error()
	assert expected_retarget != no_error
	other.native.make_current()
	context.begin_query(transform_feedback_primitives_written, mut owned)
	query_source_selected_owner()
	assert context.get_query(transform_feedback_primitives_written, current_query)? == owned
	assert query_source_native_current(transform_feedback_primitives_written) == 0
	assert context.get_error() == expected_retarget
	context.delete_query(mut owned)
	other.native.make_current()
	context.begin_query(0xbad, mut owned)
	query_source_selected_owner()
	assert context.get_error() == invalid_operation
	assert context.get_query(transform_feedback_primitives_written, current_query)? == owned
}
