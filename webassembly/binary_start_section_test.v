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
		mut decoder := Decoder{ bytes: payload }
		assert decoder.u32_leb()! == [u32(0), 128, 0xffffffff][index]
	}
	// Serialization retains a valid start index into a real imported function.
	compiled := compile_module([u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, 5,
		1, 0, 0, 0, 0, 8, 1, 0])!
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert compiled.start_function_index? == 0
	assert restored.start_function_index == compiled.start_function_index
}

fn test_start_section_rejects_missing_overlong_and_extra_operands() {
	for payload in [[]u8{}, [u8(0x80)], [u8(0xff), 0xff, 0xff, 0xff, 0x10],
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(start_section_binary(payload)))
	}
}
