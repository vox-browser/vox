module webgl

import encoding.binary

fn span_reply(data []u8) ![]u8 {
	mut span := []u8{}
	span << binary.little_endian_get_u32(WebGLCommandList.first_inline_data_offset(8))
	span << binary.little_endian_get_u32(u32(data.len))
	return WebGLSyncCall.encode_reply_bytes(span, data, []u8{})
}

fn test_context_proxy_caches_remote_gl_strings() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 128)!
	proxy.set_next_sync_reply(span_reply('ANGLE renderer\x00'.bytes())!)
	assert proxy.get_string(0x1f01) == 'ANGLE renderer'
	assert proxy.sync_requests().len == 1
	request := WebGLSyncCall.dispatch_request(proxy.sync_requests()[0])!
	assert request.type_ == webgl_sync_get_string
	assert binary.little_endian_u32_at(request.payload, 0) == 0x1f01

	assert proxy.get_string(0x1f01) == 'ANGLE renderer'
	assert proxy.sync_requests().len == 1
}

fn test_context_proxy_decodes_vertex_pointer_and_uniform_indices() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 256)!
	proxy.set_next_sync_reply(binary.little_endian_get_u64(u64(0x1234)))
	pointer := proxy.get_vertex_attrib_pointerv_robust_angle(3, 0x8645, 8)
	assert pointer.length == 1
	assert pointer.pointer == 0x1234
	assert WebGLSyncCall.dispatch_request(proxy.sync_requests().last())!.type_ == webgl_sync_get_vertex_attrib_pointer

	mut indices := []u8{}
	indices << binary.little_endian_get_u32(7)
	indices << binary.little_endian_get_u32(11)
	proxy.set_next_sync_reply(span_reply(indices)!)
	assert proxy.get_uniform_indices(5, ['first', 'second']) == [GLuint(7), 11]
	request := WebGLSyncCall.dispatch_request(proxy.sync_requests().last())!
	assert request.type_ == webgl_sync_get_uniform_indices
	span := WebGLDataSpan{
		offset: binary.little_endian_u32_at(request.payload, 8)
		size: binary.little_endian_u32_at(request.payload, 12)
	}
	assert WebGLCommandList.resolve_data_span(request.payload, span)! == 'first\x00second\x00'.bytes()
}

fn test_context_proxy_rejects_malformed_sync_replies_and_mapping_calls() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 128)!
	proxy.set_next_sync_reply([u8(1), 2, 3])
	assert proxy.get_string(0x1f00) == ''
	assert proxy.is_lost()

	if _ := proxy.map_buffer_range(0x8892, 0, 4, 0) {
		assert false, 'Proxy buffer mapping must fail'
	} else {
		assert err.msg().contains('unreachable')
	}
	if _ := proxy.unmap_buffer(0x8892) {
		assert false, 'Unmapping a proxy buffer must fail'
	} else {
		assert err.msg().contains('never mapped')
	}
}

fn test_context_proxy_restore_clears_string_cache() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 128)!
	proxy.set_next_sync_reply(span_reply('before\x00'.bytes())!)
	assert proxy.get_string(0x1f00) == 'before'
	proxy.restore([]string{}, 128)!
	proxy.set_next_sync_reply(span_reply('after\x00'.bytes())!)
	assert proxy.get_string(0x1f00) == 'after'
}
