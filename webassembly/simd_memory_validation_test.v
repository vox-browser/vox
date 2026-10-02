module webassembly

fn test_pinned_simd_splats_keep_i32_addresses_even_for_memory64_and_do_not_validate_offsets() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [WasmLimits{ address_type: .i64 }] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	arg := BinaryMemoryArgument{ offset: u64(max_u32) + 1 }
	stack.append_type(BinaryValueType{ kind: .i64 })
	if _ := validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load8_splat, arguments: arg }, validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load8_splat, arguments: arg }, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	stack.take_last()!
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .v128 })
	validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_store, arguments: arg }, validator, mut stack)!
	assert stack.is_empty()
}

fn test_simd_zero_loads_use_real_memory64_address_helper_and_memory32_offset_check() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [
		WasmLimits{},
		WasmLimits{ address_type: .i64 },
	] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i64 })
	validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load64_zero, arguments: BinaryMemoryArgument{ memory_index: 1, align: 3, offset: u64(max_u32) + 1 } }, validator, mut stack)!
	assert stack.last().concrete_type.kind == .v128
	stack.take_last()!
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load32_zero, arguments: BinaryMemoryArgument{ offset: u64(max_u32) + 1 } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('offset out of bounds')
	}
	assert stack.size() == 1
}

fn test_simd_lane_bounds_precede_memory_lookup_and_load_store_keep_source_vector_order() {
	mut validator := &BinaryInstructionValidator{ context: BinaryValidationContext{ memories: [WasmLimits{ address_type: .i64 }] } }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	if _ := validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load64_lane, arguments: BinaryMemoryLaneArgument{ lane: 2, memory: BinaryMemoryArgument{ memory_index: 2 } } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('lane index out of bounds')
	}
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .v128 })
	arg := BinaryMemoryLaneArgument{ lane: 1, memory: BinaryMemoryArgument{ align: 3 } }
	validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_load64_lane, arguments: arg }, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	stack.take_last()!
	stack.append_type(BinaryValueType{ kind: .i64 })
	stack.append_type(BinaryValueType{ kind: .v128 })
	validate_binary_simd_memory_instruction(BinaryInstruction{ opcode: binary_op_v128_store64_lane, arguments: arg }, validator, mut stack)!
	assert stack.is_empty()
}
