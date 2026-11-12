// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn retained_binding_native_int(pname GLenum) int {
	mut result := i32(0)
	C.vox_gl_int_parameter(pname, &result)
	return result
}

fn test_source_indexed_binds_leave_generic_retained_slots_unchanged() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	for target in [uniform_buffer, transform_feedback_buffer] {
		pname := if target == uniform_buffer {
			uniform_buffer_binding
		} else {
			transform_feedback_buffer_binding
		}
		original := context.create_buffer()
		indexed := context.create_buffer()
		context.bind_buffer_base(target, 0, indexed)
		assert context.get_parameter(pname).kind == .none
		assert retained_binding_native_int(pname) == int(indexed.object.native_handle_)
		context.bind_buffer(target, original)
		context.buffer_data_size(target, 32, 0x88e4)
		context.bind_buffer_base(target, 0, indexed)
		assert context.get_parameter(pname).buffer? == original
		assert retained_binding_native_int(pname) == int(indexed.object.native_handle_)
		context.buffer_data_size(target, 32, 0x88e4)
		context.bind_buffer_range(target, 0, indexed, 0, 16)
		assert context.get_parameter(pname).buffer? == original
		assert retained_binding_native_int(pname) == int(indexed.object.native_handle_)
		context.bind_buffer_base(target, 0, none)
		assert context.get_parameter(pname).buffer? == original
		assert retained_binding_native_int(pname) == 0
		context.bind_buffer_range(target, 0, none, 0, 16)
		assert context.get_parameter(pname).buffer? == original
		assert retained_binding_native_int(pname) == 0
		assert context.get_error() == no_error
		foreign := other.create_buffer()
		other.native.make_current()
		context.bind_buffer_base(0xbad, 0, foreign)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
		other.native.make_current()
		context.bind_buffer_range(0xbad, 0, foreign, -1, -1)
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == invalid_operation
	}
}

fn test_source_vao_changes_leave_element_retained_slot_unchanged() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		if version == .webgl1 { context.get_extension('OES_vertex_array_object', false)? }
		initial := context.create_buffer()
		retained := context.create_buffer()
		context.bind_buffer(element_array_buffer, initial)
		if version == .webgl2 {
			mut array := context.create_vertex_array()
			context.bind_vertex_array(array)
			assert context.get_parameter(element_array_buffer_binding).buffer? == initial
			assert retained_binding_native_int(element_array_buffer_binding) == 0
			context.bind_buffer(element_array_buffer, retained)
			context.bind_vertex_array(none)
			assert context.get_parameter(element_array_buffer_binding).buffer? == retained
			assert retained_binding_native_int(element_array_buffer_binding) == int(initial.object.native_handle_)
			// An unrelated pending driver error cannot block the source VAO slot write.
			C.vox_gl_bind_buffer(0xbad, 0)
			context.bind_vertex_array(array)
			assert context.current_vertex_array_binding()? == &array.object
			assert context.get_error() == invalid_enum
			context.delete_vertex_array(mut array)
			assert context.current_vertex_array_binding() == none
			assert context.get_parameter(element_array_buffer_binding).buffer? == retained
			assert retained_binding_native_int(element_array_buffer_binding) == int(initial.object.native_handle_)
			other.native.make_current()
			context.delete_vertex_array(mut array)
		} else {
			array := context.create_vertex_array_oes()
			context.bind_vertex_array_oes(array)
			assert context.get_parameter(element_array_buffer_binding).buffer? == initial
			assert retained_binding_native_int(element_array_buffer_binding) == 0
			context.bind_buffer(element_array_buffer, retained)
			context.bind_vertex_array_oes(none)
			assert context.get_parameter(element_array_buffer_binding).buffer? == retained
			assert retained_binding_native_int(element_array_buffer_binding) == int(initial.object.native_handle_)
			C.vox_gl_bind_buffer(0xbad, 0)
			context.bind_vertex_array_oes(array)
			assert context.current_vertex_array_binding()? == &array.object
			assert context.get_error() == invalid_enum
			context.delete_vertex_array_oes(array)
			assert context.current_vertex_array_binding() == none
			assert context.get_parameter(element_array_buffer_binding).buffer? == retained
			assert retained_binding_native_int(element_array_buffer_binding) == int(initial.object.native_handle_)
			other.native.make_current()
			context.delete_vertex_array_oes(array)
		}
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.get_error() == no_error
	}
}
