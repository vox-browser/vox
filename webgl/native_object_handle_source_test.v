// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webgl

fn test_source_object_handle_apis_use_proxy_ids_and_delete_mapped_native_names() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		mut other := WebGLRenderingContext.new(version, WebGLContextAttributes{}, [])
		context.native.make_current()
		mut reserved := []GLuint{}
		for _ in 0 .. 8 {
			name := C.vox_gl_gen_object(0)
			C.vox_gl_bind_buffer(array_buffer, name)
			reserved << name
		}
		// Source getter factories retain the raw numeric query reply and consume
		// only compact wrapper identities, never the generated creation counter.
		for _ in 0 .. 3 {
			fresh := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or {
				panic('source fresh binding record')
			}
			assert fresh.object.handle(context.identity(), context.context_generation())! == 0
			assert fresh.object.native_name() == 0
			assert fresh.object.bookkeeping_id() > 0
		}
		assert context.next_object_id == 1
		mut buffer := context.create_buffer()
		actual := buffer.object.native_handle_
		bookkeeping := buffer.object.bookkeeping_id()
		assert actual != bookkeeping
		assert actual !in reserved
		assert buffer.object.handle(context.identity(), context.context_generation())! == 1
		assert buffer.object.handle(context.identity(), context.context_generation())! != bookkeeping
		query := buffer.object.handle_for_query(context.identity(), context.context_generation())!
		assert query.has_value
		assert query.value == 1
		mut rejected := false
		buffer.object.handle_for_deletion(other.identity(), other.context_generation()) or {
			assert err.msg() == 'GL_INVALID_OPERATION'
			rejected = true
		}
		assert rejected
		assert !buffer.object.invalidated()
		context.bind_buffer(array_buffer, buffer)
		assert C.vox_gl_is_object(0, actual) == 1
		assert context.buffers[bookkeeping] == buffer
		context.delete_buffer(buffer)
		assert C.vox_gl_is_object(0, actual) == 0
		assert bookkeeping !in context.buffers
		assert buffer.object.bookkeeping_id() == bookkeeping
		assert !buffer.object.handle_for_query(context.identity(), context.context_generation())!.has_value
		assert !buffer.object.handle_for_deletion(context.identity(), context.context_generation())!.has_value
		for name in reserved {
			assert C.vox_gl_is_object(0, name) == 1
			C.vox_gl_delete_object(0, name)
		}
		assert context.get_error() == no_error
	}
}

fn test_all_source_named_resource_handles_and_cache_deletion_use_distinct_namespaces() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	buffer := context.create_buffer()
	framebuffer_object := context.create_framebuffer()
	renderbuffer_object := context.create_renderbuffer()
	texture := context.create_texture()
	shader := context.create_shader(vertex_shader) or { panic('source shader') }
	program := context.create_program()
	mut query := context.create_query()
	mut sampler := context.create_sampler()
	feedback := context.create_transform_feedback()
	mut array := context.create_vertex_array()
	for index, object in [&buffer.object, &framebuffer_object.object, &renderbuffer_object.object,
		&texture.object, &shader.object, &program.object, &query.object, &sampler.object,
		&feedback.object, &array.object] {
		assert object.native_handle_ != 0
		assert object.handle(context.identity(), context.context_generation())! == GLuint(index + 1)
		result := object.handle_for_query(context.identity(), context.context_generation())!
		assert result.has_value
		assert result.value == GLuint(index + 1)
	}
	context.delete_buffer(buffer)
	context.delete_framebuffer(framebuffer_object)
	context.delete_renderbuffer(renderbuffer_object)
	context.delete_texture(texture)
	context.delete_shader(shader)
	context.delete_program(program)
	context.delete_query(query)
	context.delete_sampler(mut sampler)
	context.delete_transform_feedback(feedback)
	context.delete_vertex_array(mut array)
	assert context.buffers.len == 0
	assert context.framebuffers.len == 0
	assert context.renderbuffers.len == 0
	assert context.textures.len == 0
	assert context.shaders.len == 0
	assert context.programs.len == 0
	assert context.queries.len == 0
	assert context.samplers.len == 0
	assert context.transform_feedbacks.len == 0
	assert context.vertex_arrays.len == 0
	assert context.get_error() == no_error
	mut webgl1 := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	webgl1.get_extension('OES_vertex_array_object', false) or { panic('source OES VAO') }
	oes := webgl1.create_vertex_array_oes()
	assert oes.object.handle(webgl1.identity(), webgl1.context_generation())! == 1
	webgl1.delete_vertex_array_oes(oes)
	assert webgl1.vertex_arrays_oes.len == 0
	assert webgl1.get_error() == no_error
}

