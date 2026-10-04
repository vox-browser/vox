module webgl

// Source list-uniform bodies select their owner, then validate their nullable
// location before reading spans. Public IDL conversions have already finished.
pub fn (mut context WebGLRenderingContext) validate_uniform_upload_location(location ?&WebGLUniformLocation) bool {
	context.native.make_current()
	value := location or { return false }
	value.handle(context.current_program) or {
		context.set_error(invalid_operation)
		return false
	}
	return true
}

// WebGL2RenderingContextImpl::get_buffer_sub_data element-based destination.
pub fn (mut context WebGLRenderingContext) get_buffer_sub_data_into(target GLenum, source_offset i64, mut destination []u8, destination_offset u64, length u32, element_size u64) {
	if !context.require_webgl2() { return }
	if element_size == 0 {
		context.set_error(invalid_value)
		return
	}
	mut copy_length := u64(length)
	if length == 0 {
		elements := u64(destination.len) / element_size
		if destination_offset > elements {
			context.set_error(invalid_value)
			return
		}
		copy_length = elements - destination_offset
	}
	if copy_length == 0 { return }
	byte_offset := checked_mul_u64(destination_offset, element_size) or {
		context.set_error(invalid_value)
		return
	}
	copy_bytes := checked_mul_u64(copy_length, element_size) or {
		context.set_error(invalid_value)
		return
	}
	end := checked_add_u64(byte_offset, copy_bytes) or {
		context.set_error(invalid_value)
		return
	}
	if end > u64(destination.len) {
		context.set_error(invalid_value)
		return
	}
	context.get_buffer_sub_data(target, source_offset, mut destination, int(byte_offset), int(copy_bytes))
}
