module webassembly

import libjs

fn test_source_branch_preserves_target_arity_raw_values_and_actual_configuration_owners() {
	for adjust in [true, false] {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		defer { configuration.destroy() }
		owner := BinaryMachineModuleInstance.create()
		expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
		mut locals := BinaryMachineArguments{}
		configuration.set_frame(.no, owner, mut locals, expression, 0)
		configuration.label_stack_ << BinaryMachineLabel.create(2, 91, 1, unsafe { nil })
		configuration.label_stack_ << BinaryMachineLabel.create(0, 92, 2, unsafe { nil })
		configuration.label_stack_ << BinaryMachineLabel.create(0, 93, 3, unsafe { nil })
		values := [BinaryMachineValue.from_i64(-17), BinaryMachineValue.from_i32(777),
			BinaryMachineValue.from_i32(888), BinaryMachineValue{ low: 0x7ff8000000001234 },
			BinaryMachineValue.from_reference(BinaryExternReference{ address: 29 })]
		for value in values { configuration.value_stack_.append(value) }
		configuration.ip_ = 73
		configuration.regs[0] = BinaryMachineValue.from_i32(41)
		interpreter.set_trap_message('Earlier trap')
		assert interpreter.branch_to_label(mut configuration, adjust, 2, 73, true) == 90
		assert configuration.label_stack_.len == 2
		assert configuration.label_stack_[1].continuation() == 91
		expected := if adjust { [values[0], values[3], values[4]] } else { values }
		assert configuration.value_stack_.size() == uint(expected.len)
		for i, value in expected {
			assert unsafe { configuration.value_stack_.data()[i] } == value
		}
		assert configuration.frame_stack_.len == 1 && configuration.ip_ == 73
		assert configuration.frame().module() == owner
		assert configuration.regs[0].to_i32() == 41
		assert interpreter.trap().format() == 'Earlier trap'
	}
}

fn test_source_unselected_branch_keeps_labels_operands_and_the_callers_current_ip() {
	for adjust in [true, false] {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		defer { configuration.destroy() }
		configuration.label_stack_ << BinaryMachineLabel.create(0, 91, 0, unsafe { nil })
		configuration.label_stack_ << BinaryMachineLabel.create(0, 92, 0, unsafe { nil })
		value := BinaryMachineValue.from_i64(-29)
		configuration.value_stack_.append(value)
		assert interpreter.branch_to_label(mut configuration, adjust, 1, 0xffff_ffff, false) == 0xffff_ffff
		assert configuration.label_stack_.len == 2
		assert configuration.label_stack_[1].continuation() == 92
		assert configuration.value_stack_.size() == 1
		assert *configuration.value_stack_.last() == value
	}
}

fn test_source_zero_arity_same_label_branch_keeps_prefix_and_wraps_the_continuation() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	configuration.label_stack_ << BinaryMachineLabel.create(0, 0, 1, unsafe { nil })
	configuration.value_stack_.append(BinaryMachineValue.from_i32(303))
	configuration.value_stack_.append(BinaryMachineValue.from_i32(777))
	assert interpreter.branch_to_label(mut configuration, true, 0, 73, true) == 0xffff_ffff
	assert configuration.label_stack_.len == 1
	assert configuration.value_stack_.size() == 1
	assert configuration.value_stack_.last().to_i32() == 303
}
