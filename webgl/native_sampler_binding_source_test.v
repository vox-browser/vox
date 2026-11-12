// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl


fn sampler_binding_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_source_sampler_binding_and_deletion_use_only_driver_bindings_and_owner_first() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut other := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.viewport(1, 2, 3, 4)
	other.viewport(9, 10, 11, 12)
	mut sampler := context.create_sampler()
	mut foreign := other.create_sampler()
	for unit in [GLuint(0), 1] {
		other.native.make_current()
		context.bind_sampler(unit, sampler)
		sampler_binding_source_owner()
		context.active_texture(texture0 + unit)
		mut actual := i32(0)
		C.vox_gl_int_parameter(sampler_binding, &actual)
		assert GLuint(actual) == sampler.object.native_handle_
		first := context.get_parameter(sampler_binding).sampler or { panic('first sampler') }
		second := context.get_parameter(sampler_binding).sampler or { panic('second sampler') }
		assert first != sampler
		assert first != second
		assert first.object.native_handle_ == sampler.object.native_handle_
		assert second.object.native_handle_ == sampler.object.native_handle_
		assert first.object.handle(context.identity(), context.context_generation())! == sampler.object.native_handle_
	}
	C.vox_gl_bind_sampler(0xffffffff, sampler.object.native_handle_)
	expected := C.vox_gl_get_error()
	assert expected != no_error
	other.native.make_current()
	context.bind_sampler(0xffffffff, sampler)
	sampler_binding_source_owner()
	assert context.get_error() == expected
	mut actual := i32(0)
	C.vox_gl_int_parameter(sampler_binding, &actual)
	assert GLuint(actual) == sampler.object.native_handle_
	other.native.make_current()
	context.bind_sampler(0xffffffff, foreign)
	sampler_binding_source_owner()
	assert context.get_error() == invalid_operation
	assert !foreign.object.invalidated()
	other.native.make_current()
	context.delete_sampler(foreign)
	sampler_binding_source_owner()
	assert context.get_error() == invalid_operation
	assert !foreign.object.invalidated()
	mut absent := ?&WebGLSampler(none)
	other.native.make_current()
	context.delete_sampler(absent)
	sampler_binding_source_owner()
	assert context.get_error() == no_error
	other.native.make_current()
	context.delete_sampler(sampler)
	sampler_binding_source_owner()
	assert C.vox_gl_is_object(5,sampler.object.native_handle_) == 0
	assert sampler.object.invalidated()
	for unit in [GLuint(0), 1] {
		context.active_texture(texture0 + unit)
		C.vox_gl_int_parameter(sampler_binding, &actual)
		assert actual == 0
		zero := context.get_parameter(sampler_binding).sampler or { panic('source zero sampler') }
		assert zero.object.handle(context.identity(), context.context_generation())! == 0
		assert zero != context.get_parameter(sampler_binding).sampler?
	}
	other.native.make_current()
	context.delete_sampler(sampler)
	sampler_binding_source_owner()
	assert context.get_error() == no_error
	other.native.make_current()
	context.bind_sampler(0xffffffff, sampler)
	sampler_binding_source_owner()
	assert context.get_error() == invalid_operation
}
