module webassembly

fn parse_variable_validation_instruction(bytes []u8) BinaryInstruction {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_instruction(mut decoder) or { panic(err) }
}

fn test_reference_validation_requires_real_declared_function_and_retains_typed_nonnull_reference() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{
			functions:             [BinaryDefinedType{}]
			function_type_indices: [?u32(7)]
		}
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	instruction := parse_variable_validation_instruction([u8(0xd2), 0])
	if _ := validate_binary_reference_variable_instruction(instruction, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid function reference'
	}
	validator.context.references[0] = true
	assert validate_binary_reference_variable_instruction(instruction, mut validator, mut stack)!
	assert stack.last().concrete_type == BinaryValueType{ kind: .type_use_reference, type_index: 7, nullable: false }
	assert !validate_binary_reference_variable_instruction(parse_variable_validation_instruction([u8(0xd1)]), mut validator, mut stack)!
	assert stack.last().concrete_type.kind == .i32
	if _ := validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0xd2),
		1,
	]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid FunctionIndex'
	}
}

fn test_reference_null_source_handler_is_constant_and_physical_empty_null_test_still_fails_unreachable() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, unreachable: true })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	if _ := validate_binary_reference_variable_instruction(parse_variable_validation_instruction([u8(0xd1)]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('expected reference')
	}
	assert validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0xd0),
		0x6f,
	]), mut validator, mut stack)!
	assert stack.last().concrete_type.kind == .extern_reference && stack.last().concrete_type.nullable
	assert !validate_binary_reference_variable_instruction(parse_variable_validation_instruction([u8(0xd1)]), mut validator, mut stack)!
	assert stack.last().concrete_type.kind == .i32
}

fn test_nondefaultable_local_initialization_is_rolled_back_with_the_source_log() {
	ref_ := BinaryValueType{ kind: .function_reference, nullable: false }
	mut validator := &BinaryInstructionValidator{
		context:           BinaryValidationContext{ locals: [ref_, BinaryValueType{ kind: .i32 }] }
		local_initialized: [false, true]
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	get := parse_variable_validation_instruction([u8(0x20), 0])
	if _ := validate_binary_reference_variable_instruction(get, mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('uninitialized non-defaultable local')
	}
	stack.append_type(ref_)
	assert !validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x22),
		0,
	]), mut validator, mut stack)!
	assert validator.local_initialized[0] && validator.local_init_log == [u32(0)]
	assert stack.size() == 1
	validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x21),
		0,
	]), mut validator, mut stack)!
	assert stack.is_empty() && validator.local_init_log.len == 1
	validator.roll_back_local_initializations(0)
	assert !validator.local_initialized[0] && validator.local_initialized[1]
	if _ := validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x20),
		2,
	]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid LocalIndex'
	}
}

fn test_global_get_constant_flag_follows_mutability_and_global_set_preserves_stack_on_readonly_error() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{
			globals: [
				BinaryGlobalType{ type_: BinaryValueType{ kind: .i64 } },
				BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 }, mutable_: true },
			]
		}
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	assert validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x23),
		0,
	]), mut validator, mut stack)!
	if _ := validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x24),
		0,
	]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('global variable for global.set')
	}
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i64
	assert !validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x23),
		1,
	]), mut validator, mut stack)!
	assert !validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x24),
		1,
	]), mut validator, mut stack)!
	assert stack.size() == 1
}

fn test_select_reference_annotation_and_unknown_operand_follow_distinct_source_paths() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .extern_reference }) }
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_reference_variable_instruction(parse_variable_validation_instruction([u8(0x1b)]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('select argument types')
	}
	assert stack.is_empty()
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .extern_reference }) }
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_reference_variable_instruction(parse_variable_validation_instruction([
		u8(0x1c),
		1,
		0x6f,
	]), mut validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .extern_reference
	stack.take_last()!
	validator.frames[0].unreachable = true
	stack.append_type(BinaryValueType{ kind: .f64 })
	stack.append(BinaryStackEntry{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_reference_variable_instruction(parse_variable_validation_instruction([u8(0x1b)]), mut validator, mut stack)!
	assert stack.last().is_known && stack.last().concrete_type.kind == .f64
}
