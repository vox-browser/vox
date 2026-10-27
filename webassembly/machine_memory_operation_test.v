module webassembly

import libjs

fn test_source_memory_store_writes_live_storage_at_edges_and_preserves_existing_trap() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut memory := BinaryMachineMemoryInstance.create(WasmLimits{ minimum: 1, maximum: u64(2) })!
	defer { memory.destroy() }
	payload := [u8(0x80), 0, 0xff, 0x41]!
	bytes := BinaryMachineBytes{ data: unsafe { &payload[0] }, size: 4 }
	interpreter.set_trap_message('Earlier trap')
	assert !interpreter.store_to_memory_instance(mut memory, 0, bytes)
	end := u64(memory.size()) - 4
	assert !interpreter.store_to_memory_instance(mut memory, end, bytes)
	for i in 0 .. 4 {
		assert unsafe { memory.data().data()[i] } == payload[i]
		assert unsafe { memory.data().data()[uint(end) + uint(i)] } == payload[i]
	}
	assert interpreter.trap().format() == 'Earlier trap'
	assert !interpreter.store_to_memory_instance(mut memory, u64(memory.size()), BinaryMachineBytes{})
	assert memory.grow(uint(page_size), .yes, .no)
	assert !interpreter.store_to_memory_instance(mut memory, u64(memory.size()) - 4, bytes)
	assert unsafe { memory.data().data()[memory.size() - 4] } == 0x80
	assert interpreter.trap().format() == 'Earlier trap'
	mut empty := BinaryMachineMemoryInstance.create(WasmLimits{ address_type: .i64, maximum: u64(0) })!
	defer { empty.destroy() }
	assert !interpreter.store_to_memory_instance(mut empty, 0, BinaryMachineBytes{})
}

fn test_source_memory_store_checked_end_and_offset_reject_before_touching_live_storage() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut memory := BinaryMachineMemoryInstance.create(WasmLimits{ minimum: 1, maximum: u64(1) })!
	defer { memory.destroy() }
	payload := [u8(0xff), 0x80, 0, 0x41]!
	bytes := BinaryMachineBytes{ data: unsafe { &payload[0] }, size: 4 }
	mut buffer := memory.data()
	buffer.fill(0, u8(0x79), memory.size())
	for address in [u64(memory.size()) - 3, u64(memory.size()), u64(memory.size()) + 1, u64(-1) - 2,
		u64(-1)] {
		interpreter.set_trap_message('Earlier trap')
		assert interpreter.store_to_memory_instance(mut memory, address, bytes)
		assert interpreter.trap().format() == 'Memory access out of bounds'
		for i in 0 .. int(memory.size()) {
			assert unsafe { buffer.data()[i] } == 0x79
		}
	}
	assert interpreter.store_to_memory_instance(mut memory, u64(memory.size()) + 1, BinaryMachineBytes{})
	assert interpreter.trap().format() == 'Memory access out of bounds'
}

fn test_source_memory_store_resolves_actual_frame_memory_and_retains_memory64_address_width() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	first_address := store.allocate_memory(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(1) })?
	second_address := store.allocate_memory(WasmLimits{ minimum: 1, maximum: u64(1) })?
	mut first := store.unsafe_get_memory(first_address)
	mut second := store.unsafe_get_memory(second_address)
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer {
		configuration.destroy()
		first.destroy()
		second.destroy()
	}
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ memories: [
		second_address,
		first_address,
	] })
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	configuration.set_frame_lightweight(owner, unsafe { nil }, expression, 0, 0)
	configuration.ip_ = 73
	configuration.value_stack_.append(BinaryMachineValue.from_i32(91))
	payload := [u8(0x80), 0, 0xff, 0x41]!
	bytes := BinaryMachineBytes{ data: unsafe { &payload[0] }, size: 4 }
	// Both module indices differ from their Store addresses. Resolve through
	// the real current frame rather than assuming the memory index is an address.
	assert !interpreter.store_to_memory(mut configuration, BinaryMemoryArgument{ memory_index: 1, offset: 7, align: 31 }, bytes, BinaryMachineValue.from_u64(2))
	assert unsafe { first.data().data()[9] } == 0x80
	assert unsafe { second.data().data()[9] } == 0
	assert !interpreter.store_to_memory(mut configuration, BinaryMemoryArgument{ memory_index: 0, offset: 3 }, bytes, BinaryMachineValue.from_u64(0x100000002))
	assert unsafe { second.data().data()[5] } == 0x80
	assert binary_machine_memory_base_address(second, BinaryMachineValue.from_i32(-1)) == 0xffffffff
	assert binary_machine_memory_base_address(first, BinaryMachineValue.from_i32(-1)) == u64(-1)
	assert interpreter.store_to_memory(mut configuration, BinaryMemoryArgument{ memory_index: 1 }, bytes, BinaryMachineValue.from_u64(0x100000002))
	assert interpreter.trap().format() == 'Memory access out of bounds'
	assert unsafe { first.data().data()[2] } == 0
	assert interpreter.store_to_memory(mut configuration, BinaryMemoryArgument{ memory_index: 1, offset: 1 }, bytes, BinaryMachineValue.from_u64(u64(-1)))
	assert interpreter.trap().format() == 'Memory access out of bounds'
	assert interpreter.store_to_memory(mut configuration, BinaryMemoryArgument{ memory_index: 0, offset: u64(-1) }, bytes, BinaryMachineValue.from_i32(-1))
	assert configuration.ip_ == 73 && configuration.value_stack_.size() == 1
	assert configuration.value_stack_.last().to_i32() == 91
}
