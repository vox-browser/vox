module webassembly

fn test_source_configuration_owner_registers_actual_identity_and_unregisters_before_region_reuse() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	mut other := BinaryMachineConfiguration.create(mut store)
	assert voidptr(configuration.store()) == voidptr(store)
	assert store.active_configurations().entries.len == 2
	assert voidptr(configuration) in store.active_configurations().entries
	assert voidptr(other) in store.active_configurations().entries
	value_region := configuration.value_stack_.data()
	call_region := configuration.call_record_stack_.data()
	assert voidptr(value_region) != voidptr(call_region)
	configuration.destroy()
	assert store.active_configurations().entries.len == 1
	assert voidptr(configuration) !in store.active_configurations().entries
	// Last member destruction is the value stack, so it is reused first.
	mut reused := BinaryMachineConfiguration.create(mut store)
	assert voidptr(reused.value_stack_.data()) == voidptr(value_region)
	assert voidptr(reused.call_record_stack_.data()) == voidptr(call_region)
	reused.destroy()
	other.destroy()
	assert store.active_configurations().entries.len == 0
}

fn test_source_configuration_operand_routing_borrows_and_consumes_actual_slots_in_all_four_modes() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	configuration.setup_call_record(247)
	registers := [BinaryRegisterOrStack.r2, .r5, .r7]!
	records := [BinaryRegisterOrStack.call_record, unsafe { BinaryRegisterOrStack(41) },
		.last_call_record]!
	stack := [BinaryRegisterOrStack.stack, .stack, .stack]!
	for mode in [BinarySourceAddressMix.all_registers, .all_call_records, .all_stack, .any] {
		for index in 0 .. 3 {
			actual := if mode == .all_registers {
				registers
			} else if mode == .all_call_records {
				records
			} else if mode == .all_stack {
				stack
			} else {
				[BinaryRegisterOrStack.r2, .stack, .last_call_record]!
			}
			configuration.push_to_destination(mode, BinaryMachineValue.from_i64(10 + index), actual[index])
			mut borrowed := configuration.source_value(mode, u8(index), &actual[0])
			assert borrowed.to_i64() == i64(10 + index)
			unsafe { *borrowed = BinaryMachineValue.from_i64(70 + index) }
			before := configuration.value_stack_.size()
			taken := configuration.take_source(mode, u8(index), &actual[0])
			assert taken.to_i64() == i64(70 + index)
			if mode == .all_stack || (mode == .any && actual[index] == .stack) {
				assert configuration.value_stack_.size() == before - 1
			} else {
				assert configuration.value_stack_.size() == before
				assert configuration.source_value(mode, u8(index), &actual[0]).to_i64() == taken.to_i64()
			}
		}
	}
	assert configuration.value_stack_.is_empty()
	assert voidptr(configuration.call_record_entry(246)) == voidptr(unsafe { configuration.call_record_base() + 246 })
}

