module libjs

fn arity_validation_fixture() &Executable {
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

fn warm_arity_validation(executable &Executable) ! {
	for _ in 0 .. 3 { executable.validate(0)! }
	assert executable.validation_snapshot != none
}

fn test_validation_reuses_unchanged_stream_across_safe_argument_counts() {
	defer { diagnose_validation_arity_for_testing(false) }
	for enabled in [false, true] {
		set_validation_arity_for_testing(enabled)
		executable := arity_validation_fixture()
		warm_arity_validation(executable)!
		diagnose_validation_arity_for_testing(true)
		for count in [u32(1), 2, 8, 0, 1] { executable.validate(count)! }
		assert (diagnose_validation_arity_for_testing(false) > 0) == enabled
	}
	set_validation_arity_for_testing(true)
}

fn test_validation_argument_bounds_cover_inputs_writes_and_nested_operands() {
	for enabled in [false, true] {
		set_validation_arity_for_testing(enabled)
		for instruction in [
			Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.argument(2) },
			Instruction{ op: .mov, dst: Operand.argument(2), lhs: Operand.constant(0) },
			Instruction{ op: .get_callee_and_this, dst: Operand.register(5), rhs: Operand.argument(2), identifier: 0 },
			Instruction{ op: .call, dst: Operand.register(5), lhs: Operand.constant(0), rhs: Operand.constant(0), arguments: [Operand.argument(2)] },
		] {
			mut executable := arity_validation_fixture()
			executable.identifier_table = [utf16_string('f')]
			executable.instructions[0] = instruction
			for count in [u32(3), 4, 3, 8] { executable.validate(count)! }
			if _ := executable.validate(2) {
				assert false
			} else {
				assert err.msg().contains('Argument out of range')
			}
			// Same-sized operand replacement must invalidate the old minimum too.
			executable.instructions[0] = Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.argument(4) }
			if _ := executable.validate(3) {
				assert false
			} else {
				assert err.msg().contains('Argument out of range')
			}
			executable.validate(5)!
		}
	}
	set_validation_arity_for_testing(true)
}

fn test_validation_arity_reuse_cannot_hide_frame_layout_overflow() {
	executable := arity_validation_fixture()
	warm_arity_validation(executable)!
	if _ := executable.validate(u32(0xffffffff)) {
		assert false
	} else {
		assert err.msg().contains('overflows')
	}
	executable.validate(1)!
}
