module webassembly

fn test_polymorphic_stack_uses_live_frame_boundary_and_retains_peak_size() {
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	if _ := stack.take_last() {
		assert false
	} else {
		assert err.msg().contains('expected <any> but got <nothing>')
	}
	stack.append_type(BinaryValueType{ kind: .i64 })
	validator.push_frame(BinaryValidationFrame{ kind: .block, initial_size: 1, unreachable: true })
	for _ in 0 .. 3 {
		assert !stack.take(BinaryValueType{ kind: .f32 })!.is_known
	}
	assert stack.size() == 1
	stack.append_type(BinaryValueType{ kind: .i32 })
	assert stack.take(BinaryValueType{ kind: .i32 })!.is_known
	assert !stack.take_last()!.is_known
	validator.frames.pop()
	assert stack.take(BinaryValueType{ kind: .i64 })!.is_known
	assert stack.is_empty() && stack.maximum_known_size() == 2
	stack.resize(4)
	assert stack.size() == 4 && !stack.last().is_known
	stack.resize(1)
	assert stack.maximum_known_size() == 4
	assert stack.release_vector().len == 1
	assert stack.is_empty() && stack.maximum_known_size() == 0
}

fn test_stack_take_performs_full_type_matching_and_preserves_pop_order_on_failure() {
	mut decoder := Decoder{ bytes: [u8(2), 0x50, 0, 0x5f, 0, 0x4f, 1, 0, 0x5f, 0] }
	types := canonicalize_binary_module_types(parse_type_section(mut decoder)!)!
	context := BinaryTypeContext{ types: types }
	mut validator := &BinaryInstructionValidator{}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, context)
	stack.append_type(BinaryValueType{ kind: .type_use_reference, type_index: 1, nullable: false })
	assert stack.take(BinaryValueType{ kind: .type_use_reference, type_index: 0 })!.is_known
	stack.append_type(BinaryValueType{ kind: .type_use_reference, type_index: 0 })
	if _ := stack.take(BinaryValueType{ kind: .function_reference }) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	assert stack.is_empty()
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .f64 })
	stack.take_and_put([BinaryValueKind.f64, .i32], .i64)!
	assert stack.last().concrete_type.kind == .i64
	assert voidptr(stack.type_context().types[0]) == voidptr(types[0])
}

fn test_stack_entry_comparison_retains_source_static_subtyping_and_unknown_wildcards() {
	unknown := BinaryStackEntry{}
	assert unknown.is_numeric() && unknown.is_reference() && unknown.is_of_kind(.v128)
	assert unknown.matches_type(BinaryValueType{ kind: .f64 })
	typed := BinaryStackEntry{ concrete_type: BinaryValueType{ kind: .type_use_reference, type_index: 7, nullable: false }, is_known: true }
	assert typed.is_reference() && !typed.is_numeric()
	assert typed.matches_type(BinaryValueType{ kind: .function_reference })
	assert typed.matches_entry(unknown) && unknown.matches_entry(typed)
	assert !typed.matches_type(BinaryValueType{ kind: .extern_reference })
	assert BinaryStackEntry{ concrete_type: BinaryValueType{ kind: .extern_reference, nullable: false }, is_known: true }.matches_type(BinaryValueType{ kind: .extern_reference })
	assert !BinaryStackEntry{ concrete_type: BinaryValueType{ kind: .v128 }, is_known: true }.is_numeric()
	assert !BinaryStackEntry{ concrete_type: BinaryValueType{ kind: .i8 }, is_known: true }.is_numeric()
}

fn test_local_initialization_log_restores_branch_scoped_definite_initialization() {
	mut validator := &BinaryInstructionValidator{ local_initialized: [true, false, false] }
	validator.mark_local_initialized(1)
	validator.mark_local_initialized(1)
	assert validator.local_init_log == [u32(1)]
	validator.push_frame(BinaryValidationFrame{ kind: .if_, type_: BinaryDefinedType{ parameters: [BinaryValueType{ kind: .i32 }], results: [BinaryValueType{ kind: .i64 }] } })
	assert validator.frames[0].local_init_log_height == 1
	validator.mark_local_initialized(2)
	validator.roll_back_local_initializations(validator.frames[0].local_init_log_height)
	assert validator.local_initialized == [true, true, false]
	validator.roll_back_local_initializations(0)
	assert validator.local_initialized == [true, false, false]
	frame := validator.frames[0]
	assert frame.labels()[0].kind == .i64
	assert BinaryValidationFrame{ ...frame, kind: .loop }.labels()[0].kind == .i32
}
