module webassembly

fn test_simd_splats_and_last_lane_extracts_use_each_source_unpacked_shape() {
	cases := [
		[u32(binary_op_i8x16_splat), binary_op_i8x16_extract_lane_s, 15],
		[u32(binary_op_i16x8_splat), binary_op_i16x8_extract_lane_u, 7],
		[u32(binary_op_i32x4_splat), binary_op_i32x4_extract_lane, 3],
		[u32(binary_op_i64x2_splat), binary_op_i64x2_extract_lane, 1],
		[u32(binary_op_f32x4_splat), binary_op_f32x4_extract_lane, 3],
		[u32(binary_op_f64x2_splat), binary_op_f64x2_extract_lane, 1],
	]
	kinds := [BinaryValueKind.i32, .i32, .i32, .i64, .f32, .f64]
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for i, case_ in cases {
		stack.append_type(BinaryValueType{ kind: kinds[i] })
		validate_binary_simd_lane_instruction(BinaryInstruction{ opcode: case_[0] }, mut stack)!
		assert stack.last().concrete_type.kind == .v128
		validate_binary_simd_lane_instruction(BinaryInstruction{ opcode: case_[1], arguments: BinaryLaneArgument{ lane: u8(case_[2]) } }, mut stack)!
		assert stack.size() == 1 && stack.last().concrete_type.kind == kinds[i]
		stack.take_last()!
	}
}

fn test_simd_replacement_checks_lane_before_pop_and_consumes_scalar_before_vector() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .v128 })
	stack.append_type(BinaryValueType{ kind: .f64 })
	if _ := validate_binary_simd_lane_instruction(BinaryInstruction{ opcode: binary_op_f64x2_replace_lane, arguments: BinaryLaneArgument{ lane: 2 } }, mut stack) {
		assert false
	} else {
		assert err.msg().contains('extract lane out of bounds')
	}
	assert stack.size() == 2
	validate_binary_simd_lane_instruction(BinaryInstruction{ opcode: binary_op_f64x2_replace_lane, arguments: BinaryLaneArgument{ lane: 1 } }, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	stack.append_type(BinaryValueType{ kind: .i64 })
	if _ := validate_binary_simd_lane_instruction(BinaryInstruction{ opcode: binary_op_f64x2_replace_lane, arguments: BinaryLaneArgument{} }, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	assert stack.size() == 1
}

fn test_real_shuffle_operand_accepts_both_vectors_and_rejects_out_of_range_before_popping() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .v128 }) }
	mut bytes := [u8(0xfd), 0x0d]
	bytes << []u8{len: 16, init: 31}
	mut decoder := Decoder{ bytes: bytes }
	validate_binary_simd_lane_instruction(parse_binary_instruction(mut decoder)!, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .v128
	bytes[2] = 32
	mut invalid := Decoder{ bytes: bytes }
	if _ := validate_binary_simd_lane_instruction(parse_binary_instruction(mut invalid)!, mut stack) {
		assert false
	} else {
		assert err.msg().contains('shuffle lane out of bounds')
	}
	assert stack.size() == 1
}
