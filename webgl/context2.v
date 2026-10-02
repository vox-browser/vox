// Copyright (c) 2026, Ladybird contributors
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
	if !context.require_webgl2() {
		return
	}
	if read_offset < 0 || write_offset < 0 || size < 0 {
		context.set_error(invalid_value)
		return
	}
	read_handle := context.bound_buffers[read_target] or {
		context.set_error(invalid_operation)
		return
	}
	write_handle := context.bound_buffers[write_target] or {
		context.set_error(invalid_operation)
		return
	}
	read_buffer := context.buffers[read_handle] or {
		context.set_error(invalid_operation)
		return
	}
	write_buffer := context.buffers[write_handle] or {
		context.set_error(invalid_operation)
		return
	}
	mut mutable_write_buffer := unsafe { &WebGLBuffer(write_buffer) }
	if read_offset + size > read_buffer.data_.len || write_offset + size > mutable_write_buffer.data_.len {
		context.set_error(invalid_value)
		return
	}
	read_start := int(read_offset)
	write_start := int(write_offset)
	count := int(size)
	if read_handle == write_handle && write_start > read_start && write_start < read_start + count {
		for index := count - 1; index >= 0; index-- {
			mutable_write_buffer.data_[write_start + index] = read_buffer.data_[read_start + index]
		}
	} else {
		copy(mut mutable_write_buffer.data_[write_start..write_start + count], read_buffer.data_[read_start..read_start + count])
	}
	context.native.dispatch('copy_buffer_sub_data', read_target, write_target, read_offset, write_offset, size)
}

pub fn (mut context WebGLRenderingContext) get_buffer_sub_data(target GLenum, source_offset i64, mut destination []u8, destination_offset int, length int) {
	if !context.require_webgl2() {
		return
	}
	if source_offset < 0 || destination_offset < 0 || length < 0 {
		context.set_error(invalid_value)
		return
	}
	handle := context.bound_buffers[target] or {
		context.set_error(invalid_operation)
		return
	}
	buffer := context.buffers[handle] or {
		context.set_error(invalid_operation)
		return
	}
	copy_length := if length == 0 { destination.len - destination_offset } else { length }
	if destination_offset + copy_length > destination.len || source_offset + copy_length > buffer.data_.len {
		context.set_error(invalid_value)
		return
	}
	copy(mut destination[destination_offset..destination_offset + copy_length], buffer.data_[int(source_offset)..int(source_offset) + copy_length])
	context.native.dispatch('get_buffer_sub_data', target, source_offset, destination_offset, copy_length)
}

