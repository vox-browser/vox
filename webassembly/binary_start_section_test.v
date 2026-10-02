module webassembly

import webidl

fn start_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 8, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_start_section_preserves_zero_index_and_absent_start_distinction() {
	absent := compile_module([u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0])!
	assert absent.start_function_index == none
	for index, payload in [[u8(0)], [u8(0x80), 1], [u8(0xff), 0xff, 0xff, 0xff, 0x0f]] {
		compiled := compile_module(start_section_binary(payload))!
		assert compiled.start_function_index? == [u32(0), 128, 0xffffffff][index]
		mut restored := Module.create_for_serialization()
		restored.deserialization_steps(compiled.serialization_steps(false)!)!
		assert restored.start_function_index == compiled.start_function_index
	}
}

fn test_start_section_rejects_missing_overlong_and_extra_operands() {
	for payload in [[]u8{}, [u8(0x80)], [u8(0xff), 0xff, 0xff, 0xff, 0x10],
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(start_section_binary(payload)))
	}
}
