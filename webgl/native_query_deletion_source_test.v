// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl


fn deletion_query_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_query_delete_selects_owner_before_all_early_returns_and_keeps_slot() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut foreign := other.create_query()
	context.delete_query(foreign)
	deletion_query_source_owner()
	assert !foreign.object.invalidated()
	assert context.get_error() == invalid_operation
	other.native.make_current()
	mut absent := ?&WebGLQuery(none)
	context.delete_query(absent)
	deletion_query_source_owner()
	assert context.get_error() == no_error
	mut owned := context.create_query()
	context.begin_query(any_samples_passed, mut owned)
	context.end_query(any_samples_passed)
	assert C.vox_gl_is_object(4,owned.object.native_handle_) == 1
	// A rejected retarget still installs the source's independent retained slot.
	context.begin_query(transform_feedback_primitives_written, mut owned)
	assert context.get_error() == invalid_operation
	other.native.make_current()
	context.delete_query(owned)
	deletion_query_source_owner()
	assert C.vox_gl_is_object(4,owned.object.native_handle_) == 0
	assert owned.object.invalidated()
	assert owned.object.handle_ !in context.queries
	assert context.get_query(transform_feedback_primitives_written, current_query)? == owned
	assert context.get_error() == no_error
	other.native.make_current()
	context.delete_query(owned)
	deletion_query_source_owner()
	assert context.get_query(transform_feedback_primitives_written, current_query)? == owned
	assert context.get_error() == no_error
}
