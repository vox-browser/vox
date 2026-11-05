module querywire

import platform
import x.json2

fn document_reply_oracle(key string) string {
	return json2.encode(json2.Any({
		'bridgeKey': json2.Any(key)
		'nodeType': json2.Any(9)
		'nodeName': json2.Any('#document')
		'tagName': json2.Any('#node')
	}))
}

fn test_document_reply_preserves_exact_object_fields_and_arbitrary_key_bytes() {
	mut keys := ['', '__document_0', '__document_18446744073709551615',
		'λ😀\u2028\u2029', '"\\/\b\f\n\r\t']
	for byte in 0 .. 256 { keys << [u8(byte)].bytestr() }
	for length in [255, 256, 257, 512, 16384] {
		keys << 'x'.repeat(length)
		keys << '\n'.repeat(length)
	}
	for key in keys { assert encode_document_reply(key) == document_reply_oracle(key) }
}

fn test_document_reply_matches_random_multibyte_and_invalid_sequences() {
	mut seed := u32(0x49278163)
	for length in 0 .. 257 {
		mut bytes := []u8{cap:length}
		for _ in 0 .. length {
			seed = seed * u32(1664525) + u32(1013904223)
			bytes << u8(seed >> 24)
		}
		key := bytes.bytestr()
		assert encode_document_reply(key) == document_reply_oracle(key)
	}
}

fn test_document_reply_owns_escaped_output_after_input_retirement() {
	mut input := platform.new_arena('document reply input')
	entry := input.enter()
	key := ('__document_' + 'λ"\\😀'.repeat(24)).clone()
	expected := document_reply_oracle(key)
	input.leave(entry)
	actual := encode_document_reply(key)
	control := expected.clone()
	input.release()
	mut churn := platform.new_arena('document reply overwrite')
	churn_entry := churn.enter()
	_ = []u8{len:1024*1024, init:u8(0xa5)}
	churn.leave(churn_entry)
	assert actual == control
	churn.release()
}

fn test_root_document_reply_uses_no_current_arena_storage() {
	_ = encode_document_reply('')
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		value := encode_document_reply('')
		assert value == '{"bridgeKey":"","nodeName":"#document","nodeType":9,"tagName":"#node"}'
	}
	$if prealloc {
		if !retain_document_reply_map { assert platform.thread_arena_usage().used == before }
	}
}
