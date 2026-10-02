module webassembly

fn test_gc_reference_conversion_preserves_nullability_and_source_unknown_result_is_nonnull() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for nullable in [true, false] {
		stack.append_type(BinaryValueType{ kind: .extern_reference, nullable: nullable })
		mut convert := BinaryInstruction{ opcode: binary_op_any_convert_extern }
		assert validate_binary_gc_reference_instruction(mut convert, validator, mut stack)!
		assert stack.last().concrete_type.kind == .any_reference && stack.last().concrete_type.nullable == nullable
		mut back := BinaryInstruction{ opcode: binary_op_extern_convert_any }
		assert validate_binary_gc_reference_instruction(mut back, validator, mut stack)!
		assert stack.last().concrete_type.kind == .extern_reference && stack.last().concrete_type.nullable == nullable
		stack.take_last()!
	}
	validator.frames[0].unreachable = true
	mut convert := BinaryInstruction{ opcode: binary_op_any_convert_extern }
	validate_binary_gc_reference_instruction(mut convert, validator, mut stack)!
	assert stack.last().is_known && !stack.last().concrete_type.nullable
	stack.take_last()!
	mut nonnull := BinaryInstruction{ opcode: binary_op_ref_as_non_null }
	validate_binary_gc_reference_instruction(mut nonnull, validator, mut stack)!
	assert !stack.last().is_known
}

fn test_gc_scalar_reference_and_equality_validate_the_eq_heap_family() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	mut scalar := BinaryInstruction{ opcode: binary_op_ref_i31 }
	assert validate_binary_gc_reference_instruction(mut scalar, validator, mut stack)!
	assert stack.last().concrete_type.kind == .i31_reference && !stack.last().concrete_type.nullable
	stack.append_type(BinaryValueType{ kind: .struct_reference })
	mut eq := BinaryInstruction{ opcode: binary_op_ref_eq }
	validate_binary_gc_reference_instruction(mut eq, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	stack.take_last()!
	stack.append_type(BinaryValueType{ kind: .extern_reference })
	stack.append_type(BinaryValueType{ kind: .extern_reference })
	if _ := validate_binary_gc_reference_instruction(mut eq, validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
}

fn test_reference_cast_and_test_require_the_target_heap_family_top_and_validate_type_uses() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .any_reference })
	mut cast := BinaryInstruction{ opcode: binary_op_ref_cast, arguments: BinaryValueType{ kind: .struct_reference, nullable: false } }
	validate_binary_gc_reference_instruction(mut cast, validator, mut stack)!
	assert stack.last().concrete_type.kind == .struct_reference && !stack.last().concrete_type.nullable
	mut test := BinaryInstruction{ opcode: binary_op_ref_test_null, arguments: BinaryValueType{ kind: .array_reference } }
	validate_binary_gc_reference_instruction(mut test, validator, mut stack)!
	assert stack.last().concrete_type.kind == .i32
	mut bad := BinaryInstruction{ opcode: binary_op_ref_cast, arguments: BinaryValueType{ kind: .type_use_reference, type_index: 0 } }
	if _ := validate_binary_gc_reference_instruction(mut bad, validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid TypeIndex'
	}
	assert stack.size() == 1
}

fn test_null_branches_restore_label_prefix_and_refine_or_remove_reference_on_fallthrough() {
	i64_type := BinaryValueType{ kind: .i64 }
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [i64_type] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(i64_type)
	stack.append_type(BinaryValueType{ kind: .extern_reference })
	mut null_branch := BinaryInstruction{ opcode: binary_op_br_on_null, arguments: BinaryBranchArguments{} }
	validate_binary_gc_reference_instruction(mut null_branch, validator, mut stack)!
	assert stack.size() == 2 && !stack.last().concrete_type.nullable
	args := null_branch.arguments as BinaryBranchArguments
	assert args.has_stack_adjustment
	stack.take_last()!
	validator.frames[0].type_ = BinaryDefinedType{ results: [i64_type,
		BinaryValueType{ kind: .function_reference, nullable: false }] }
	stack.append_type(BinaryValueType{ kind: .function_reference })
	mut nonnull_branch := BinaryInstruction{ opcode: binary_op_br_on_non_null, arguments: BinaryBranchArguments{} }
	validate_binary_gc_reference_instruction(mut nonnull_branch, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type == i64_type
	assert !validator.frames[0].unreachable
}

fn test_cast_branch_difference_and_failure_fallthrough_follow_source_nullability_rule() {
	source := BinaryValueType{ kind: .any_reference }
	target := BinaryValueType{ kind: .struct_reference }
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [target] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(source)
	mut branch := BinaryInstruction{ opcode: binary_op_br_on_cast, arguments: BinaryBranchCastArguments{ source_type: source, target_type: target } }
	validate_binary_gc_reference_instruction(mut branch, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .any_reference && !stack.last().concrete_type.nullable
	args := branch.arguments as BinaryBranchCastArguments
	assert args.branch.has_stack_adjustment
	stack.take_last()!
	validator.frames[0].type_ = BinaryDefinedType{ results: [BinaryValueType{ kind: .any_reference, nullable: false }] }
	stack.append_type(source)
	mut failure := BinaryInstruction{ opcode: binary_op_br_on_cast_fail, arguments: BinaryBranchCastArguments{ source_type: source, target_type: target } }
	validate_binary_gc_reference_instruction(mut failure, validator, mut stack)!
	assert stack.last().concrete_type == target && !validator.frames[0].unreachable
	mut invalid := BinaryInstruction{ opcode: binary_op_br_on_cast, arguments: BinaryBranchCastArguments{ source_type: source, target_type: BinaryValueType{ kind: .extern_reference } } }
	if _ := validate_binary_gc_reference_instruction(mut invalid, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('br_on_cast target type')
	}
	assert stack.size() == 1
}
