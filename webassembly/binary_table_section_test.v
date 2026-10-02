module webassembly

import webidl

fn table_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 4, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_table_section_retains_explicit_and_source_implicit_initializers() {
	compiled := compile_module(table_section_binary([u8(3), 0x70, 1, 1, 4, 0x40, 0, 0x64, 0x6f,
		0, 0, 0xd0, 0x6f, 0x0b, 0x64, 0, 0, 2]))!
	assert compiled.table_definitions.len == 3
	function_table := compiled.table_definitions[0]
	assert function_table.type_.limits.minimum == 1 && function_table.type_.limits.maximum? == 4
	assert function_table.initializer.instructions[0].opcode == binary_op_ref_null
	assert function_table.initializer.instructions[1].opcode == binary_op_synthetic_end_expression
	explicit_table := compiled.table_definitions[1]
	assert !explicit_table.type_.element_type.nullable
	assert explicit_table.type_.element_type.kind == .extern_reference
	assert (explicit_table.initializer.instructions[0].arguments as BinaryValueType).kind == .extern_reference
	typed_table := compiled.table_definitions[2]
	assert !typed_table.type_.element_type.nullable && typed_table.type_.element_type.type_index == 0
	implicit := typed_table.initializer.instructions[0].arguments as BinaryValueType
	assert implicit.nullable && implicit.type_index == 0
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.table_definitions == compiled.table_definitions
}

fn test_table_section_rejects_reserved_prefix_numeric_types_and_missing_expressions() {
	for payload in [[]u8{}, [u8(1), 0x40, 1, 0x70, 0, 0, 0x0b], [u8(1), 0x7f, 0, 0],
		[u8(1), 0x40, 0, 0x70, 0, 0, 0xd0, 0x70], [u8(1), 0x64, 0x80], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(table_section_binary(payload)))
	}
}