fn test_source_configuration_reset_retains_stack_addresses_vector_capacity_and_count_limit() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	value_region := configuration.value_stack_.data()
	call_region := configuration.call_record_stack_.data()
	configuration.value_stack_.append(BinaryMachineValue.from_i32(9))
	configuration.setup_call_record(2)
	mut entry := configuration.call_record_entry(0)
	unsafe { *entry = BinaryMachineValue.from_i32(8) }
	mut locals := [BinaryMachineValue.from_i32(11), BinaryMachineValue.from_i32(12)]
	configuration.set_locals_base(unsafe { &locals[0] })
	mut local := configuration.local(1)
	unsafe { *local = BinaryMachineValue.from_i32(31) }
	assert locals[1].to_i32() == 31
	configuration.regs[2] = BinaryMachineValue.from_i32(9)
	configuration.depth_ = 17
	configuration.ip_ = 97
	configuration.enable_instruction_count_limit()
	configuration.compiled_call_result_scratch_ = BinaryMachineValue.from_i64(121)
	configuration.label_stack_ << BinaryMachineLabel.create(1, 2, 3, unsafe { nil })
	configuration.owned_locals_stack_ << BinaryMachineArguments.from_values(locals)
	configuration.call_argument_freelist_ << BinaryMachineArguments.from_values(locals)
	label_capacity := configuration.label_stack_.cap
	freelist_capacity := configuration.call_argument_freelist_.cap
	configuration.reset_after_invoke()
	assert configuration.value_stack_.is_empty() && configuration.call_record_stack_.is_empty()
	assert voidptr(configuration.value_stack_.data()) == voidptr(value_region)
	assert voidptr(configuration.call_record_stack_.data()) == voidptr(call_region)
	assert configuration.label_stack_.len == 0 && configuration.label_stack_.cap == label_capacity
	assert configuration.owned_locals_stack_.len == 0 && configuration.call_argument_freelist_.len == 0
	assert configuration.call_argument_freelist_.cap == freelist_capacity
	assert configuration.depth_ == 0 && configuration.ip_ == 0
	assert configuration.locals_base() == unsafe { nil }
	assert configuration.call_record_base() == unsafe { nil }
	assert configuration.memory_instances_ == unsafe { nil } && configuration.global_instances_ == unsafe { nil }
	assert configuration.compiled_call_result_scratch_.to_i64() == 0
	assert configuration.regs == [8]BinaryMachineValue{}
	assert configuration.should_limit_instruction_count()
	assert voidptr(configuration) in store.active_configurations().entries
	for index in 0 .. 8 {
		assert unsafe { value_region[index] } == BinaryMachineValue{}
		assert unsafe { call_region[index] } == BinaryMachineValue{}
	}
}

fn test_source_configuration_reference_accessors_and_machine_offsets_reach_actual_fields() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	mut ip := configuration.ip()
	mut depth := configuration.depth()
	unsafe {
		*ip = 37
		*depth = 5
	}
	assert configuration.ip_ == 37 && configuration.depth_ == 5
	module_ := BinaryMachineModuleInstance.create()
	mut expression := BinaryExpression{}
	configuration.frame_stack_ << BinaryMachineFrame.create(module_, unsafe { nil }, &expression, 3, false)
	mut frame := configuration.frame()
	frame.set_label_index(19)
	assert configuration.frame_stack_[0].label_index() == 19
	mut scratch := configuration.compiled_call_result_scratch()
	unsafe { *scratch = BinaryMachineValue.from_i64(91) }
	assert configuration.compiled_call_result_scratch_.to_i64() == 91
	configuration.setup_call_record(2)
	configuration.set_locals_base(configuration.call_record_base())
	configuration.value_stack_.append(BinaryMachineValue.from_i32(11))
	base := unsafe { &u8(configuration) }
	offsets := [BinaryMachineConfiguration.locals_base_offset(),
		BinaryMachineConfiguration.memory_instances_offset(),
		BinaryMachineConfiguration.global_instances_offset(),
		BinaryMachineConfiguration.value_stack_base_offset(),
		BinaryMachineConfiguration.value_stack_top_offset(),
		BinaryMachineConfiguration.call_record_base_offset()]
	expected := [uint(configuration.locals_base()), uint(configuration.memory_instances_),
		uint(configuration.global_instances_), uint(configuration.value_stack_.data()),
		uint(configuration.value_stack_.end()), uint(configuration.call_record_base())]
	for index, offset in offsets {
		mut actual := uint(0)
		unsafe { C.memcpy(&actual, base + offset, sizeof(uint)) }
		assert actual == expected[index]
	}
	mut actual_scratch := BinaryMachineValue{}
	unsafe { C.memcpy(&actual_scratch, base + BinaryMachineConfiguration.compiled_call_result_scratch_offset(), sizeof(BinaryMachineValue)) }
	assert actual_scratch.to_i64() == 91
}
