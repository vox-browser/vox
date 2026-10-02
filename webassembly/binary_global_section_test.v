module webassembly

import webidl

fn global_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 6, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_global_section_retains_mutability_reference_types_and_initializer_instructions() {
	// Retain parser coverage of a nullable initializer for a nonnull type and
	// an undeclared large global index without bypassing module validation.
	mut decoder := Decoder{
		bytes: [u8(3), 0x7f, 1, 0x41, 0x7f, 0x0b, 0x64, 0x6f, 0, 0xd0, 0x6f, 0x0b, 0x7e, 0, 0x23,
			0x80, 1, 0x0b]
	}
	globals := parse_global_section(mut decoder)!
	assert globals.len == 3 && decoder.offset == decoder.bytes.len
	i32_global := globals[0]
	assert i32_global.type_.mutable_ && i32_global.type_.type_.kind == .i32
	assert (i32_global.initializer.instructions[0].arguments as BinaryI32Constant).value == -1
	assert i32_global.initializer.instructions[1].opcode == binary_op_synthetic_end_expression
	ref_global := globals[1]
	assert !ref_global.type_.mutable_ && !ref_global.type_.type_.nullable
	assert (ref_global.initializer.instructions[0].arguments as BinaryValueType).kind == .extern_reference
	imported_global := globals[2].initializer.instructions[0]
	assert (imported_global.arguments as BinaryIndexArgument).kind == .global
	assert (imported_global.arguments as BinaryIndexArgument).index == 128
}

fn test_global_section_rejects_bad_types_mutability_and_unterminated_initializers() {
	for payload in [[]u8{}, [u8(1), 0x78, 0, 0x0b], [u8(1), 0x7f, 2, 0x0b], [u8(1), 0x7f, 0, 0x41,
		1], [u8(1), 0x7f, 0, 0x06, 0x0b], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(global_section_binary(payload)))
	}
}
