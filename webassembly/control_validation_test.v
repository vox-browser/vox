module webassembly

fn control_validation_instruction(bytes []u8) BinaryInstruction {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_instruction(mut decoder) or { panic(err) }
}

fn test_structured_block_parameters_results_metadata_and_local_rollback() {
	i32_type := BinaryValueType{ kind: .i32 }
	i64_type := BinaryValueType{ kind: .i64 }
	mut validator := &BinaryInstructionValidator{
		context:           BinaryValidationContext{ types: [BinaryDefinedType{ parameters: [i32_type], results: [i64_type] }] }
		local_initialized: [false]
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(i32_type)
	mut block := control_validation_instruction([u8(0x02), 0])
	assert !validate_binary_control_instruction(mut block, mut validator, mut stack)!
	meta := block.arguments as BinaryStructuredArguments
	assert meta.meta.parameter_count == 1 && meta.meta.arity == 1 && !meta.meta.tier_up_eligible
	assert validator.frames.len == 2 && validator.frames.last().initial_size == 0
	assert stack.last().concrete_type == i32_type
	stack.take(i32_type)!
	stack.append_type(i64_type)
	validator.mark_local_initialized(0)
	mut end := control_validation_instruction([u8(0x0b)])
	validate_binary_control_instruction(mut end, mut validator, mut stack)!
	assert validator.frames.len == 1 && !validator.local_initialized[0]
	assert stack.size() == 1 && stack.last().concrete_type == i64_type
}

fn test_if_without_else_validates_the_real_implicit_empty_else_and_rejects_result_only_signature() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut empty_if := control_validation_instruction([u8(0x04), 0x40])
	validate_binary_control_instruction(mut empty_if, mut validator, mut stack)!
	mut end := control_validation_instruction([u8(0x0b)])
	validate_binary_control_instruction(mut end, mut validator, mut stack)!
	assert validator.frames.len == 1 && stack.is_empty()
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut result_if := control_validation_instruction([u8(0x04), 0x7f])
	validate_binary_control_instruction(mut result_if, mut validator, mut stack)!
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_control_instruction(mut end, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('expected <any> but got <nothing>')
	}
	assert validator.frames.last().kind == .else_ && stack.is_empty()
}

fn test_else_rolls_back_local_initialization_and_reappends_block_parameters() {
	i32_type := BinaryValueType{ kind: .i32 }
	mut validator := &BinaryInstructionValidator{
		context:           BinaryValidationContext{ types: [BinaryDefinedType{ parameters: [i32_type], results: [i32_type] }] }
		local_initialized: [false]
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(i32_type)
	stack.append_type(i32_type)
	mut if_ := control_validation_instruction([u8(0x04), 0])
	validate_binary_control_instruction(mut if_, mut validator, mut stack)!
	validator.mark_local_initialized(0)
	mut else_ := control_validation_instruction([u8(0x05)])
	validate_binary_control_instruction(mut else_, mut validator, mut stack)!
	assert !validator.local_initialized[0] && validator.local_init_log.len == 0
	assert stack.size() == 1 && stack.last().concrete_type == i32_type
	if _ := validate_binary_control_instruction(mut else_, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('usage of structured else')
	}
}

fn test_loop_labels_are_parameters_and_tier_up_requires_empty_parameters_and_base_stack() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ types: [BinaryDefinedType{ parameters: [BinaryValueType{ kind: .i32 }], results: [BinaryValueType{ kind: .i64 }] }] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut loop_ := control_validation_instruction([u8(0x03), 0])
	validate_binary_control_instruction(mut loop_, mut validator, mut stack)!
	assert validator.frames.last().labels() == [BinaryValueType{ kind: .i32 }]
	args := loop_.arguments as BinaryStructuredArguments
	assert !args.meta.tier_up_eligible
	mut branch := control_validation_instruction([u8(0x0c), 0])
	validate_binary_control_instruction(mut branch, mut validator, mut stack)!
	assert validator.frames.last().unreachable && stack.is_empty()
	branch_args := branch.arguments as BinaryBranchArguments
	assert !branch_args.has_stack_adjustment
	mut end := control_validation_instruction([u8(0x0b)])
	validate_binary_control_instruction(mut end, mut validator, mut stack)!
	stack.take(BinaryValueType{ kind: .i64 })!
	mut empty_loop := control_validation_instruction([u8(0x03), 0x40])
	validate_binary_control_instruction(mut empty_loop, mut validator, mut stack)!
	empty_args := empty_loop.arguments as BinaryStructuredArguments
	assert empty_args.meta.tier_up_eligible
}

fn test_conditional_branch_restores_label_type_and_table_branch_checks_each_target_arity() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	validator.push_frame(BinaryValidationFrame{ kind: .block, type_: BinaryDefinedType{ results: [BinaryValueType{ kind: .extern_reference }] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .extern_reference, nullable: false })
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut branch := control_validation_instruction([u8(0x0d), 0])
	validate_binary_control_instruction(mut branch, mut validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.nullable
	assert !validator.frames.last().unreachable
	args := branch.arguments as BinaryBranchArguments
	assert args.has_stack_adjustment
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut table := control_validation_instruction([u8(0x0e), 1, 1, 0])
	if _ := validate_binary_control_instruction(mut table, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('br_table label arity mismatch')
	}
	assert stack.size() == 1 && !validator.frames.last().unreachable
}

fn test_try_table_catches_resolve_outer_labels_before_its_own_label_and_throw_is_polymorphic() {
	i32_type := BinaryValueType{ kind: .i32 }
	exn_type := BinaryValueType{ kind: .exception_reference, nullable: false }
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ types: [BinaryDefinedType{ parameters: [i32_type] }], tags: [BinaryTagType{ type_index: 0 }] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [
		i32_type,
		exn_type,
	] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	mut try_ := control_validation_instruction([u8(0x1f), 0x40, 1, 1, 0, 0])
	validate_binary_control_instruction(mut try_, mut validator, mut stack)!
	assert validator.frames.len == 2 && validator.frames.last().kind == .try_table
	args := try_.arguments as BinaryTryTableArguments
	assert args.meta.arity == 0
	stack.append_type(i32_type)
	mut throw_ := control_validation_instruction([u8(0x08), 0])
	validate_binary_control_instruction(mut throw_, mut validator, mut stack)!
	assert validator.frames.last().unreachable && stack.is_empty()
	mut throw_ref := control_validation_instruction([u8(0x0a)])
	validate_binary_control_instruction(mut throw_ref, mut validator, mut stack)!
	mut bad_try := control_validation_instruction([u8(0x1f), 0x40, 1, 1, 0, 2])
	if _ := validate_binary_control_instruction(mut bad_try, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid LabelIndex'
	}
	assert validator.frames.len == 2
}

fn test_structured_end_rejects_excess_values_and_return_targets_the_function_frame() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [BinaryValueType{ kind: .i64 }] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	mut block := control_validation_instruction([u8(0x02), 0x40])
	validate_binary_control_instruction(mut block, mut validator, mut stack)!
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut end := control_validation_instruction([u8(0x0b)])
	if _ := validate_binary_control_instruction(mut end, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: stack height mismatch'
	}
	stack.append_type(BinaryValueType{ kind: .i64 })
	mut return_ := control_validation_instruction([u8(0x0f)])
	validate_binary_control_instruction(mut return_, mut validator, mut stack)!
	assert validator.frames.len == 2 && validator.frames.last().unreachable && stack.is_empty()
}
