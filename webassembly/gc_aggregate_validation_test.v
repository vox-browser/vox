module webassembly

fn aggregate_validation_context(input []BinaryDefinedType) !BinaryValidationContext {
	mut types := input.clone()
	for index, _ in types {
		types[index].rec_group = BinaryRecGroupSpan{ start: u32(index), count: 1 }
	}
	return BinaryValidationContext{ types: types, canonical_types: canonicalize_binary_module_types(types)! }
}

fn test_struct_creation_unpacks_packed_fields_and_get_requires_explicit_packed_signedness() {
	context := aggregate_validation_context([BinaryDefinedType{ kind: .struct_, fields: [
		BinaryFieldType{ type_: BinaryValueType{ kind: .i16 }, mutable_: true },
		BinaryFieldType{ type_: BinaryValueType{ kind: .f64 } },
	] }])!
	mut validator := &BinaryInstructionValidator{ context: context }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: context.canonical_types })
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .f64 })
	assert validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_struct_new, arguments: BinaryIndexArgument{} }, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type == binary_typed_reference(0, false)
	arg := BinaryStructFieldArguments{ type_index: 0, field_index: 0 }
	if _ := validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_struct_get, arguments: arg }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('signedness')
	}
	assert stack.size() == 1
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_struct_get_s, arguments: arg }, validator, mut stack)!
	assert stack.last().concrete_type.kind == .i32
	stack.take_last()!
	stack.append_type(binary_typed_reference(0, true))
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_struct_set, arguments: arg }, validator, mut stack)!
	assert stack.is_empty()
}

fn test_default_aggregate_creation_rejects_nondefaultable_fields_before_stack_consumption() {
	nonnull := BinaryFieldType{ type_: BinaryValueType{ kind: .extern_reference, nullable: false } }
	context := aggregate_validation_context([
		BinaryDefinedType{ kind: .struct_, fields: [nonnull] },
		BinaryDefinedType{ kind: .array, fields: [nonnull] },
	])!
	mut validator := &BinaryInstructionValidator{ context: context }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: context.canonical_types })
	stack.append_type(BinaryValueType{ kind: .i32 })
	for pair in [[binary_op_struct_new_default, u32(0)], [binary_op_array_new_default, u32(1)]] {
		if _ := validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: pair[0], arguments: BinaryIndexArgument{ index: pair[1] } }, validator, mut stack) {
			assert false
		} else {
			assert err.msg().contains('must be defaultable')
		}
		assert stack.size() == 1
	}
}

fn test_array_fixed_creation_get_fill_and_immutable_set_rejection() {
	context := aggregate_validation_context([
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .i8 }, mutable_: true }] },
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .i8 } }] },
	])!
	mut validator := &BinaryInstructionValidator{ context: context }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: context.canonical_types })
	for _ in 0 .. 3 { stack.append_type(BinaryValueType{ kind: .i32 }) }
	assert validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_new_fixed, arguments: BinaryArrayFixedArguments{ count: 3 } }, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type == binary_typed_reference(0, false)
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_get_u, arguments: BinaryIndexArgument{} }, validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i32
	stack.take_last()!
	stack.append_type(binary_typed_reference(0, true))
	for _ in 0 .. 3 { stack.append_type(BinaryValueType{ kind: .i32 }) }
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_fill, arguments: BinaryIndexArgument{} }, validator, mut stack)!
	assert stack.is_empty()
	if _ := validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_set, arguments: BinaryIndexArgument{ index: 1 } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('mutable array type')
	}
}

fn test_array_data_requires_data_count_and_array_element_segments_match_the_reference_field() {
	mut context := aggregate_validation_context([
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .i16 }, mutable_: true }] },
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .extern_reference } }] },
	])!
	context.datas = [false]
	context.elements = [BinaryValueType{ kind: .extern_reference, nullable: false },
		BinaryValueType{ kind: .function_reference }]
	mut validator := &BinaryInstructionValidator{ context: context }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: context.canonical_types })
	data := BinaryInstruction{ opcode: binary_op_array_new_data, arguments: BinaryArrayDataArguments{} }
	if _ := validate_binary_gc_aggregate_instruction(data, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('requires data count section')
	}
	validator.context.data_count = 1
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .i32 }) }
	assert !validate_binary_gc_aggregate_instruction(data, validator, mut stack)!
	assert stack.last().concrete_type == binary_typed_reference(0, false)
	for _ in 0 .. 3 { stack.append_type(BinaryValueType{ kind: .i32 }) }
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_init_data, arguments: BinaryArrayDataArguments{} }, validator, mut stack)!
	assert stack.is_empty()
	for _ in 0 .. 2 { stack.append_type(BinaryValueType{ kind: .i32 }) }
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_new_elem, arguments: BinaryArrayElementArguments{ type_index: 1 } }, validator, mut stack)!
	assert stack.last().concrete_type == binary_typed_reference(1, false)
	if _ := validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_new_elem, arguments: BinaryArrayElementArguments{ type_index: 1, element_index: 1 } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('element segment type')
	}
	assert stack.size() == 1
}

fn test_array_copy_requires_mutable_destination_and_compares_immutable_field_projections_covariantly() {
	context := aggregate_validation_context([
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .extern_reference }, mutable_: true }] },
		BinaryDefinedType{ kind: .array, fields: [BinaryFieldType{ type_: BinaryValueType{ kind: .extern_reference, nullable: false } }] },
	])!
	mut validator := &BinaryInstructionValidator{ context: context }
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: context.canonical_types })
	stack.append_type(binary_typed_reference(0, true))
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(binary_typed_reference(1, true))
	stack.append_type(BinaryValueType{ kind: .i32 })
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_copy, arguments: BinaryArrayCopyArguments{ destination_type_index: 0, source_type_index: 1 } }, validator, mut stack)!
	assert stack.is_empty()
	if _ := validate_binary_gc_aggregate_instruction(BinaryInstruction{ opcode: binary_op_array_copy, arguments: BinaryArrayCopyArguments{ destination_type_index: 1, source_type_index: 0 } }, validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('mutable array type')
	}
}
