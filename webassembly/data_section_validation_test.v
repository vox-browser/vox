module webassembly

fn data_validation_module(memory_type []u8, expression []u8, index u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 5, u8(memory_type.len + 1), 1]
	bytes << memory_type
	mut payload := [u8(1), 2, index]
	payload << expression
	payload << [u8(1), 0xff]
	bytes << [u8(11), u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_active_data_uses_selected_memory_address_kind_and_retains_expression_peak() {
	for definition in [[u8(0), 0], [u8(4), 0]] {
		opcode := if definition[0] == 0 { u8(0x41) } else { u8(0x42) }
		compiled := compile_module(data_validation_module(definition, [opcode, 1, opcode, 2,
			if opcode == 0x41 { u8(0x6a) } else { u8(0x7c) }, 0x0b], 0))!
		offset := compiled.data_segments[0].offset?
		assert offset.stack_usage_hint? == 2 && compiled.data_segments[0].init == [u8(0xff)]
	}
}

fn test_active_data_rejects_missing_memory_nonconstant_surplus_and_wrong_address_kind() {
	for expression in [[u8(0x42), 0, 0x0b], [u8(0x41), 1, 0x41, 2, 0x6d, 0x0b],
		[u8(0x41), 1, 0x41, 2, 0x0b], [u8(0x0b)]] {
		if _ := compile_module(data_validation_module([u8(0), 0], expression, 0)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
	if _ := compile_module(data_validation_module([u8(0), 0], [u8(0x41), 0, 0x0b], 1)) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid MemoryIndex'
	}
}