pub fn (mut context WebGLRenderingContext) create_query() &WebGLQuery {
	context.require_webgl2()
	handle := context.allocate_handle()
	query := &WebGLQuery{
		object: new_object(context.identity(), context.context_generation_, handle)
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
	if !context.require_webgl2() {
		return
	}
	if !valid_query_target(target) {
		context.set_error(invalid_enum)
		return
	}
	if !context.owns(&query.object) || target in context.current_queries || query.active_ {
		context.set_error(invalid_operation)
		return
	}
	if existing_target := query.target_ {
		if existing_target != target {
			context.set_error(invalid_operation)
			return
		}
	}
	query.target_ = target
	query.active_ = true
	query.available_ = false
	unsafe {
		context.current_queries[target] = query
	}
	context.native.dispatch('begin_query', target, query.object.handle_)
}

pub fn (mut context WebGLRenderingContext) end_query(target GLenum) {
	if !context.require_webgl2() {
		return
	}
	if !valid_query_target(target) {
		context.set_error(invalid_enum)
		return
	}
	mut query := context.current_queries[target] or {
		context.set_error(invalid_operation)
		return
	}
	query.active_ = false
	query.available_ = true
	context.current_queries.delete(target)
	context.native.dispatch('end_query', target)
}

pub fn (mut context WebGLRenderingContext) get_query(target GLenum, pname GLenum) ?&WebGLQuery {
	if pname != current_query || !valid_query_target(target) {
		context.set_error(invalid_enum)
		return none
	}
	return context.current_queries[target] or { none }
}

pub fn (mut context WebGLRenderingContext) get_query_parameter(query &WebGLQuery, pname GLenum) ?u64 {
	if !context.owns(&query.object) {
		context.set_error(invalid_operation)
		return none
	}
	return match pname {
		query_result {
			query.result_
		}
		query_result_available {
			if query.available_ {
				u64(1)
			} else {
				u64(0)
			}
		}
		else {
			context.set_error(invalid_enum)
			none
		}
	}
}

pub fn (mut context WebGLRenderingContext) delete_query(mut query ?&WebGLQuery) {
	if mut value := query {
		handle_result := value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.queries.delete(handle)
		context.native.dispatch('delete_query', handle)
	}
}

pub fn (mut context WebGLRenderingContext) create_sampler() &WebGLSampler {
	context.require_webgl2()
	handle := context.allocate_handle()
	sampler := &WebGLSampler{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.samplers[handle] = sampler
	}
	return sampler
}

pub fn (mut context WebGLRenderingContext) bind_sampler(unit GLuint, sampler ?&WebGLSampler) {
	if value := sampler {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		context.bound_samplers[unit] = value.object.handle_
	} else {
		context.bound_samplers.delete(unit)
	}
	context.native.dispatch('bind_sampler', unit, if value := sampler {
		value.object.handle_
	} else {
		0
	})
}

fn valid_sampler_parameter(pname GLenum) bool {
	return pname in [texture_compare_func, texture_compare_mode, texture_mag_filter, texture_max_lod,
		texture_min_filter, texture_min_lod, texture_wrap_r, texture_wrap_s, texture_wrap_t]
}

pub fn (mut context WebGLRenderingContext) sampler_parameteri(mut sampler WebGLSampler, pname GLenum, parameter int) {
	if !context.owns(&sampler.object) {
		context.set_error(invalid_operation)
		return
	}
	if !valid_sampler_parameter(pname) && !(pname == texture_max_anisotropy_ext && context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return
	}
	sampler.integer_parameters[pname] = parameter
	context.native.dispatch('sampler_parameteri', sampler.object.handle_, pname, parameter)
}

pub fn (mut context WebGLRenderingContext) sampler_parameterf(mut sampler WebGLSampler, pname GLenum, parameter f32) {
	if !context.owns(&sampler.object) {
		context.set_error(invalid_operation)
		return
	}
	if !valid_sampler_parameter(pname) && !(pname == texture_max_anisotropy_ext && context.extension_enabled('EXT_texture_filter_anisotropic')) {
		context.set_error(invalid_enum)
		return
	}
	sampler.float_parameters[pname] = parameter
	context.native.dispatch('sampler_parameterf', sampler.object.handle_, pname, i64(parameter))
}

pub fn (mut context WebGLRenderingContext) delete_sampler(mut sampler ?&WebGLSampler) {
	if mut value := sampler {
		handle_result := value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.samplers.delete(handle)
		for unit, bound in context.bound_samplers {
			if bound == handle { context.bound_samplers.delete(unit) }
		}
		context.native.dispatch('delete_sampler', handle)
	}
}

pub fn (mut context WebGLRenderingContext) fence_sync(condition GLenum, flags GLenum) ?&WebGLSync {
	if !context.require_webgl2() { return none }
	native_handle := context.native.native_fence_sync(condition, flags)
	if native_handle == unsafe { nil } { return none }
	handle := context.allocate_handle()
	sync := &WebGLSync{
		object: new_object(context.identity(), context.context_generation_, handle)
		native_handle_: native_handle
	}
	unsafe {
		context.syncs[handle] = sync
	}
	context.native.dispatch('fence_sync', condition, flags)
	return sync
}

pub fn (mut context WebGLRenderingContext) client_wait_sync(mut sync WebGLSync, flags GLenum, timeout u64) GLenum {
	if !context.owns(&sync.object) {
		context.set_error(invalid_operation)
		return wait_failed
	}
	context.native.dispatch('client_wait_sync', sync.object.handle_, flags, i64(timeout))
	return context.native.native_client_wait_sync(sync.native_handle_, flags, timeout)
}

pub fn (mut context WebGLRenderingContext) wait_sync(mut sync WebGLSync, flags GLenum, timeout u64) {
	if !context.owns(&sync.object) {
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
		handle := handle_result.value
		context.syncs.delete(handle)
		context.native.native_delete_sync(value.native_handle_)
		value.native_handle_ = unsafe { nil }
		context.native.dispatch('delete_sync', handle)
	}
}

pub fn (mut context WebGLRenderingContext) create_transform_feedback() &WebGLTransformFeedback {
	handle := context.allocate_handle()
	feedback := &WebGLTransformFeedback{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.transform_feedbacks[handle] = feedback
	}
	return feedback
}

pub fn (mut context WebGLRenderingContext) bind_transform_feedback(target GLenum, feedback ?&WebGLTransformFeedback) {
	if target != transform_feedback {
		context.set_error(invalid_enum)
		return
	}
	if value := feedback {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
		if current := context.current_transform_feedback {
			if current.active_ && !current.paused_ && current != value {
				context.set_error(invalid_operation)
				return
			}
		}
	}
	context.current_transform_feedback = feedback
	context.native.dispatch('bind_transform_feedback', target, if value := feedback {
		value.object.handle_
	} else {
		0
	})
}

pub fn (mut context WebGLRenderingContext) begin_transform_feedback(primitive_mode GLenum) {
	mut feedback := context.current_transform_feedback or {
		context.set_error(invalid_operation)
		return
	}

	if feedback.active_ {
		context.set_error(invalid_operation)
		return
	}
	feedback.active_ = true
	feedback.paused_ = false
	context.native.dispatch('begin_transform_feedback', primitive_mode)
}

pub fn (mut context WebGLRenderingContext) end_transform_feedback() {
	mut feedback := context.current_transform_feedback or {
		context.set_error(invalid_operation)
		return
	}

	if !feedback.active_ {
		context.set_error(invalid_operation)
		return
	}
	feedback.active_ = false
	feedback.paused_ = false
	context.native.dispatch('end_transform_feedback')
}

pub fn (mut context WebGLRenderingContext) pause_transform_feedback() {
	mut feedback := context.current_transform_feedback or {
		context.set_error(invalid_operation)
		return
	}

	if !feedback.active_ || feedback.paused_ {
		context.set_error(invalid_operation)
		return
	}
	feedback.paused_ = true
	context.native.dispatch('pause_transform_feedback')
}

pub fn (mut context WebGLRenderingContext) resume_transform_feedback() {
	mut feedback := context.current_transform_feedback or {
		context.set_error(invalid_operation)
		return
	}

	if !feedback.active_ || !feedback.paused_ {
		context.set_error(invalid_operation)
		return
	}
	feedback.paused_ = false
	context.native.dispatch('resume_transform_feedback')
}

pub fn (mut context WebGLRenderingContext) create_vertex_array() &WebGLVertexArrayObject {
	handle := context.allocate_handle()
	array := &WebGLVertexArrayObject{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.vertex_arrays[handle] = array
	}
	return array
}

pub fn (mut context WebGLRenderingContext) bind_vertex_array(array ?&WebGLVertexArrayObject) {
	if value := array {
		if !context.owns(&value.object) {
			context.set_error(invalid_operation)
			return
		}
	}
	context.current_vertex_array = array
	if value := array {
		context.set_current_vertex_array_binding(&value.object)
	} else {
		context.set_current_vertex_array_binding(none)
	}
	context.native.dispatch('bind_vertex_array', if value := array {
		value.object.handle_
	} else {
		0
	})
}

pub fn (mut context WebGLRenderingContext) is_vertex_array(array ?&WebGLVertexArrayObject) bool {
	value := array or { return false }
	handle := context.object_handle_for_query(&value.object) or { return false }
	return handle in context.vertex_arrays
}

pub fn (mut context WebGLRenderingContext) delete_vertex_array(mut array ?&WebGLVertexArrayObject) {
	if mut value := array {
		handle_result := value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			context.set_error(invalid_operation)
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.vertex_arrays.delete(handle)
		if current := context.current_vertex_array {
			if current == value {
				context.current_vertex_array = none
				context.set_current_vertex_array_binding(none)
			}
		}
		context.native.dispatch('delete_vertex_array', handle)
	}
}

// OES_vertex_array_object mirrors the WebGL2 ownership/binding contract with
// its distinct platform object type.
pub fn (mut context WebGLRenderingContext) create_vertex_array_oes() &WebGLVertexArrayObjectOES {
	handle := context.allocate_handle()
	array := &WebGLVertexArrayObjectOES{
		object: new_object(context.identity(), context.context_generation_, handle)
	}
	unsafe {
		context.vertex_arrays_oes[handle] = array
	}
	return array
}

pub fn (mut context WebGLRenderingContext) bind_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) {
	if value := array {
		if !context.owns(&value.object) {
			return
		}
	}
	context.current_vertex_array_oes = array
	if value := array {
		context.set_current_vertex_array_binding(&value.object)
	} else {
		context.set_current_vertex_array_binding(none)
	}
	context.native.dispatch('bind_vertex_array_oes', if value := array {
		value.object.handle_
	} else {
		0
	})
}

