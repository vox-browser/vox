module libjs

struct OperandSlotFailure {
	operand Operand
	writing bool
	message string
}

fn test_operand_slot_preserves_offsets_and_validation() {
	mut executable := &Executable{
		registers_and_locals_count: 7
		local_index_base:           5
		local_variable_names:       [utf16_string('a'), utf16_string('b')]
		constants:                  [Value.from_i32(41), Value.from_i32(42)]
	}
	assert Operand.register(6).slot(executable, 2, true)! == 6
	assert Operand.local(1).slot(executable, 2, true)! == 6
	assert Operand.constant(1).slot(executable, 2, false)! == 8
	assert Operand.argument(1).slot(executable, 2, true)! == 10
	for invalid in [
		OperandSlotFailure{Operand.register(7), false, 'Register out of range'},
		OperandSlotFailure{Operand.local(2), false, 'Local out of range'},
		OperandSlotFailure{Operand.constant(1), true, 'Cannot write to a constant operand'},
		OperandSlotFailure{Operand.constant(2), false, 'Constant out of range'},
		OperandSlotFailure{Operand.argument(2), false, 'Argument out of range'},
		OperandSlotFailure{Operand{ raw: u32(4) << 29 }, false, 'Invalid bytecode operand 2147483648'},
		OperandSlotFailure{Operand{}, false, 'Invalid bytecode operand 4294967295'},
	] {
		if _ := invalid.operand.slot(executable, 2, invalid.writing) {
			assert false, 'Expected ${invalid.message}'
		} else {
			assert err.msg() == invalid.message
		}
	}
	executable.local_index_base = 6
	if _ := Operand.local(1).slot(executable, 2, true) {
		assert false, 'Expected a local whose mapped slot exceeds the frame to fail'
	} else {
		assert err.msg() == 'Local out of range'
	}
}

// The dispatch loop resolves operands of a validated executable without the
// checks: every valid operand of each kind maps to the same frame slot.
fn test_validated_operand_slots_match_checked_slots() {
	executable := &Executable{
		registers_and_locals_count: 7
		local_index_base:           5
		local_variable_names:       [utf16_string('a'), utf16_string('b')]
		constants:                  [Value.from_i32(41), Value.from_i32(42)]
	}
	mut operands := []Operand{}
	for index in u32(0) .. 7 { operands << Operand.register(index) }
	for index in u32(0) .. 2 {
		operands << Operand.local(index)
		operands << Operand.constant(index)
	}
	for index in u32(0) .. 3 { operands << Operand.argument(index) }
	for operand in operands {
		assert operand.validated_slot(executable) == operand.slot(executable, 3, false)!
	}
}

// The dispatch loop's per-opcode tables agree with the definitions for every
// opcode, which run in declaration order from mov to nop.
fn test_opcode_operand_tables_match_instruction_definitions() {
	assert opcode_operand_facts.input_counts.len == int(OpCode.nop) + 1
	for index in 0 .. int(OpCode.nop) + 1 {
		instruction := Instruction{
			op: unsafe { OpCode(index) }
		}
		assert instruction.dispatch_input_count() == instruction.input_count()
		assert instruction.dispatch_writes_operand() == instruction.writes_operand()
	}
}
