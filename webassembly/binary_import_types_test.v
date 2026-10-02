module webassembly

import webidl

fn binary_import_module(kind u8, descriptor []u8) []u8 {
	mut payload := [u8(1), 3, `e`, `n`, `v`, 1, `x`, kind]
	payload << descriptor
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_import_table_and_global_types_retain_reference_operands_and_limits() {
	for element in [[u8(0x70)], [u8(0x63), 0], [u8(0x64), 0x6f]] {
		mut descriptor := element.clone()
		descriptor << [u8(1), 1, 3]
		compiled := compile_module(binary_import_module(1, descriptor))!
		table := compiled.import_entries[0].table_type or { panic('table type') }
		assert table.element_type.is_reference()
		assert table.limits.minimum == 1 && table.limits.maximum? == 3
		assert table.element_type.nullable == (element[0] != 0x64)
		if element.len == 2 && element[1] == 0 {
			assert table.element_type.kind == .type_use_reference
			assert table.element_type.type_index == 0
		}
	}
	for value in [[u8(0x7f)], [u8(0x7b)], [u8(0x63), 0], [u8(0x64), 0x6f]] {
		for mutability in [u8(0), 1] {
			mut descriptor := value.clone()
			descriptor << mutability
			compiled := compile_module(binary_import_module(3, descriptor))!
			global := compiled.import_entries[0].global_type or { panic('global type') }
			assert global.mutable_ == (mutability == 1)
			assert global.type_.nullable == (value[0] != 0x64)
			if value[0] == 0x7b {
				assert global.type_.kind == .v128
			}
		}
	}
	compiled := compile_module(binary_import_module(0, [u8(0)]))!
	assert compiled.import_entries[0].function_type_index == 0
	assert compiled.import_entries[0].table_type == none
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.import_entries == compiled.import_entries
}

fn test_import_type_parser_rejects_invalid_types_and_consumes_reference_immediates() {
	for descriptor in [[u8(0x7f), 0, 1], [u8(0x7b), 0, 1], [u8(0x78), 0, 1], [u8(0x65), 0, 1],
		[u8(0x63)], [u8(0x63), 0x7f, 0, 1], [u8(0x70), 1, 2, 1]] {
		assert !validate(webidl.BufferSource.array_buffer(binary_import_module(1, descriptor)))
	}
	for descriptor in [[u8(0xff), 0], [u8(0x78), 0], [u8(0x7f), 2], [u8(0x63), 0x7f, 0], [u8(0x63),
		0], [u8(0x7f)]] {
		assert !validate(webidl.BufferSource.array_buffer(binary_import_module(3, descriptor)))
	}
}
