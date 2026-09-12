module webgl

import encoding.binary

fn test_pack_strings_nul_terminates_each_value() {
	assert pack_strings(['position', 'normal']) == 'position\x00normal\x00'.bytes()
	assert pack_strings([]string{}).len == 0
}

fn test_context_proxy_records_shader_source_as_nul_terminated_inline_data() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 256)!
	proxy.shader_source(7, 'void main() {}')!
	proxy.flush_commands()
	record := WebGLCommandList.for_each_command(proxy.transmitted_batches()[0].bytes)!.first()
	assert record.type_ == webgl_command_shader_source
	assert binary.little_endian_u32_at(record.payload, 0) == 7
	span := WebGLDataSpan{
		offset: binary.little_endian_u32_at(record.payload, 4)
		size: binary.little_endian_u32_at(record.payload, 8)
	}
	assert WebGLCommandList.resolve_string_span(record.payload, span)! == 'void main() {}\x00'.bytes()
}

fn test_context_proxy_packs_transform_feedback_varyings() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 256)!
	proxy.transform_feedback_varyings(9, ['value', 'color'], 0x8c8d)!
	proxy.flush_commands()
	record := WebGLCommandList.for_each_command(proxy.transmitted_batches()[0].bytes)!.first()
	assert record.type_ == webgl_command_transform_feedback_varyings
	assert binary.little_endian_u32_at(record.payload, 0) == 9
	assert binary.little_endian_u32_at(record.payload, 4) == 2
	span := WebGLDataSpan{
		offset: binary.little_endian_u32_at(record.payload, 8)
		size: binary.little_endian_u32_at(record.payload, 12)
	}
	assert WebGLCommandList.resolve_data_span(record.payload, span)! == 'value\x00color\x00'.bytes()
	assert binary.little_endian_u32_at(record.payload, 16) == 0x8c8d
}
