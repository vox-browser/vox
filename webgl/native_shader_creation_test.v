// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_shader_creation_source_type_gate_precedes_real_native_creation_owner() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.viewport(1, 2, 3, 4)
		other.viewport(9, 10, 11, 12)
		for type_ in [GLenum(0), GLenum(0xbad), GLenum(0xffff), GLenum(0xffff_ffff)] {
			previous_records := context.shaders.len
			context.native.make_current()
			C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
			other.native.make_current()
			assert context.create_shader(type_) == none
			mut selected := [0, 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [9, 10, 11, 12]!
			assert context.shaders.len == previous_records
			assert context.get_error() == invalid_value
			assert context.get_error() == invalid_enum
			assert context.get_error() == no_error
		}
		for type_ in [vertex_shader, fragment_shader] {
			other.native.make_current()
			shader := context.create_shader(type_) or { panic('source actual shader') }
			mut selected := [0, 0, 0, 0]!
			C.vox_gl_int_parameter(viewport, &selected[0])
			assert selected == [1, 2, 3, 4]!
			assert shader.type_ == type_
			assert C.vox_gl_shader_parameter(shader.object.native_handle_, shader_type) == int(type_)
			assert context.owns(&shader.object)
			assert context.get_error() == no_error
		}
	}
}

fn test_source_shader_creation_retains_owned_record_for_actual_native_zero() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		initial := context.create_shader(vertex_shader) or { panic('initial shader') }
		assert initial.object.native_handle_ != 0
		context.lose_context_from_compositor_loss()
		assert context.native.is_lost()
		mut zero_shaders := []&WebGLShader{}
		// The production loss path destroys and unbinds its native GL context.
		// The backend supplies zero here; this test installs no substitute backend.
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
			assert source_handle > 0
			assert source_handle == shader.object.source_handle_
			assert shader.object.bookkeeping_id() > 0
			query_handle := shader.object.handle_for_query(context.identity(), context.context_generation())!
			assert query_handle.has_value
			assert query_handle.value == source_handle
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
		assert context.next_object_id == 4
		restored_shader := context.create_shader(vertex_shader) or { panic('source ID after restoration') }
		assert restored_shader.object.handle(context.identity(), context.context_generation())! == 4
	}
}

fn test_source_lost_shader_creation_retains_owned_ids_without_touching_other_driver() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		other.viewport(9, 10, 11, 12)
		mut sentinel := other.create_shader(vertex_shader) or { panic('other driver sentinel') }
		sentinel_source := 'void main(){gl_Position=vec4(0);}'
		other.shader_source(mut sentinel, sentinel_source)
		context.lose_context_from_compositor_loss()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		previous_records := context.shaders.len
		first_proxy_id := context.next_object_id
		mut creation_index := GLuint(0)
		for type_ in [vertex_shader, fragment_shader] {
			shader := context.create_shader(type_) or { panic('lost source shader record') }
			assert shader.type_ == type_
			assert shader.object.native_handle_ == 0
			assert context.owns(&shader.object)
			assert shader.object.handle(context.identity(), context.context_generation())! == first_proxy_id + creation_index
			assert shader.object.bookkeeping_id() != 0
			creation_index++
			assert context.shaders[shader.object.bookkeeping_id()] == shader
		}
		assert context.shaders.len == previous_records + 2
		mut selected := [0, 0, 0, 0]!
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [9, 10, 11, 12]!
		assert C.vox_gl_is_object(9, sentinel.object.native_handle_) == 1
		assert C.vox_gl_get_error() == invalid_value
		assert C.vox_gl_get_error() == no_error
		assert other.get_shader_source(sentinel) or { panic('other retained driver source') } == sentinel_source
		assert context.get_error() == context_lost_webgl
		assert context.get_error() == no_error
		C.vox_gl_int_parameter(viewport, &selected[0])
		assert selected == [9, 10, 11, 12]!
	}
}
