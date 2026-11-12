// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2024-2025, Aliaksandr Kalenik <kalenik.aliaksandr@gmail.com>
// Copyright (c) 2024-2025, Luke Wilde <luke@ladybird.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2025, Undefine <undefine@undefine.pl>
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebGL2RenderingContext, WebGL2RenderingContextImpl and its
// overloads. Native pixels, GLSL reflection and actual GPU execution remain
// ordered OpenGLContext dispatches; Web-exposed validation/state lives here.
module webgl

fn (mut context WebGLRenderingContext) require_webgl2() bool {
	if context.version != .webgl2 {
		context.set_error(invalid_operation)
		return false
	}
	return true
}

pub fn (mut context WebGLRenderingContext) copy_buffer_sub_data(read_target GLenum, write_target GLenum, read_offset i64, write_offset i64, size i64) {
    if !context.require_webgl2() { return }
    context.native.dispatch('copy_buffer_sub_data', read_target, write_target, read_offset, write_offset, size)
    C.vox_gl_copy_buffer_sub_data(read_target, write_target, read_offset, write_offset, size)
}

pub fn (mut context WebGLRenderingContext) get_buffer_sub_data(target GLenum, source_offset i64, mut destination []u8, destination_offset int, length int) {
    if !context.require_webgl2() { return }
    if destination_offset < 0 || length < 0 || destination_offset > destination.len {
        context.set_error(invalid_value)
        return
    }
    copy_length := if length == 0 { destination.len - destination_offset } else { length }
    if copy_length == 0 { return }
    if copy_length > destination.len - destination_offset { context.set_error(invalid_value); return }
    context.native.dispatch('get_buffer_sub_data', target, source_offset, destination_offset, copy_length)
    mut bytes := []u8{len: copy_length}
    success := C.vox_gl_read_buffer_sub_data(target, source_offset, copy_length, bytes.data) == 1
    if success { copy(mut destination[destination_offset..destination_offset + copy_length], bytes) }
}

pub fn (mut context WebGLRenderingContext) create_query() &WebGLQuery {
	context.require_webgl2()
	context.native.make_current()
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	query := &WebGLQuery{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle, source_handle), native_handle_: C.vox_gl_gen_object(4)}
	}
	unsafe {
		context.queries[handle] = query
	}
	return query
}

fn valid_query_target(target GLenum) bool {
	return target in [any_samples_passed, any_samples_passed_conservative,
		transform_feedback_primitives_written]
}

pub fn (mut context WebGLRenderingContext) begin_query(target GLenum, mut query WebGLQuery) {
	context.native.make_current()
	if !context.require_webgl2() {
		return
	}
	if !context.owns(&query.object) {
		context.set_error(invalid_operation)
		return
	}
	if valid_query_target(target) {
		unsafe {
			context.current_queries[target] = query
		}
	}
	context.native.dispatch('begin_query', target, query.object.handle_)
	C.vox_gl_begin_query(target, query.object.native_handle_)
}

pub fn (mut context WebGLRenderingContext) end_query(target GLenum) {
	context.native.make_current()
	if !context.require_webgl2() {
		return
	}
	if valid_query_target(target) {
		context.current_queries.delete(target)
	}
	context.native.dispatch('end_query', target)
	C.vox_gl_end_query(target)
}

pub fn (mut context WebGLRenderingContext) get_query(target GLenum, pname GLenum) ?&WebGLQuery {
	if pname != current_query || !valid_query_target(target) {
		context.set_error(invalid_enum)
		return none
	}
	return context.current_queries[target] or { none }
}

pub fn (mut context WebGLRenderingContext) get_query_parameter(query &WebGLQuery, pname GLenum) ?u64 {
	context.native.make_current()
	if !context.require_webgl2() { return none }
	if !context.owns(&query.object) {
		context.set_error(invalid_operation)
		return none
	}
	result := C.vox_gl_query_parameter(query.object.native_handle_, pname)
	if pname !in [query_result, query_result_available] { return none }
	return u64(result)
}

