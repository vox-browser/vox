// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl


fn transform_feedback_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_transform_feedback_never_assigns_the_declared_retained_slot() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	feedback := context.create_transform_feedback()
	foreign := other.create_transform_feedback()
	other.native.make_current()
	context.bind_transform_feedback(transform_feedback, feedback)
	transform_feedback_source_owner()
	mut actual := i32(0)
	C.vox_gl_int_parameter(transform_feedback_binding, &actual)
	assert GLuint(actual) == feedback.object.native_handle_
	assert C.vox_gl_is_object(8,feedback.object.native_handle_) == 1
	assert context.current_transform_feedback == none
	assert context.get_parameter(transform_feedback_binding).kind == .none
	assert context.get_error() == no_error
	C.vox_gl_bind_transform_feedback(0xbad, feedback.object.native_handle_)
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	context.bind_transform_feedback(0xbad, feedback)
	transform_feedback_source_owner()
	assert context.get_error() == expected
	C.vox_gl_int_parameter(transform_feedback_binding, &actual)
	assert GLuint(actual) == feedback.object.native_handle_
	other.native.make_current()
	context.bind_transform_feedback(0xbad, foreign)
	transform_feedback_source_owner()
	assert context.get_error() == invalid_operation
	assert !foreign.object.invalidated()
	other.native.make_current()
	context.delete_transform_feedback(foreign)
	transform_feedback_source_owner()
	assert context.get_error() == invalid_operation
	assert !foreign.object.invalidated()
	for _ in 0 .. 2 {
		other.native.make_current()
		context.delete_transform_feedback(none)
		transform_feedback_source_owner()
		assert context.get_error() == no_error
	}
	other.native.make_current()
	context.delete_transform_feedback(feedback)
	transform_feedback_source_owner()
	assert feedback.object.invalidated()
	assert C.vox_gl_is_object(8,feedback.object.native_handle_) == 0
	C.vox_gl_int_parameter(transform_feedback_binding, &actual)
	assert actual == 0
	assert context.get_parameter(transform_feedback_binding).kind == .none
	other.native.make_current()
	context.delete_transform_feedback(feedback)
	transform_feedback_source_owner()
	assert context.get_error() == no_error
	other.native.make_current()
	context.bind_transform_feedback(0xbad, feedback)
	transform_feedback_source_owner()
	assert context.get_error() == invalid_operation
}

fn test_source_transform_feedback_varyings_selects_owner_before_program_validation() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	foreign := other.create_program()
	context.transform_feedback_varyings(foreign, ['output'], 0xbad)
	transform_feedback_source_owner()
	assert context.get_error() == invalid_operation
	owned := context.create_program()
	names := ['output'].map(voidptr(it.str))
	C.vox_gl_transform_feedback_varyings(owned.object.native_handle_, names.len, names.data, 0xbad)
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	context.transform_feedback_varyings(owned, ['output'], 0xbad)
	transform_feedback_source_owner()
	assert context.get_error() == expected
	context.transform_feedback_varyings(owned, [], 0x8c8c)
	assert context.get_error() == no_error
	context.delete_program(owned)
	other.native.make_current()
	context.transform_feedback_varyings(owned, [], 0x8c8c)
	transform_feedback_source_owner()
	assert context.get_error() == invalid_operation
}