fn test_source_shader_proxy_id_and_sync_base_zero_remain_distinct_from_native_handles() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('source sync') }
	assert sync.native_handle_ != unsafe { nil }
	assert sync.object.bookkeeping_id() > 0
	assert uint(sync.sync_handle(context.identity(), context.context_generation())!) == 1
	assert context.next_object_id == 2
	assert sync.object.handle(context.identity(), context.context_generation())! == 0
	base_query := sync.object.handle_for_query(context.identity(), context.context_generation())!
	assert base_query.has_value
	assert base_query.value == 0
	base_delete := sync.object.handle_for_deletion(context.identity(), context.context_generation())!
	assert base_delete.has_value
	assert base_delete.value == 0
	assert sync.object.invalidated()
	assert !sync.object.handle_for_deletion(context.identity(), context.context_generation())!.has_value
	C.vox_gl_delete_sync(sync.native_handle_)
	assert C.vox_gl_get_error() == no_error
	// ANGLE itself produces zero after the real production EGL-loss path.
	context.lose_context_from_compositor_loss()
	assert C.vox_gl_create_shader(vertex_shader) == 0
	mut zero := context.create_shader(vertex_shader) or { panic('zero native shader record') }
	assert zero.object.native_handle_ == 0
	assert zero.object.bookkeeping_id() > 0
	assert zero.object.handle(context.identity(), context.context_generation())! == 2
	zero_query := zero.object.handle_for_query(context.identity(), context.context_generation())!
	assert zero_query.has_value
	assert zero_query.value == 2
	zero_delete := zero.object.handle_for_deletion(context.identity(), context.context_generation())!
	assert zero_delete.has_value
	assert zero_delete.value == 2
	assert !zero.object.handle_for_deletion(context.identity(), context.context_generation())!.has_value
}

fn test_source_raw_query_factory_values_do_not_consume_generated_ids() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	first := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or {
		panic('source zero buffer reply')
	}
	sampler_reply := context.get_parameter(sampler_binding).sampler or {
		panic('source zero sampler reply')
	}
	assert first.object.handle(context.identity(), context.context_generation())! == 0
	assert sampler_reply.object.handle(context.identity(), context.context_generation())! == 0
	assert first.object.bookkeeping_id() != sampler_reply.object.bookkeeping_id()
	assert context.next_object_id == 1
	buffer := context.create_buffer()
	assert buffer.object.handle(context.identity(), context.context_generation())! == 1
	assert buffer.object.bookkeeping_id() == 3
	context.bind_buffer(array_buffer, buffer)
	context.vertex_attrib_pointer(0, 2, gl_float, false, 0, 0)
	fresh := context.get_vertex_attrib(0, vertex_attrib_array_buffer_binding).buffer or {
		panic('source genuine native binding reply')
	}
	assert fresh != buffer
	assert fresh.object.handle(context.identity(), context.context_generation())! == buffer.object.native_name()
	assert fresh.object.native_name() == buffer.object.native_name()
	assert context.next_object_id == 2
	mut sync := context.fence_sync(sync_gpu_commands_complete, 0) or { panic('source shared allocator sync') }
	assert uint(sync.sync_handle(context.identity(), context.context_generation())!) == 2
	assert sync.object.handle(context.identity(), context.context_generation())! == 0
	shader := context.create_shader(vertex_shader) or { panic('source creation after getter and sync') }
	assert shader.object.handle(context.identity(), context.context_generation())! == 3
	assert context.get_error() == no_error
	context.delete_sync(mut sync)
}
