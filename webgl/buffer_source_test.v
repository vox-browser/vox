module webgl

fn expect_middle_buffer_source_bytes(bytes []u8) ! {
	assert bytes == [u8(4), 5, 6, 7]
}

fn expect_empty_buffer_source_bytes(bytes []u8) ! {
	assert bytes.len == 0
}

fn test_with_buffer_source_bytes_applies_element_offsets_inside_the_view() {
	source := WebGLBufferSource{
		buffer: [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9]
		byte_offset: 2
		byte_length: 8
		element_size: 2
	}
	with_buffer_source_bytes(source, 1, 2, expect_middle_buffer_source_bytes)!
	span := span_from_typed_array(source, 1, 2)!
	assert span.size() == 2
	assert span.data() == [u8(4), 5, 6, 7]
}

fn test_buffer_source_rejects_detached_invalid_and_overflowing_views() {
	with_buffer_source_bytes(WebGLBufferSource{ detached: true }, 0, 0, expect_empty_buffer_source_bytes) or {
		assert err.msg().contains('detached')
	}
	with_buffer_source_bytes(WebGLBufferSource{
		buffer: [u8(1), 2]
		byte_length: 2
		element_size: 2
	}, max_u64, 0, expect_empty_buffer_source_bytes) or {
		assert err.msg().contains('overflow')
	}
	span_from_typed_array(WebGLBufferSource{
		buffer: [u8(1), 2]
		byte_offset: 2
		byte_length: 1
	}, 0, 0) or {
		assert err.msg().contains('invalid view')
	}
}

fn test_out_of_bounds_buffer_source_allows_only_an_empty_default_range() {
	source := WebGLBufferSource{ out_of_bounds: true }
	with_buffer_source_bytes(source, 0, 0, expect_empty_buffer_source_bytes)!
	with_buffer_source_bytes(source, 1, 0, expect_empty_buffer_source_bytes) or {
		assert err.msg().contains('out of bounds')
	}
}

fn test_webgl_string_helpers_preserve_utf8_and_termination() {
    assert null_terminated_string([]u8{}) == ''
    assert null_terminated_string([u8(0), 65]) == ''
    assert null_terminated_string('Леди'.bytes()) == 'Леди'
    assert null_terminated_string('Леди\x00ignored'.bytes()) == 'Леди'

	encoded := null_terminated_utf8_string('Леди')
	assert encoded.last() == 0
	assert encoded[..encoded.len - 1].bytestr() == 'Леди'
	assert utf16_string_from_gl_string(encoded, encoded.len - 1) == 'Леди'
	assert utf16_string_from_gl_string(encoded, 0) == ''
}
