module adblock

import platform

fn test_filter_json_encoding_owns_unicode_and_nested_payload_after_workspace_reuse() {
	input := ['https://filter.test/中😀?a="b"', 'line\n\tend', 'backslash\\value']
	encoded := encode_transport_json(input)
	for _ in 0 .. 32 { _ = encode_transport_json(Request{url:'https://other.test/',source_url:'https://owner.test/'}) }
	assert decode_transport_json[[]string](encoded)! == input
	assert encoded.to_lower().contains('\\u4e2d') && encoded.to_lower().contains('\\ud83d\\ude00')
	assert encoded.contains('\\n') && encoded.contains('\\t')
}

fn test_filter_json_encoding_keeps_only_the_final_serialized_string() {
	input := ['text"\\\n中😀'.repeat(4096)]
	mut storage := platform.new_arena('filter JSON output')
	entry := storage.enter()
	before := storage.usage().used
	encoded := encode_transport_json(input)
	growth := storage.usage().used - before
	storage.leave(entry)
	$if prealloc { assert growth <= encoded.len + 512, '${growth} bytes for ${encoded.len} serialized bytes' }
	assert decode_transport_json[[]string](encoded)! == input
	storage.release()
}
