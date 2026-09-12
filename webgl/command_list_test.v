module webgl

import encoding.binary

fn test_command_list_aligns_payload_and_inline_data() {
	assert WebGLCommandList.first_inline_data_offset(3) == 16
	assert WebGLCommandList.next_inline_data_offset(WebGLDataSpan{
		offset: 16
		size: 3
	}) == 32
	assert WebGLCommandList.padded_record_size([u8(1), 2, 3], [u8(9), 8])! == 32

	mut list := WebGLCommandList{}
	list.append_bytes(7, [u8(1), 2, 3], [u8(9), 8])!
	assert list.size_in_bytes() == 32
	bytes := list.bytes()
	assert bytes[0] == 7
	assert binary.little_endian_u32_at(bytes, 4) == 24
	assert bytes[8..11] == [u8(1), 2, 3]
	assert bytes[11..24] == []u8{len: 13}
	assert bytes[24..26] == [u8(9), 8]
	assert bytes[26..] == []u8{len: 6}

	list.append_bytes(8, [u8(4)], []u8{})!
	records := WebGLCommandList.for_each_command(list.buffer())!
	assert records.map(it.type_) == [WebGLCommandType(7), 8]
	assert records[0].payload.len == 24
	assert records[1].payload.len == 8
	list.clear_with_capacity()
	assert list.is_empty()
}

fn test_command_list_rejects_malformed_records() {
	WebGLCommandList.for_each_command([]u8{len: 7}) or {
		assert err.msg() == 'Truncated WebGL command header'
	}
	mut invalid_type := []u8{len: 16}
	invalid_type[0] = u8(webgl_command_type_count)
	WebGLCommandList.for_each_command(invalid_type) or {
		assert err.msg() == 'Invalid WebGL command type'
	}
	mut truncated := []u8{len: 16}
	copy(mut truncated[4..8], binary.little_endian_get_u32(16))
	WebGLCommandList.for_each_command(truncated) or {
		assert err.msg() == 'Truncated WebGL command payload'
	}
}

fn test_command_list_resolves_inline_data_spans() {
	payload := [u8(0), 0, 0, 0, 10, 20, 30, 0]
	span := WebGLDataSpan{ offset: 4, size: 4 }
	assert WebGLCommandList.resolve_data_span(payload, span)! == [u8(10), 20, 30, 0]
	assert WebGLCommandList.resolve_typed_span(payload, span, 2, 2)! == [u8(10), 20, 30, 0]
	assert WebGLCommandList.resolve_string_span(payload, span)! == [u8(10), 20, 30, 0]
	mut destination := []u8{len: 6}
	WebGLCommandList.copy_data_span(payload, span, mut destination)!
	assert destination == [u8(10), 20, 30, 0, 0, 0]
	WebGLCommandList.resolve_data_span(payload, WebGLDataSpan{ offset: 7, size: 2 }) or {
		assert err.msg().contains('outside')
	}
	WebGLCommandList.resolve_string_span(payload, WebGLDataSpan{ offset: 4, size: 3 }) or {
		assert err.msg().contains('NUL')
	}
}

fn test_sync_call_request_and_reply_encoding() {
	request := WebGLSyncCall.encode_request_bytes(3, [u8(1), 2, 3, 4], [u8(9), 0])!
	assert request.len == 40
	assert binary.little_endian_u32_at(request, 4) == 32
	assert request[8..12] == [u8(1), 2, 3, 4]
	assert request[24..26] == [u8(9), 0]
	decoded := WebGLSyncCall.dispatch_request(request)!
	assert decoded.type_ == 3
	assert decoded.payload.len == 32

	reply := WebGLSyncCall.encode_reply_bytes([u8(1), 2], [u8(3)], [u8(4), 5])!
	assert reply.len == 48
	assert reply[..2] == [u8(1), 2]
	assert reply[16] == 3
	assert reply[32..34] == [u8(4), 5]
	assert WebGLSyncCall.decode_reply(reply, 2)! == [u8(1), 2]

	WebGLSyncCall.dispatch_request([]u8{len: 7}) or {
		assert err.msg() == 'Truncated WebGL sync call header'
	}
	WebGLSyncCall.encode_reply_bytes([u8(1)], []u8{}, [u8(2)]) or {
		assert err.msg().contains('requires a first span')
	}
}
