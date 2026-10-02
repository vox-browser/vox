module webassembly

fn memory_validation_instruction(bytes []u8) BinaryInstruction {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_instruction(mut decoder) or { panic(err) }
}

fn test_memory_access_checks_alignment_and_memory32_offset_before_address_consumption() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [WasmLimits{}] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_memory_access_instruction(memory_validation_instruction([
		u8(0x28),
		3,
		0,
	]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('alignment out of bounds')
	}
	assert stack.size() == 1
	if _ := validate_binary_memory_access_instruction(memory_validation_instruction([
		u8(0x28),
		2,
		0x80,
		0x80,
		0x80,
		0x80,
		0x10,
	]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('offset out of bounds')
	}
	assert stack.size() == 1
	validate_binary_memory_access_instruction(memory_validation_instruction([u8(0x28), 2, 0]), validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	if _ := validate_binary_memory_access_instruction(BinaryInstruction{ opcode: binary_op_i32_load, arguments: BinaryMemoryArgument{ align: 65 } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('alignment value out of bounds')
	}
}

fn test_memory64_multiple_memory_loads_and_stores_keep_source_scalar_and_vector_result_types() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [
		WasmLimits{},
		WasmLimits{ address_type: .i64 },
	] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i64 })
	validate_binary_memory_access_instruction(memory_validation_instruction([u8(0x2d), 0x40, 1,
		0x80, 0x80, 0x80, 0x80, 0x10]), validator, mut stack)!
	assert stack.last().concrete_type.kind == .i32
	stack.take_last()!
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .f64 })
	validate_binary_memory_access_instruction(memory_validation_instruction([u8(0x39), 0x43, 1,
		0]), validator, mut stack)!
	assert stack.is_empty()
	stack.append_type(BinaryValueType{ kind: .i64 })
	validate_binary_memory_access_instruction(memory_validation_instruction([u8(0xfd), 0, 0x44,
		1, 0]), validator, mut stack)!
	assert stack.last().concrete_type.kind == .v128
}

fn test_memory_store_consumes_value_before_source_offset_error_and_narrow_store_alignment_is_access_width() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [WasmLimits{}] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i64 })
	if _ := validate_binary_memory_access_instruction(memory_validation_instruction([
		u8(0x3e),
		2,
		0x80,
		0x80,
		0x80,
		0x80,
		0x10,
	]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('offset out of bounds')
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	stack.append_type(BinaryValueType{ kind: .i64 })
	if _ := validate_binary_memory_access_instruction(memory_validation_instruction([
		u8(0x3c),
		1,
		0,
	]), validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('alignment out of bounds')
	}
	assert stack.size() == 2
	validate_binary_memory_access_instruction(memory_validation_instruction([u8(0x3c), 0, 0]), validator, mut stack)!
	assert stack.is_empty()
}

fn test_memory64_size_growth_fill_and_mixed_copy_use_the_source_address_types() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [
		WasmLimits{},
		WasmLimits{ address_type: .i64 },
	] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	validate_binary_memory_bulk_instruction(memory_validation_instruction([u8(0x3f), 1]), validator, mut stack)!
	assert stack.last().concrete_type.kind == .i64
	validate_binary_memory_bulk_instruction(memory_validation_instruction([u8(0x40), 1]), validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i64
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i64 })
	validate_binary_memory_bulk_instruction(memory_validation_instruction([u8(0xfc), 0x0b, 1]), validator, mut stack)!
	assert stack.is_empty()
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_memory_bulk_instruction(memory_validation_instruction([u8(0xfc), 0x0a, 1, 0]), validator, mut stack)!
	assert stack.is_empty()
}

fn test_memory_init_and_data_drop_require_data_count_before_validating_indices_or_stack() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [WasmLimits{ address_type: .i64 }], datas: [false] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	init := memory_validation_instruction([u8(0xfc), 8, 0, 0])
	if _ := validate_binary_memory_bulk_instruction(init, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('requires data count section')
	}
	validator.context.data_count = 1
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_memory_bulk_instruction(init, validator, mut stack)!
	assert stack.is_empty()
	validate_binary_memory_bulk_instruction(memory_validation_instruction([u8(0xfc), 9, 0]), validator, mut stack)!
	if _ := validate_binary_memory_bulk_instruction(memory_validation_instruction([
		u8(0xfc),
		9,
		1,
	]), validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid DataIndex'
	}
}
