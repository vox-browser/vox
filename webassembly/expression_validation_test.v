module webassembly

fn expression_validation_fixture(bytes []u8) BinaryExpression {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_expression(mut decoder) or { panic(err) }
}

fn test_expression_validation_extended_constants_retains_peak_hint_and_releases_frame() {
	mut expression := expression_validation_fixture([u8(0x41), 1, 0x41, 2, 0x6a, 0x41, 3, 0x6c,
		0x0b])
	mut validator := &BinaryInstructionValidator{}
	result := validator.validate_expression(mut expression, [BinaryValueType{ kind: .i32 }])!
	assert result.is_constant
	assert result.result_types == [BinaryStackEntry{ concrete_type: BinaryValueType{ kind: .i32 }, is_known: true }]
	assert expression.stack_usage_hint? == 2 && validator.frames.len == 0
	mut empty := expression_validation_fixture([u8(0x0b)])
	empty_result := validator.validate_expression(mut empty, [])!
	assert empty_result.is_constant && empty_result.result_types.len == 0 && empty.stack_usage_hint? == 0
}

fn test_expression_validation_visits_every_instruction_after_nonconstant_and_reports_result_underflow() {
	mut validator := &BinaryInstructionValidator{}
	mut expression := expression_validation_fixture([u8(0x01), 0x41, 1, 0x43, 0, 0, 0, 0, 0x6a,
		0x0b])
	if _ := validator.validate_expression(mut expression, [BinaryValueType{ kind: .i32 }]) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	mut missing_validator := &BinaryInstructionValidator{}
	mut missing := expression_validation_fixture([u8(0x0b)])
	if _ := missing_validator.validate_expression(mut missing, [BinaryValueType{ kind: .i64 }]) {
		assert false
	} else {
		assert err.msg().contains('expected <any> but got <nothing>')
	}
}

fn test_expression_validation_preserves_structured_and_branch_metadata_in_actual_instruction_records() {
	mut expression := expression_validation_fixture([u8(0x03), 0x40, 0x41, 9, 0x0c, 0, 0x0b, 0x41,
		7, 0x0b])
	mut validator := &BinaryInstructionValidator{}
	result := validator.validate_expression(mut expression, [BinaryValueType{ kind: .i32 }])!
	assert !result.is_constant && result.result_types.len == 1
	loop_ := expression.instructions[0].arguments as BinaryStructuredArguments
	assert loop_.meta.tier_up_eligible && loop_.meta.arity == 0 && loop_.end_ip == 3
	branch := expression.instructions[2].arguments as BinaryBranchArguments
	assert branch.has_stack_adjustment
	assert expression.stack_usage_hint? == 1 && validator.frames.len == 0
}

fn test_expression_validation_widens_refined_reference_results_and_keeps_extra_stack_values_for_section_check() {
	mut validator := &BinaryInstructionValidator{}
	mut expression := expression_validation_fixture([u8(0x41), 3, 0xd0, 0x6f, 0xd4, 0x0b])
	expected := BinaryValueType{ kind: .extern_reference }
	result := validator.validate_expression(mut expression, [expected])!
	assert !result.is_constant && result.result_types.len == 2
	assert result.result_types[0].concrete_type.kind == .i32
	assert result.result_types[1].concrete_type == expected && result.result_types[1].is_known
	assert expression.stack_usage_hint? == 2
}

fn test_expression_validation_dispatches_gc_and_vector_operands_with_actual_source_constant_flags() {
	mut gc := expression_validation_fixture([u8(0x41), 0, 0xfb, 0x1c, 0x0b])
	mut validator := &BinaryInstructionValidator{}
	result := validator.validate_expression(mut gc, [BinaryValueType{ kind: .i31_reference }])!
	assert result.is_constant && result.result_types.len == 1
	mut vector_bytes := [u8(0xfd), 0x0c]
	vector_bytes << []u8{len: 16}
	vector_bytes << [u8(0xfd), 0x53, 0x0b]
	mut vector := expression_validation_fixture(vector_bytes)
	vector_result := validator.validate_expression(mut vector, [BinaryValueType{ kind: .i32 }])!
	assert !vector_result.is_constant && vector_result.result_types.len == 1
	assert vector.stack_usage_hint? == 1
	mut invalid := BinaryExpression{ instructions: [BinaryInstruction{ opcode: 0xffffffff }] }
	if _ := validator.validate_expression(mut invalid, []) {
		assert false
	} else {
		assert err.msg().contains('instruction opcode (0xffffffff)')
	}
}
