module libjs

import platform

fn test_native_key_encoding_preserves_word_order_endianness_and_existing_prefix() {
	defer { set_native_key_encoding_for_testing(true) }
	mut results := [][]u8{}
	for enabled in [false, true] {
		set_native_key_encoding_for_testing(enabled)
		mut bytes := [u8(0xa5), 0x5a]
		for value in [u32(0), 1, 255, 256, 0x12345678, 0xffffffff] {
			native_key_u32(mut bytes, value)
		}
		results << bytes
	}
	assert results[0] == results[1]
	assert results[1] == [u8(0xa5), 0x5a, 0, 0, 0, 0, 1, 0, 0, 0, 255, 0, 0, 0,
		0, 1, 0, 0, 0x78, 0x56, 0x34, 0x12, 255, 255, 255, 255]
}

fn test_in_place_native_key_encoding_does_not_allocate_a_word_array() {
	defer { set_native_key_encoding_for_testing(true) }
	set_native_key_encoding_for_testing(true)
	mut bytes := []u8{cap: 40000}
	before := platform.thread_arena_usage().used
	for value in 0 .. 10000 { native_key_u32(mut bytes, u32(value)) }
	assert bytes.len == 40000
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert bytes[39996..] == [u8(15), 39, 0, 0]
}
