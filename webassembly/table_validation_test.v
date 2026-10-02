module webassembly

fn table_validation_instruction(bytes []u8) BinaryInstruction {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_instruction(mut decoder) or { panic(err) }
}

fn test_table64_get_set_size_grow_and_fill_consume_source_address_and_element_types() {
	ref_ := BinaryValueType{ kind: .extern_reference }
	i64_type := BinaryValueType{ kind: .i64 }
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ tables: [BinaryTableType{ element_type: ref_, limits: WasmLimits{ address_type: .i64 } }] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(i64_type)
	validate_binary_table_instruction(table_validation_instruction([u8(0x25), 0]), validator, mut stack)!
	assert stack.last().concrete_type == ref_
	stack.take_last()!
	stack.append_type(i64_type)
	stack.append_type(ref_)
	validate_binary_table_instruction(table_validation_instruction([u8(0x26), 0]), validator, mut stack)!
	assert stack.is_empty()
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x10, 0]), validator, mut stack)!
	assert stack.last().concrete_type == i64_type
	stack.take_last()!
	stack.append_type(ref_)
	stack.append_type(i64_type)
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0f, 0]), validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type == i64_type
	stack.append_type(ref_)
	stack.append_type(i64_type)
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x11, 0]), validator, mut stack)!
	assert stack.is_empty()
}

fn test_table_copy_checks_reference_direction_before_popping_and_mixed_address_count_is_i32() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ tables: [
			BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference }, limits: WasmLimits{ address_type: .i64 } },
			BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference, nullable: false } },
		] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0e, 0, 1]), validator, mut stack)!
	assert stack.is_empty()
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0e, 1,
		0]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('table.copy types')
	}
	assert stack.size() == 1
}

fn test_table_init_checks_element_reference_and_uses_i32_source_offset_and_count_for_table64() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ tables: [BinaryTableType{ element_type: BinaryValueType{ kind: .function_reference }, limits: WasmLimits{ address_type: .i64 } }], elements: [
			BinaryValueType{ kind: .function_reference },
			BinaryValueType{ kind: .extern_reference },
		] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0c, 0, 0]), validator, mut stack)!
	assert stack.is_empty()
	if _ := validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0c, 1,
		0]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('table.init types')
	}
	validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0d, 1]), validator, mut stack)!
	if _ := validate_binary_table_instruction(table_validation_instruction([u8(0xfc), 0x0d, 2]), validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid ElementIndex'
	}
}