// Borrow the optional; only the owned object changes during deletion.
// A mutable optional would require callers to pass an option container ABI.
pub fn (mut context WebGLRenderingContext) delete_query(query ?&WebGLQuery) {
	context.native.make_current()
	if value := query {
        mut mutable_value:=unsafe { &WebGLQuery(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.queries.delete(handle)
		context.native.dispatch('delete_query', handle)
		C.vox_gl_delete_object(4, value.object.native_handle_)
	}
}

pub fn (mut context WebGLRenderingContext) create_sampler() &WebGLSampler {
	context.require_webgl2()
	context.native.make_current()
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	sampler := &WebGLSampler{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle, source_handle), native_handle_: C.vox_gl_gen_object(5)}
	}
	unsafe {
		context.samplers[handle] = sampler
	}
	return sampler
}

pub fn (mut context WebGLRenderingContext) bind_sampler(unit GLuint, sampler ?&WebGLSampler) {
	context.native.make_current()
	if !context.require_webgl2() { return }
	if value := sampler {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
	}
	context.native.dispatch('bind_sampler', unit, if value := sampler {
		value.object.handle_
	} else {
		0
	})
	C.vox_gl_bind_sampler(unit, if value := sampler { value.object.native_handle_ } else { 0 })
}

fn valid_sampler_parameter(pname GLenum) bool {
	return pname in [texture_compare_func, texture_compare_mode, texture_mag_filter, texture_max_lod,
		texture_min_filter, texture_min_lod, texture_wrap_r, texture_wrap_s, texture_wrap_t]
}

pub fn (mut context WebGLRenderingContext) sampler_parameteri(mut sampler WebGLSampler, pname GLenum, parameter int) {
	context.native.make_current()
	if !context.owns(&sampler.object) {
		context.set_error(invalid_operation)
		return
	}
	if !valid_sampler_parameter(pname) && !(pname == texture_max_anisotropy_ext && context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return
	}
	context.native.dispatch('sampler_parameteri', sampler.object.handle_, pname, parameter)
	C.vox_gl_sampler_parameteri(sampler.object.native_handle_, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) sampler_parameterf(mut sampler WebGLSampler, pname GLenum, parameter f32) {
	context.native.make_current()
	if !context.owns(&sampler.object) {
		context.set_error(invalid_operation)
		return
	}
	if !valid_sampler_parameter(pname) && !(pname == texture_max_anisotropy_ext && context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return
	}
	context.native.dispatch('sampler_parameterf', sampler.object.handle_, pname, i64(parameter))
	C.vox_gl_sampler_parameterf(sampler.object.native_handle_, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) delete_sampler(mut sampler ?&WebGLSampler) {
	context.native.make_current()
	if mut value := sampler {
		handle_result := value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.samplers.delete(handle)
		context.native.dispatch('delete_sampler', handle)
		C.vox_gl_delete_object(5, value.object.native_handle_)
	}
}

pub fn (mut context WebGLRenderingContext) fence_sync(condition GLenum, flags GLenum) ?&WebGLSync {
	if !context.require_webgl2() { return none }
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	native_handle := context.native.native_fence_sync(condition, flags)
	sync := &WebGLSync{
		object: new_object(context.identity(), context.context_generation_, handle, 0)
		native_handle_: native_handle
		source_handle_: unsafe { voidptr(uint(source_handle)) }
	}
	unsafe {
		context.syncs[handle] = sync
	}
	context.native.dispatch('fence_sync', condition, flags)
	return sync
}

pub fn (mut context WebGLRenderingContext) client_wait_sync(mut sync WebGLSync, flags GLenum, timeout u64) GLenum {
	sync.sync_handle(context.identity(), context.context_generation_) or {
		context.set_error(invalid_operation)
		return wait_failed
	}
	context.native.dispatch('client_wait_sync', sync.object.handle_, flags, i64(timeout))
	return context.native.native_client_wait_sync(sync.native_handle_, flags, timeout)
}

pub fn (mut context WebGLRenderingContext) wait_sync(mut sync WebGLSync, flags GLenum, timeout u64) {
	sync.sync_handle(context.identity(), context.context_generation_) or {
		context.set_error(invalid_operation)
		return
	}
	context.native.dispatch('wait_sync', sync.object.handle_, flags, i64(timeout))
	context.native.native_wait_sync(sync.native_handle_, flags, timeout)
}

pub fn (mut context WebGLRenderingContext) delete_sync(mut sync ?&WebGLSync) {
	if mut value := sync {
		handle_result := value.sync_handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.syncs.delete(handle)
		context.native.native_delete_sync(value.native_handle_)
		context.native.dispatch('delete_sync', handle)
	}
}

pub fn (mut context WebGLRenderingContext) create_transform_feedback() &WebGLTransformFeedback {
	context.native.make_current()
	context.require_webgl2()
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	feedback := &WebGLTransformFeedback{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle, source_handle), native_handle_: C.vox_gl_gen_object(8)}
	}
	unsafe {
		context.transform_feedbacks[handle] = feedback
	}
	return feedback
}

