module webgl

fn test_buffer_source_span_preserves_element_offsets_lengths_and_bounds() {
	source := WebGLBufferSource{ buffer: [u8(1), 2, 3, 4, 5, 6, 7, 8], byte_length: 8, element_size: 2 }
	assert buffer_source_bytes(source, 1, 2)! == [u8(3), 4, 5, 6]
	assert buffer_source_bytes(source, 3, 0)! == [u8(7), 8]
	assert buffer_source_bytes(source, 4, 0)!.len == 0
	for offset in [u64(5), max_u64] {
		if _ := buffer_source_bytes(source, offset, 0) {
			assert false
		}
	}
	if _ := buffer_source_bytes(source, 3, 2) {
		assert false
	}
	if _ := buffer_source_bytes(WebGLBufferSource{ buffer: [u8(1)], byte_length: 1, element_size: max_int }, 0, 2) {
		assert false
	}
}

fn test_buffer_source_span_uses_source_detachment_and_resized_view_rules() {
	if _ := buffer_source_bytes(WebGLBufferSource{ detached: true }, 0, 0) {
		assert false
	}
	out := WebGLBufferSource{ out_of_bounds: true }
	assert buffer_source_bytes(out, 0, 0)!.len == 0
	if _ := buffer_source_bytes(out, 1, 0) {
		assert false
	}
	if _ := buffer_source_bytes(out, 0, 1) {
		assert false
	}
}

fn test_native_buffer_readback_uses_typed_element_offsets_without_integer_wrap() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	buffer := context.create_buffer()
	context.bind_buffer(array_buffer, buffer)
	context.buffer_data(array_buffer, [u8(1), 2, 3, 4, 5, 6, 7, 8], GLenum(0x88e4))
	mut output := []u8{len: 8, init: 99}
	context.get_buffer_sub_data_into(array_buffer, 2, mut output, 1, 2, 2)
	assert output == [u8(99), 99, 3, 4, 5, 6, 99, 99]
	assert context.get_error() == no_error
	context.get_buffer_sub_data_into(array_buffer, 0, mut output, max_u64, 1, 2)
	assert context.get_error() == invalid_value
	context.get_buffer_sub_data_into(array_buffer, 0, mut output, 3, 2, 2)
	assert context.get_error() == invalid_value
	context.get_buffer_sub_data_into(GLenum(0xbad), -1, mut output, 4, 0, 2)
	assert context.get_error() == no_error
}

fn test_typed_list_span_accepts_detached_default_range_but_not_byte_access() {
	detached := WebGLBufferSource{ detached: true, element_size: 4 }
	assert span_from_typed_array(detached, 0, 0)!.size() == 0
	if _ := span_from_typed_array(detached, 1, 0) {
		assert false
	}
	if _ := span_from_typed_array(detached, 0, 1) {
		assert false
	}
	if _ := buffer_source_bytes(detached, 0, 0) {
		assert false
	}
}
