module webassembly

import webidl

fn function_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 3, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_defined_function_section_retains_type_indices_and_serialization() {
	// Parsing preserves indices; validating these against the type section and
	// code-body count belongs to the still-pending LibWasm module validator.
	compiled := compile_module(function_section_binary([u8(4), 0, 0x80, 1, 0x80, 0x80, 1,
		0xff, 0xff, 0xff, 0xff, 0x0f]))!
	assert compiled.function_type_indices == [u32(0), 128, 16384, 0xffffffff]
	assert compiled.import_entries.len == 0
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.function_type_indices == compiled.function_type_indices
	assert compile_module(function_section_binary([u8(0)]))!.function_type_indices.len == 0
}

fn test_defined_function_section_rejects_missing_and_invalid_index_operands() {
	for payload in [[]u8{}, [u8(1)], [u8(2), 0], [u8(1), 0x80],
		[u8(1), 0xff, 0xff, 0xff, 0xff, 0x10], [u8(1), 0x80, 0x80, 0x80, 0x80, 0x80, 0],
		[u8(0), 0], [u8(1), 0, 0]] {
		assert !validate(webidl.BufferSource.array_buffer(function_section_binary(payload)))
	}
}