pub fn (mut context WebGLRenderingContext) bind_transform_feedback(target GLenum, feedback ?&WebGLTransformFeedback) {
	context.native.make_current()
    if !context.require_webgl2() { return }
    if value := feedback { if !context.owns(&value.object) { context.set_error(invalid_operation); return } }
    context.native.dispatch('bind_transform_feedback',target,if value := feedback { value.object.handle_ } else { 0 })
    C.vox_gl_bind_transform_feedback(target,if value := feedback { value.object.native_handle_ } else { 0 })
}

pub fn (mut context WebGLRenderingContext) begin_transform_feedback(primitive_mode GLenum) {
	context.native.make_current()
    if !context.require_webgl2() { return }
    context.native.dispatch('begin_transform_feedback',primitive_mode)
    C.vox_gl_begin_transform_feedback(primitive_mode)
}

pub fn (mut context WebGLRenderingContext) end_transform_feedback() {
	context.native.make_current()
    if !context.require_webgl2() { return }
    context.native.dispatch('end_transform_feedback')
    C.vox_gl_end_transform_feedback()
}

pub fn (mut context WebGLRenderingContext) pause_transform_feedback() {
	context.native.make_current()
    if !context.require_webgl2() { return }
    context.native.dispatch('pause_transform_feedback')
    C.vox_gl_pause_transform_feedback()
}

pub fn (mut context WebGLRenderingContext) resume_transform_feedback() {
	context.native.make_current()
    if !context.require_webgl2() { return }
    context.native.dispatch('resume_transform_feedback')
    C.vox_gl_resume_transform_feedback()
}

pub fn (mut context WebGLRenderingContext) create_vertex_array() &WebGLVertexArrayObject {
	context.require_webgl2()
	context.native.make_current()
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	array := &WebGLVertexArrayObject{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle, source_handle), native_handle_: C.vox_gl_gen_object(6)}
	}
	unsafe {
		context.vertex_arrays[handle] = array
	}
	return array
}

pub fn (mut context WebGLRenderingContext) bind_vertex_array(array ?&WebGLVertexArrayObject) {
	context.native.make_current()
	if !context.require_webgl2() { return }
	if value := array {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
	}
	context.native.dispatch('bind_vertex_array', if value := array { value.object.handle_ } else { 0 })
	C.vox_gl_bind_vertex_array(if value := array { value.object.native_handle_ } else { 0 },0)
	context.current_vertex_array = array
	if value := array {
		context.set_current_vertex_array_binding(&value.object)
	} else {
		context.set_current_vertex_array_binding(none)
	}
}

pub fn (mut context WebGLRenderingContext) is_vertex_array(array ?&WebGLVertexArrayObject) bool {
	context.native.make_current()
	value := array or { return false }
	context.object_handle_for_query(&value.object) or { return false }
	return C.vox_gl_is_vertex_array(value.object.native_handle_,0) == 1
}

pub fn (mut context WebGLRenderingContext) delete_vertex_array(mut array ?&WebGLVertexArrayObject) {
	context.native.make_current()
	if mut value := array {
		handle_result := value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.vertex_arrays.delete(handle)
		context.native.dispatch('delete_vertex_array', handle)
		C.vox_gl_delete_object(6,value.object.native_handle_)
		if current := context.current_vertex_array {
			if voidptr(current) == voidptr(value) {
				context.current_vertex_array = none
				context.set_current_vertex_array_binding(none)
			}
		}
	}
}