pub fn (mut context WebGLRenderingContext) is_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) bool {
	value := array or { return false }
	// The extension currently returns false without setting an error for a
	// vertex array created by another context.
	handle_result := value.object.handle_for_query(context.identity(), context.context_generation_) or {
		return false
	}
	return handle_result.has_value && handle_result.value in context.vertex_arrays_oes
}

pub fn (mut context WebGLRenderingContext) delete_vertex_array_oes(array ?&WebGLVertexArrayObjectOES) {
	if value := array {
		mut mutable_value := unsafe { &WebGLVertexArrayObjectOES(value) }
		handle_result := mutable_value.object.handle_for_deletion(context.identity(), context.context_generation_) or {
			// Upstream currently returns silently for a foreign OES VAO.
			return
		}
		if !handle_result.has_value {
			return
		}
		handle := handle_result.value
		context.vertex_arrays_oes.delete(handle)
		if current := context.current_vertex_array_oes {
			if current == value {
				context.current_vertex_array_oes = none
				context.set_current_vertex_array_binding(none)
			}
		}
		context.native.dispatch('delete_vertex_array_oes', handle)
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
	if internal_format !in context.enabled_compressed_texture_formats_ {
		context.set_error(invalid_enum)
		return
	}
	pixels := offset_span(source, source_offset, length_override) or {
		context.set_error(invalid_value)
		return
	}
	context.native.dispatch('compressed_tex_image3d', target, level, internal_format, width, height, depth, border, pixels.len)
}

pub fn (mut context WebGLRenderingContext) draw_arrays_instanced(mode GLenum, first int, count int, instance_count int) {
	if first < 0 || count < 0 || instance_count < 0 {
		context.set_error(invalid_value)
		return
	}
	context.native.dispatch('draw_arrays_instanced', mode, first, count, instance_count)
}

pub fn (mut context WebGLRenderingContext) draw_elements_instanced(mode GLenum, count int, type_ GLenum, offset i64, instance_count int) {
	if count < 0 || offset < 0 || instance_count < 0 {
		context.set_error(invalid_value)
		return
	}
	context.native.dispatch('draw_elements_instanced', mode, count, type_, offset, instance_count)
}

// Remaining WebGL2 pixel, texture, uniform matrix and reflection entry points
// use this checked dispatch after WebIDL conversion has produced native values.
pub fn (mut context WebGLRenderingContext) webgl2_command(name string, args ...i64) {
	if !context.require_webgl2() {
		return
	}
	context.native.dispatch(name, ...args)
}
