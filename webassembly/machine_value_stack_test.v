module webassembly

fn test_machine_value_stack_retains_actual_stable_address_and_aliases_last_and_span() {
	mut stack := BinaryMachineValueStack.create()
	base := stack.data()
	assert stack.is_empty() && voidptr(stack.begin()) == voidptr(base) && voidptr(stack.end()) == voidptr(base)
	stack.append(BinaryMachineValue.from_i32(17))
	mut last := stack.last()
	unsafe { *last = BinaryMachineValue.from_i64(99) }
	assert stack.span().at(0).to_i64() == 99
	mark := stack.mark()
	allocated := stack.allocate(2)
	unsafe {
		allocated[0] = BinaryMachineValue.from_i32(2)
		allocated[1] = BinaryMachineValue.from_i32(3)
	}
	assert voidptr(stack.data()) == voidptr(base) && stack.size() == 3
	stack.release_to(mark)
	assert stack.size() == 1 && stack.last().to_i64() == 99
	stack.restore_size(3)
	assert stack.take_last().to_i32() == 3 && stack.unsafe_take_last().to_i32() == 2
	stack.shrink(0, false)
	assert stack.is_empty() && voidptr(stack.data()) == voidptr(base)
	stack.destroy()
}

fn test_machine_value_stack_memmove_and_reset_preserve_source_conservative_scan_slack() {
	mut stack := BinaryMachineValueStack.create()
	stack.reset_and_clear()
	for i in 0 .. 12 { stack.append(BinaryMachineValue.from_i32(i + 1)) }
	assert stack.conservative_scan_size() == 20
	stack.remove(2, 3)
	assert stack.size() == 9 && stack.span().at(2).to_i32() == 6
	assert stack.last().to_i32() == 12
	stack.reset_and_clear()
	assert stack.size() == 0 && stack.conservative_scan_size() == 8
	for i in 0 .. 8 {
		assert unsafe { stack.data()[i] } == BinaryMachineValue{}
	}
	// Source reset clears only the eight slack slots, rather than the mapping.
	assert unsafe { stack.data()[8] }.to_i32() == 12
	stack.ensure_capacity(binary_value_stack_max_values)
	stack.allocate(binary_value_stack_max_values)
	assert stack.size() == binary_value_stack_max_values
	assert stack.conservative_scan_size() == binary_value_stack_max_values
	assert uint(stack.end()) - uint(stack.begin()) == binary_value_stack_reservation_size
	stack.reset_and_clear()
	stack.destroy()
}

fn test_machine_value_stack_recycles_only_four_regions_in_lifo_order_without_implicit_clear() {
	mut stacks := []&BinaryMachineValueStack{}
	for i in 0 .. 6 {
		mut stack := BinaryMachineValueStack.create()
		stack.append(BinaryMachineValue.from_i32(10 + i))
		stacks << stack
	}
	assert binary_stack_region_pool().count == 0
	for stack in stacks { stack.destroy() }
	assert binary_stack_region_pool().count == 4
	mut reused := []&BinaryMachineValueStack{}
	for i in 0 .. 4 {
		stack := BinaryMachineValueStack.create()
		assert voidptr(stack.data()) == voidptr(stacks[3 - i].data())
		assert stack.is_empty() && unsafe { stack.data()[0] }.to_i32() == 13 - i
		reused << stack
	}
	for stack in reused { stack.destroy() }
	assert binary_stack_region_pool().count == 4
	assert BinaryMachineValueStack.base_offset() == 0
	assert BinaryMachineValueStack.top_offset() == sizeof(&BinaryMachineValue)
}

fn machine_stack_thread_pool_probe() uint {
	mut stack := BinaryMachineValueStack.create()
	assert binary_stack_region_pool().count == 0
	pool_address := uint(binary_stack_region_pool())
	stack.append(BinaryMachineValue.from_i32(87))
	assert stack.take_last().to_i32() == 87
	stack.destroy()
	assert binary_stack_region_pool().count == 1
	return pool_address
}

fn test_machine_value_stack_region_pool_is_owned_by_each_native_thread() {
	root_pool := uint(binary_stack_region_pool())
	first := spawn machine_stack_thread_pool_probe()
	second := spawn machine_stack_thread_pool_probe()
	first_pool := first.wait()
	second_pool := second.wait()
	assert first_pool != root_pool && second_pool != root_pool
	assert first_pool != second_pool
}
