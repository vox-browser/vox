module querywire

import platform
import x.json2

fn identity_reply_oracle(key string) string {
	return json2.encode(json2.Any({
		'bridgeKey': json2.Any(key)
	}))
}

fn test_identity_reply_preserves_json_escaping_and_arbitrary_byte_strings() {
	mut keys := ['', '__element_0', '__created_2147483648', 'λ😀\u2028\u2029', '"\\/\b\f\n\r\t']
	for byte in 0 .. 256 { keys << [u8(byte)].bytestr() }
	keys << 'x'.repeat(16384) + '"😀'
	for length in [255, 256, 257, 512] {
		keys << 'x'.repeat(length)
		keys << '\n'.repeat(length)
	}
	for key in keys {
		assert encode_identity_reply(key) == identity_reply_oracle(key)
	}
}

fn test_identity_reply_matches_randomized_multibyte_and_invalid_keys() {
	mut seed := u32(0x12345678)
	for length in 0 .. 256 {
		mut bytes := []u8{cap: length}
		for _ in 0 .. length {
			seed = seed * u32(1664525) + u32(1013904223)
			bytes << u8(seed >> 24)
		}
		key := bytes.bytestr()
		assert encode_identity_reply(key) == identity_reply_oracle(key)
	}
}

fn test_identity_reply_owns_output_after_input_arena_retirement() {
	mut input := platform.new_arena('identity reply input')
	entry := input.enter()
	key := ('__element_' + 'λ"\\😀'.repeat(32)).clone()
	expected := identity_reply_oracle(key)
	input.leave(entry)
	actual := encode_identity_reply(key)
	control := expected.clone()
	input.release()
	mut churn := platform.new_arena('identity reply input overwrite')
	churn_entry := churn.enter()
	_ = []u8{len: 1024 * 1024, init: u8(0xa5)}
	churn.leave(churn_entry)
	assert actual == control
	churn.release()
}
