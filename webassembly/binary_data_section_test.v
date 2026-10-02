module webassembly

import webidl

fn data_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 11, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_data_section_retains_all_modes_actual_offsets_and_owned_initializers() {
	mut bytes := data_section_binary([u8(3), 0, 0x41, 2, 0x0b, 3, 1, 2, 3, 1, 2, 0, 0xff, 2, 7,
		0x42, 0x7f, 0x0b, 1, 9])
	compiled := compile_module(bytes)!
	assert compiled.data_segments.len == 3
	implicit := compiled.data_segments[0]
	assert implicit.mode == .active && implicit.memory_index? == 0
	assert implicit.init == [u8(1), 2, 3]
	implicit_offset := implicit.offset?
	assert (implicit_offset.instructions[0].arguments as BinaryI32Constant).value == 2
	passive := compiled.data_segments[1]
	assert passive.mode == .passive && passive.memory_index == none && passive.offset == none
	assert passive.init == [u8(0), 0xff]
	explicit := compiled.data_segments[2]
	assert explicit.mode == .active && explicit.memory_index? == 7 && explicit.init == [u8(9)]
	explicit_offset := explicit.offset?
	assert (explicit_offset.instructions[0].arguments as BinaryI64Constant).value == -1
	bytes[bytes.len - 1] = 99
	assert compiled.data_segments[2].init == [u8(9)]
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.data_segments == compiled.data_segments
}

fn test_data_section_rejects_invalid_modes_missing_bytes_and_unterminated_offsets() {
	for payload in [[]u8{}, [u8(1), 3], [u8(1), 1, 2, 0], [u8(1), 2, 0x80], [u8(1), 0, 0x41, 1],
		[u8(1), 0, 0x06, 0x0b, 0], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(data_section_binary(payload)))
	}
}
