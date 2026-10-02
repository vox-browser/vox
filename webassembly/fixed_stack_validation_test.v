module webassembly

fn test_source_fixed_stack_operations_validate_real_extended_constant_expression() {
	mut decoder := Decoder{ bytes: [u8(0x41), 1, 0x41, 2, 0x6a, 0x41, 3, 0x6c, 0x0b] }
	expression := parse_binary_expression(mut decoder)!
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for instruction in expression.instructions {
		constant := validate_binary_fixed_stack_instruction(instruction, mut stack)!
		assert constant
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	assert stack.maximum_known_size() == 2
	stack.take(BinaryValueType{ kind: .i32 })!
	assert stack.is_empty()
}

fn test_source_fixed_stack_division_comparisons_conversions_and_vector_constant_flags() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .i64 }) }
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i64_divs }, mut stack)!
	assert stack.last().concrete_type.kind == .i64
	stack.append_type(BinaryValueType{ kind: .i64 })
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i64_eq }, mut stack)!
	assert stack.last().concrete_type.kind == .i32
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i64_extend_si32 }, mut stack)!
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_f32_convert_si64 }, mut stack)!
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_f64_promote_f32 }, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .f64
	assert !validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_nop }, mut stack)!
	assert stack.size() == 1
	mut vector_bytes := [u8(0xfd), 12]
	vector_bytes << []u8{len: 16, init: 0xff}
	mut decoder := Decoder{ bytes: vector_bytes }
	vector := parse_binary_instruction(mut decoder)!
	assert validate_binary_fixed_stack_instruction(vector, mut stack)!
	assert stack.size() == 2 && stack.last().concrete_type.kind == .v128
}

fn test_source_fixed_stack_ops_reject_underflow_and_wrong_types_and_honor_unreachable_frames() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	if _ := validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i32_add }, mut stack) {
		assert false
	} else {
		assert err.msg().contains('expected <any> but got <nothing>')
	}
	stack.append_type(BinaryValueType{ kind: .f32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i32_mul }, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	assert stack.is_empty()
	validator.frames[0].unreachable = true
	assert validate_binary_fixed_stack_instruction(BinaryInstruction{ opcode: binary_op_i32_sub }, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
}

fn fixed_stack_vector_constant_bytes() []u8 {
	mut bytes := [u8(0xfd), 0x0c]
	bytes << []u8{len: 16}
	return bytes
}

fn test_source_simd_return_bodies_validate_parsed_unary_binary_ternary_and_reduction() {
	mut bytes := fixed_stack_vector_constant_bytes()
	bytes << [u8(0xfd), 0x4d] // v128.not
	bytes << fixed_stack_vector_constant_bytes()
	bytes << [u8(0xfd), 0x4e] // v128.and
	bytes << fixed_stack_vector_constant_bytes()
	bytes << fixed_stack_vector_constant_bytes()
	bytes << [u8(0xfd), 0x52, 0xfd, 0x67, 0xfd, 0x53, 0x0b] // bitselect, ceil, any_true
	mut decoder := Decoder{ bytes: bytes }
	expression := parse_binary_expression(mut decoder)!
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for instruction in expression.instructions {
		constant := validate_binary_fixed_stack_instruction(instruction, mut stack)!
		assert constant == (instruction.opcode in [binary_op_v128_const,
			binary_op_synthetic_end_expression])
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	assert stack.maximum_known_size() == 3
}

fn test_source_simd_shift_pops_scalar_before_vector_and_rejects_wrong_scalar() {
	mut bytes := fixed_stack_vector_constant_bytes()
	bytes << [u8(0x41), 3, 0xfd, 0x6b, 0x0b] // i32.const, i8x16.shl
	mut decoder := Decoder{ bytes: bytes }
	expression := parse_binary_expression(mut decoder)!
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for instruction in expression.instructions {
		validate_binary_fixed_stack_instruction(instruction, mut stack)!
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	stack.append_type(BinaryValueType{ kind: .i64 })
	if _ := validate_binary_fixed_stack_instruction(expression.instructions[2], mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
}

fn test_source_relaxed_simd_return_body_and_unreachable_polymorphism() {
	mut bytes := fixed_stack_vector_constant_bytes()
	bytes << fixed_stack_vector_constant_bytes()
	bytes << fixed_stack_vector_constant_bytes()
	bytes << [u8(0xfd), 0x89, 0x02, 0x0b] // i8x16.relaxed_laneselect
	mut decoder := Decoder{ bytes: bytes }
	expression := parse_binary_expression(mut decoder)!
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for instruction in expression.instructions {
		validate_binary_fixed_stack_instruction(instruction, mut stack)!
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	stack.take(BinaryValueType{ kind: .v128 })!
	validator.frames[0].unreachable = true
	assert !validate_binary_fixed_stack_instruction(expression.instructions[3], mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
}
