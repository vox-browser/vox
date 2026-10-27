module webassembly

fn test_source_dispatch_union_register_mapping_and_trap_layout() {
	assert sizeof(BinaryRegisterOrStack) == 1
	assert int(binary_count_registers) == 8
	assert int(BinaryRegisterOrStack.call_record) == 9
	assert int(BinaryRegisterOrStack.last_call_record) == 255
	assert sizeof(BinarySourcesAndDestinationFields) == 4
	assert sizeof(BinarySourcesAndDestination) == 4
	assert sizeof(BinaryCraneliftTrap) == 8
	assert sizeof(BinaryDispatchPayload) == sizeof(uint)
	assert sizeof(BinaryDispatch) == 2 * sizeof(uint)
	mut instruction := BinaryInstruction{ opcode: binary_op_i32_const, arguments: BinaryI32Constant{ value: 7 } }
	mut dispatch := BinaryDispatch{ payload: BinaryDispatchPayload{ instruction_opcode: binary_op_i32_const }, instruction: &instruction }
	unsafe {
		assert dispatch.payload.instruction_opcode == binary_op_i32_const
		dispatch.payload.handler_ptr = uint(0x12345678)
		assert dispatch.payload.instruction_opcode == 0x12345678
	}
	assert voidptr(dispatch.instruction) == voidptr(&instruction)
	mut mapping := BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [
				BinaryRegisterOrStack.r2,
				.stack,
				.last_call_record,
			]!
			destination: .call_record
		}
	}
	unsafe {
		assert mapping.sources_and_destination == 0x09ff0802
		mapping.sources_and_destination = 0x08070605
		assert mapping.operands.sources == [BinaryRegisterOrStack.r5, .r6, .r7]!
		assert mapping.operands.destination == .stack
	}
}

fn test_source_expression_owns_actual_dispatch_and_extra_instruction_records() {
	mut expression := BinaryExpression{}
	assert expression.stack_usage_hint == none
	assert binary_cranelift_entry_acquire(&expression.compiled_instructions) == 0
	assert expression.compiled_instructions.cranelift_code_handle == unsafe { nil }
	assert expression.compiled_instructions.cranelift_traps == unsafe { nil }
	assert !expression.compiled_instructions.direct && !expression.compiled_instructions.cranelift_compiled
	assert !expression.compiled_instructions.cranelift_eligible && !expression.compiled_instructions.has_tier_up_checkpoints
	first := expression.compiled_instructions.extra_instruction_storage.append(BinaryInstruction{ opcode: binary_op_i32_const, arguments: BinaryI32Constant{ value: 9 } })
	expression.compiled_instructions.dispatches << BinaryDispatch{ instruction: first }
	for _ in 0 .. 1536 {
		expression.compiled_instructions.extra_instruction_storage.append(BinaryInstruction{ opcode: binary_op_nop })
	}
	assert expression.compiled_instructions.extra_instruction_storage.size() == 1537
	assert voidptr(expression.compiled_instructions.dispatches[0].instruction) == voidptr(first)
	arguments := expression.compiled_instructions.dispatches[0].instruction.arguments as BinaryI32Constant
	assert arguments.value == 9
}

fn source_compiled_record_consumer(compiled &BinaryCompiledInstructions) uint {
	for binary_cranelift_entry_acquire(compiled) == 0 {
	}
	// These ordinary reads follow the source acquire publication boundary.
	return compiled.max_call_arg_count + compiled.max_call_rec_size + uint(compiled.cranelift_local_count)
}

fn test_source_native_entry_publication_exposes_preceding_metadata_to_reader() {
	mut compiled := &BinaryCompiledInstructions{}
	consumer := spawn source_compiled_record_consumer(compiled)
	compiled.max_call_arg_count = 17
	compiled.max_call_rec_size = 31
	compiled.cranelift_local_count = 7
	binary_publish_cranelift_entry(mut compiled, uint(0x1234))
	observed := consumer.wait()
	assert observed == 55
	assert binary_cranelift_entry_acquire(compiled) == uint(0x1234)
}
