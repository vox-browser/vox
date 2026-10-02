module webassembly

fn call_validation_instruction(bytes []u8) BinaryInstruction {
	mut decoder := Decoder{ bytes: bytes }
	return parse_binary_instruction(mut decoder) or { panic(err) }
}

fn test_direct_call_consumes_parameters_in_reverse_and_tail_call_requires_exact_return_types() {
	i32_type := BinaryValueType{ kind: .i32 }
	i64_type := BinaryValueType{ kind: .i64 }
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{
			functions: [BinaryDefinedType{
				parameters: [
					i32_type,
					i64_type,
				]
				results:    [i64_type]
			}]
		}
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [i32_type] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(i32_type)
	stack.append_type(i64_type)
	validate_binary_call_instruction(call_validation_instruction([u8(0x10), 0]), mut validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type == i64_type
	stack.take_last()!
	stack.append_type(i32_type)
	stack.append_type(i64_type)
	if _ := validate_binary_call_instruction(call_validation_instruction([u8(0x12), 0]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('return_call target')
	}
	assert stack.is_empty() && !validator.frames[0].unreachable
	validator.frames[0].type_ = BinaryDefinedType{ results: [i64_type] }
	stack.append_type(i32_type)
	stack.append_type(i64_type)
	validate_binary_call_instruction(call_validation_instruction([u8(0x12), 0]), mut validator, mut stack)!
	assert validator.frames[0].unreachable && stack.is_empty()
}

fn test_indirect_calls_preserve_source_table64_and_i32_tail_call_difference() {
	type_ := BinaryDefinedType{ results: [BinaryValueType{ kind: .i64 }] }
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ types: [type_], tables: [BinaryTableType{ element_type: BinaryValueType{ kind: .function_reference }, limits: WasmLimits{ address_type: .i64 } }] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: type_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i64 })
	validate_binary_call_instruction(call_validation_instruction([u8(0x11), 0, 0]), mut validator, mut stack)!
	assert stack.size() == 1 && stack.last().concrete_type.kind == .i64
	if _ := validate_binary_call_instruction(call_validation_instruction([u8(0x13), 0, 0]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid stack state'
	}
	stack.append_type(BinaryValueType{ kind: .i32 })
	validate_binary_call_instruction(call_validation_instruction([u8(0x13), 0, 0]), mut validator, mut stack)!
	assert stack.is_empty() && validator.frames[0].unreachable
}

fn test_indirect_call_rejects_nonfunction_table_or_type_before_consuming_operand() {
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{
			types:  [BinaryDefinedType{}, BinaryDefinedType{ kind: .struct_ }]
			tables: [BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference } }]
		}
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_ })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{})
	stack.append_type(BinaryValueType{ kind: .i32 })
	if _ := validate_binary_call_instruction(call_validation_instruction([u8(0x11), 0, 0]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('table element type')
	}
	assert stack.size() == 1
	validator.context.tables[0] = BinaryTableType{ element_type: BinaryValueType{ kind: .function_reference } }
	if _ := validate_binary_call_instruction(call_validation_instruction([u8(0x11), 1, 0]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('type for call.indirect')
	}
	assert stack.size() == 1
}

fn test_typed_reference_tail_call_uses_source_stack_entry_covariance_while_direct_tail_requires_equality() {
	callee := BinaryDefinedType{ results: [BinaryValueType{ kind: .extern_reference, nullable: false }], rec_group: BinaryRecGroupSpan{ count: 1 } }
	canonical := canonicalize_binary_module_types([callee])!
	mut validator := &BinaryInstructionValidator{
		context: BinaryValidationContext{ types: [callee], canonical_types: canonical, functions: [callee] }
	}
	validator.push_frame(BinaryValidationFrame{ kind: .function_, type_: BinaryDefinedType{ results: [BinaryValueType{ kind: .extern_reference }] } })
	mut stack := BinaryValidationStack.create(validator, BinaryTypeContext{ types: canonical })
	stack.append_type(BinaryValueType{ kind: .type_use_reference, type_index: 0, nullable: false })
	validate_binary_call_instruction(call_validation_instruction([u8(0x14), 0]), mut validator, mut stack)!
	assert stack.last().concrete_type.kind == .extern_reference && !stack.last().concrete_type.nullable
	stack.take_last()!
	if _ := validate_binary_call_instruction(call_validation_instruction([u8(0x12), 0]), mut validator, mut stack) {
		assert false
	} else {
		assert err.msg().contains('return_call target')
	}
	stack.append_type(BinaryValueType{ kind: .type_use_reference, type_index: 0 })
	validate_binary_call_instruction(call_validation_instruction([u8(0x15), 0]), mut validator, mut stack)!
	assert validator.frames[0].unreachable && stack.is_empty()
}
