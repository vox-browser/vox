module webassembly

fn test_machine_labels_retain_source_control_and_try_table_instruction_identity() {
	mut instruction := &BinaryInstruction{
		opcode:    binary_op_try_table
		arguments: BinaryTryTableArguments{ end_ip: 9, catches: [BinaryCatch{ label_index: 3 }] }
	}
	label := BinaryMachineLabel.create(2, 9, 17, instruction)
	assert label.arity() == 2 && label.continuation() == 9 && label.stack_height() == 17
	assert voidptr(label.try_table_instruction()) == voidptr(instruction)
	instruction.arguments = BinaryTryTableArguments{ end_ip: 11 }
	arguments := label.try_table_instruction().arguments
	assert arguments is BinaryTryTableArguments
	if arguments is BinaryTryTableArguments {
		assert arguments.end_ip == 11
	}
	ordinary := BinaryMachineLabel.create(0, 0, 0, unsafe { nil })
	assert ordinary.try_table_instruction() == unsafe { nil }
}

fn test_machine_frame_move_keeps_actual_module_locals_expression_and_vector_header() {
	mut module_ := BinaryMachineModuleInstance.create()
	mut expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_nop }] }
	mut locals := [BinaryMachineValue.from_i32(41)]
	mut frame := BinaryMachineFrame.create(module_, locals.data, expression, 2, true)
	assert voidptr(frame.module()) == voidptr(module_)
	assert voidptr(frame.expression()) == voidptr(expression)
	assert voidptr(frame.locals_data()) == voidptr(locals.data)
	assert frame.owns_locals() && frame.arity() == 2 && frame.label_index() == 0
	assert frame.compiled_fn_table() == unsafe { nil }
	mut table := &BinaryMachineCompiledFunctionTable{
		entries: [BinaryMachineCompiledFunctionEntry{ arity: 2 }]
	}
	frame.set_compiled_fn_table(table)
	frame.set_label_index(7)
	moved := BinaryMachineFrame.move_construct(&frame)
	assert moved.label_index() == 7 && moved.owns_locals() && moved.arity() == 2
	assert voidptr(moved.locals_data()) == voidptr(frame.locals_data())
	assert voidptr(moved.compiled_fn_table()) == voidptr(table)
	// Mutating the real owners remains visible; no local/code/table copies.
	locals[0] = BinaryMachineValue.from_i32(73)
	expression.instructions << BinaryInstruction{ opcode: binary_op_synthetic_end_expression }
	mut contents := module_.contents()
	contents.functions << 19
	for index in 0 .. 100 {
		table.entries << BinaryMachineCompiledFunctionEntry{ arity: u32(index) }
	}
	assert unsafe { moved.locals_data()[0].to_i32() } == 73
	assert moved.expression().instructions.len == 2
	assert moved.module().functions() == [u64(19)]
	assert moved.compiled_fn_table().entries.len == 101
	assert moved.compiled_fn_table().entries[100].arity == 99
	// Source move does not clear fields on the moved-from record.
	assert frame.label_index() == 7 && voidptr(frame.compiled_fn_table()) == voidptr(table)
	borrowed := BinaryMachineFrame.create(module_, unsafe { nil }, expression, 0, false)
	assert !borrowed.owns_locals() && borrowed.locals_data() == unsafe { nil }
}
