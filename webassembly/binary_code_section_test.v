module webassembly

import webidl

fn code_section_binary(payload []u8) []u8 {
	// Supply genuine module function/body counts for module validation.
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0]
	if payload.len > 0 {
		bytes << [u8(3), u8(payload[0] + 1), payload[0]]
		for _ in 0 .. payload[0] { bytes << u8(0) }
	}
	bytes << [u8(10), u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_code_section_retains_local_groups_real_bodies_and_function_boundaries() {
	// These parser fixtures leave surplus values for a void signature. Keep
	// their framing/operand coverage at the parser rather than weakening the
	// source function-result validation.
	mut decoder := Decoder{
		bytes: [u8(2), 8, 1, 2, 0x7f, 0x20, 0, 0x41, 42, 0x0b, 7, 1, 1, 0x64, 0x6f, 0xd0, 0x6f,
			0x0b]
	}
	functions := parse_code_section(mut decoder)!
	assert functions.len == 2 && decoder.offset == decoder.bytes.len
	first := functions[0]
	assert first.declared_size == 8
	assert first.locals == [BinaryLocals{ count: 2, type_: BinaryValueType{ kind: .i32 } }]
	assert first.body.instructions[0].local_index == 0
	assert (first.body.instructions[1].arguments as BinaryI32Constant).value == 42
	assert first.body.instructions.last().opcode == binary_op_synthetic_end_expression
	second := functions[1]
	assert !second.locals[0].type_.nullable && second.locals[0].type_.kind == .extern_reference
}

fn test_code_section_local_count_limit_and_malformed_body_framing() {
	// 50000 = d0 86 03; the limit counts all local groups and parameters.
	compiled := compile_module(code_section_binary([u8(1), 6, 1, 0xd0, 0x86, 3, 0x7f, 0x0b]))!
	assert compiled.function_bodies[0].locals[0].count == 50000
	for payload in [[]u8{}, [u8(1)], [u8(1), 0], [u8(1), 2, 0, 0x41], [u8(1), 2, 0, 0x0b, 0],
		[u8(1), 3, 0, 0x0b, 0x0b], [u8(1), 6, 1, 0xd1, 0x86, 3, 0x7f, 0x0b],
		[u8(1), 10, 2, 0xa8, 0xc3, 1, 0x7f, 0xa9, 0xc3, 1, 0x7f, 0x0b],
		[u8(1), 4, 1, 1, 0x78, 0x0b]] {
		assert !validate(webidl.BufferSource.array_buffer(code_section_binary(payload)))
	}
}
