// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_lost_is_shader_sync_returns_default_without_other_native_query() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		original := owner.create_shader(vertex_shader) or { panic('owned shader before loss') }
		sentinel := other.create_shader(vertex_shader) or { panic('other genuine shader') }
		assert original.object.native_name() == sentinel.object.native_name()
		assert owner.is_shader(original)
		owner.lose_context_from_compositor_loss()
		assert owner.native.is_lost()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		after_loss := owner.create_shader(vertex_shader) or { panic('owned proxy shader after loss') }
		assert after_loss.object.native_name() == 0
		assert owner.owns(&after_loss.object)
		assert after_loss.object.handle(owner.identity(), owner.context_generation())! == 2
		for shader in [original, after_loss] {
			assert !owner.is_shader(shader)
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_is_object(9, sentinel.object.native_name()) == 1
		}
		assert !owner.is_shader(none)
		assert !owner.is_shader(sentinel)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		assert owner.get_error() == context_lost_webgl
		assert owner.get_error() == no_error
		assert other.is_shader(sentinel)
		assert other.get_error() == no_error
	}
}

fn test_source_live_is_shader_retains_actual_driver_result_outside_wrapper_state() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut owner := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		shader := owner.create_shader(vertex_shader) or { panic('live driver shader') }
		owner.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		assert owner.is_shader(shader)
		C.vox_gl_delete_shader(shader.object.native_name())
		assert owner.owns(&shader.object)
		assert C.vox_gl_is_object(9, shader.object.native_name()) == 0
		other.native.make_current()
		assert !owner.is_shader(shader)
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert owner.get_error() == no_error
	}
}
