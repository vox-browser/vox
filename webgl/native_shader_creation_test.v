// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_shader_creation_retains_owned_record_for_actual_native_zero() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		initial := context.create_shader(vertex_shader) or { panic('initial shader') }
		assert initial.object.native_handle_ != 0
		context.lose_context_from_compositor_loss()
		assert context.native.is_lost()
		mut zero_shaders := []&WebGLShader{}
		// The production loss path destroys EGL and unbinds its current context.
		// ANGLE itself supplies zero here; this test installs no substitute backend.
		for type_ in [vertex_shader, fragment_shader] {
			native_handle := C.vox_gl_create_shader(type_)
			assert native_handle == 0
			shader := context.create_shader(type_) or { panic('source zero-name shader record') }
			assert shader.object.native_handle_ == native_handle
			assert shader.type_ == type_
			assert context.owns(&shader.object)
			assert !shader.object.invalidated()
			assert context.shaders[shader.object.handle_] == shader
			source_handle := shader.object.handle(context.identity(), context.context_generation()) or {
				panic(err)
			}
			assert source_handle == 0
			assert shader.object.bookkeeping_id() > 0
			query_handle := shader.object.handle_for_query(context.identity(), context.context_generation())!
			assert query_handle.has_value
			assert query_handle.value == 0
			zero_shaders << shader
		}
		first_error := context.get_error()
		second_error := context.get_error()
		assert first_error == context_lost_webgl
		assert second_error == no_error
		context.request_context_restore()
		restored := context.restore_context_after_compositor_reconnect()
		assert restored
		assert !context.owns(&initial.object)
		for shader in zero_shaders {
			assert !context.owns(&shader.object)
			assert shader.object.invalidated_for_context(context.context_generation())
		}
		assert context.context_generation() == 1
	}
}
