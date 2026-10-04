module webassembly

import libjs

fn source_numeric_divide(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	result := binary_divide_i32(lhs.to_i32(), rhs.to_i32())!
	return BinaryMachineValue.from_i32(result)
}

fn source_numeric_rotate(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_u64(binary_rotate_left_u64(lhs.to_u64(), rhs.to_u64()))
}

fn source_numeric_identity(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(value.to_i64())
}

fn source_numeric_unary_failure(_ BinaryMachineValue) !BinaryMachineValue {
	return error('Original Source operator error')
}

fn numeric_addresses(rhs BinaryRegisterOrStack, lhs BinaryRegisterOrStack) BinarySourcesAndDestination {
	return BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [rhs, lhs, BinaryRegisterOrStack.r6]!
			// Source writes the LHS slot; this separate field is not consumed.
			destination: .r7
		}
	}
}

fn test_source_numeric_binary_operation_routes_actual_slots_in_all_four_source_modes() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	configuration.setup_call_record(3)
	for mix in [BinarySourceAddressMix.all_registers, .all_call_records, .all_stack, .any] {
		addresses := if mix == .all_registers {
			numeric_addresses(.r2, .r3)
		} else if mix == .all_call_records {
			numeric_addresses(.call_record, unsafe { BinaryRegisterOrStack(10) })
		} else if mix == .all_stack {
			numeric_addresses(.stack, .stack)
		} else {
			numeric_addresses(.stack, .r3)
		}
		lhs := BinaryMachineValue.from_i32(-21)
		rhs := BinaryMachineValue.from_i32(3)
		configuration.push_to_destination(mix, lhs, unsafe { addresses.operands.sources[1] })
		configuration.push_to_destination(mix, rhs, unsafe { addresses.operands.sources[0] })
		configuration.regs[7] = BinaryMachineValue.from_i64(791)
		before := configuration.value_stack_.size()
		assert !interpreter.binary_numeric_operation(mut configuration, &addresses, mix, source_numeric_divide)
		assert !interpreter.did_trap()
		actual := configuration.source_value(mix, 1, unsafe { &addresses.operands.sources[0] })
		assert actual.to_i32() == -7
		assert configuration.regs[7].to_i64() == 791
		if mix == .all_stack || mix == .any {
			assert configuration.value_stack_.size() == before - 1
		} else {
			assert configuration.value_stack_.size() == before
		}
		if mix == .all_stack {
			assert configuration.value_stack_.take_last().to_i32() == -7
		}
		assert configuration.value_stack_.is_empty()
	}
}

fn test_source_numeric_binary_failure_consumes_rhs_preserves_lhs_and_replaces_the_trap_reason() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	addresses := numeric_addresses(.stack, .stack)
	lhs := BinaryMachineValue.from_i32(i32(-2147483648))
	configuration.value_stack_.append(lhs)
	configuration.value_stack_.append(BinaryMachineValue.from_i32(-1))
	configuration.ip_ = 73
	interpreter.set_trap_message('Earlier trap')
	assert interpreter.binary_numeric_operation(mut configuration, &addresses, .all_stack, source_numeric_divide)
	assert interpreter.trap().data is string
	assert interpreter.trap().format() == 'Integer division overflow'
	assert configuration.value_stack_.size() == 1
	assert unsafe { *configuration.value_stack_.last() } == lhs
	assert configuration.ip_ == 73
}

fn test_source_numeric_unary_operation_uses_selected_input_without_popping_or_writing_destination() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	addresses := numeric_addresses(.r2, .r3)
	configuration.regs[2] = BinaryMachineValue.from_i32(19)
	configuration.regs[3] = BinaryMachineValue.from_i32(29)
	configuration.regs[6] = BinaryMachineValue{ low: 0xfffffffffffffff9, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_numeric_identity)
	assert configuration.regs[6] == BinaryMachineValue.from_i64(-7)
	assert configuration.regs[2].to_i32() == 19 && configuration.regs[3].to_i32() == 29
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
	configuration.value_stack_.append(BinaryMachineValue.from_i64(31))
	stack_addresses := numeric_addresses(.stack, .stack)
	before := configuration.value_stack_.size()
	assert interpreter.unary_operation(configuration, &stack_addresses, .all_stack, 0, source_numeric_unary_failure)
	assert interpreter.trap().format() == 'Original Source operator error'
	assert configuration.value_stack_.size() == before
	assert configuration.value_stack_.last().to_i64() == 31
}

fn test_source_numeric_binary_success_preserves_existing_trap_and_actual_aliasing_register_order() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	addresses := numeric_addresses(.r2, .r2)
	configuration.regs[2] = BinaryMachineValue.from_u64(1)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_numeric_rotate)
	assert configuration.regs[2].to_u64() == 2
	assert interpreter.trap().format() == 'Retained earlier trap'
}