// OES_vertex_array_object mirrors the WebGL2 ownership/binding contract with
// its distinct platform object type.
pub fn (mut context WebGLRenderingContext) create_vertex_array_oes() &WebGLVertexArrayObjectOES {
	context.native.make_current()
	handle := context.allocate_handle()
	source_handle := context.allocate_object_id()
	array := &WebGLVertexArrayObjectOES{
		object: WebGLObject{...new_object(context.identity(), context.context_generation_, handle, source_handle), native_handle_: C.vox_gl_gen_object(7)}
	}
	unsafe {
		context.vertex_arrays_oes[handle] = array
	}
	return array
}

pub fn (mut context WebGLRenderingContext) bind_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) {
	context.native.make_current()
	if value := array {
		if !context.owns(&value.object) {
			return
		}
	}
	context.native.dispatch('bind_vertex_array_oes', if value := array { value.object.handle_ } else { 0 })
	C.vox_gl_bind_vertex_array(if value := array { value.object.native_handle_ } else { 0 },1)
	context.current_vertex_array_oes = array
	if value := array {
		context.set_current_vertex_array_binding(&value.object)
	} else {
		context.set_current_vertex_array_binding(none)
	}
}

pub fn (mut context WebGLRenderingContext) is_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) bool {
	context.native.make_current()
	value := array or { return false }
	// The extension currently returns false without setting an error for a
	// vertex array created by another context.
	handle_result := value.object.handle_for_query(context.identity(), context.context_generation_) or {
		return false
	}
	if !handle_result.has_value { return false }
	return C.vox_gl_is_vertex_array(value.object.native_handle_,1) == 1
}

pub fn (mut context WebGLRenderingContext) delete_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) {
	context.native.make_current()
	if value := array {
		mut mutable_value := unsafe { &WebGLVertexArrayObjectOES(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			// Upstream currently returns silently for a foreign OES VAO.
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := value.object.bookkeeping_id()
		context.vertex_arrays_oes.delete(handle)
		context.native.dispatch('delete_vertex_array_oes', handle)
		C.vox_gl_delete_object(7,value.object.native_handle_)
		if current := context.current_vertex_array_oes {
			if voidptr(current) == voidptr(value) {
				context.current_vertex_array_oes = none
				context.set_current_vertex_array_binding(none)
			}
		}
	}
}

pub fn offset_span(bytes []u8, source_offset u64, length_override u32) ![]u8 {
	if source_offset > u64(bytes.len) {
		return error('offset exceeds source')
	}
	length := if length_override == 0 {
		u64(bytes.len) - source_offset
	} else {
		u64(length_override)
	}
	if source_offset + length < source_offset || source_offset + length > u64(bytes.len) {
		return error('slice exceeds source')
	}
	return bytes[int(source_offset)..int(source_offset + length)]
}

pub fn (mut context WebGLRenderingContext) compressed_tex_image3d(target GLenum, level int, internal_format GLenum, width int, height int, depth int, border int, source []u8, source_offset u64, length_override u32) {
	context.native.make_current()
	if internal_format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	pixels := offset_span(source, source_offset, length_override) or {
		context.set_error(invalid_value)
		return
	}
	context.native.dispatch('compressed_tex_image3d', target, level, internal_format, width, height, depth, border, pixels.len)
	C.vox_gl_compressed_tex_image3d(target,level,internal_format,width,height,depth,border,pixels.len,pixels.data)
}

pub fn (mut context WebGLRenderingContext) draw_arrays_instanced(mode GLenum, first int, count int, instance_count int) {
	context.native.make_current()
	context.native.notify_painting_surface_content_will_change()
	context.native.did_update_canvas_content()
	context.native.dispatch('draw_arrays_instanced', mode, first, count, instance_count)
}

pub fn (mut context WebGLRenderingContext) draw_elements_instanced(mode GLenum, count int, type_ GLenum, offset i64, instance_count int) {
	context.native.make_current()
	context.native.notify_painting_surface_content_will_change()
	context.native.dispatch('draw_elements_instanced', mode, count, type_, offset, instance_count)
	context.native.did_update_canvas_content()
}

// Remaining WebGL2 pixel, texture, uniform matrix and reflection entry points
// use this checked dispatch after WebIDL conversion has produced native values.
pub fn (mut context WebGLRenderingContext) webgl2_command(name string, args ...i64) {
	if !context.require_webgl2() {
		return
	}
	context.native.dispatch(name, ...args)
}
