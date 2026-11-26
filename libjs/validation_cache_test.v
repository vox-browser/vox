module libjs

fn validation_fixture() &Executable {
	return &Executable{
		registers_and_locals_count: 6
		constants:                  [Value.from_i32(42)]
		bytecode_length:            2
		instructions:               [
			Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.constant(0) },
			Instruction{ op: .end, lhs: Operand.register(5) },
		]
	}
}

fn warm_validation(executable &Executable) ! {
	executable.validate(0)!
	executable.validate(0)!
	executable.validate(0)!
	assert executable.validation_snapshot != none
}

fn test_validation_cache_reuses_exact_stream_and_detects_instruction_mutation() {
	defer { diagnose_validation_cache_for_testing(false) }
	diagnose_validation_cache_for_testing(true)
	mut executable := validation_fixture()
	warm_validation(executable)!
	activity := diagnose_validation_cache_for_testing(false)
	assert activity.hits > 0 && activity.misses > 0
	executable.instructions[0].lhs = Operand.constant(1)
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	executable.instructions[0].lhs = Operand.constant(0)
	executable.validate(0)!
	executable.instructions[0].dst = Operand.register(6)
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Register out of range')
	}
}

fn test_validation_cache_checks_nested_operands_handlers_and_argument_count() {
	mut executable := validation_fixture()
	executable.instructions[0] = Instruction{ op: .call, dst: Operand.register(5), lhs: Operand.constant(0), rhs: Operand.constant(0), arguments: [Operand.constant(0)] }
	warm_validation(executable)!
	executable.instructions[0].arguments[0] = Operand.constant(1)
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	executable.instructions[0].arguments[0] = Operand.constant(0)
	executable.validate(0)!
	executable.exception_handlers = [ExceptionHandlers{ start_offset: 0, end_offset: 1, handler_offset: 1, catches_exception: true }]
	executable.validate(0)!
	executable.validate(0)!
	executable.exception_handlers[0] = ExceptionHandlers{ start_offset: 0, end_offset: 3, handler_offset: 1, catches_exception: true }
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Invalid exception handler range')
	}
	executable.exception_handlers = []ExceptionHandlers{}
	executable.instructions[0] = Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.argument(0) }
	executable.validate(1)!
	executable.validate(1)!
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Argument out of range')
	}
}

fn test_validation_cache_checks_layout_and_identifier_table_lengths() {
	mut executable := validation_fixture()
	warm_validation(executable)!
	executable.constants = []Value{}
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	executable.constants = [Value.from_i32(42)]
	executable.instructions[0] = Instruction{ op: .get_binding, dst: Operand.register(5), identifier: 0 }
	executable.identifier_table = [utf16_string('x')]
	executable.validate(0)!
	executable.validate(0)!
	executable.identifier_table = []Utf16String{}
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Identifier out of range')
	}
	executable.identifier_table = [utf16_string('x')]
	executable.registers_and_locals_count = 5
	if _ := executable.validate(0) {
		assert false
	} else {
		assert err.msg().contains('Register out of range')
	}
}

fn test_validation_snapshots_bound_extra_storage_for_large_executables() {
	count := validation_snapshot_limit / int(sizeof(Instruction)) + 1
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		bytecode_length:            u32(count)
		instructions:               []Instruction{len: count, init: Instruction{ op: .end, lhs: Operand.constant(0) }}
	}
	for _ in 0 .. 3 { executable.validate(0)! }
	assert executable.validation_snapshot == none
}
