module libjs

fn test_exact_context_capacity_preserves_values_arguments_copies_and_stack_accounting() {
	defer { set_exact_context_capacity_for_testing(true) }
	for enabled in [false, true] {
		set_exact_context_capacity_for_testing(enabled)
		for count in [0, 1, 4, 5, 16, 17, 63, 64, 65, 128, 129, 513] {
			mut frame := ExecutionContext.create(u32(count), [Value.from_i32(42)], 2)
			assert frame.values.len == count + 3
			if enabled {
				assert frame.values.cap == frame.values.len
			} else {
				assert frame.values.cap >= frame.values.len
			}
			for index in 0 .. count {
				if index < int(reserved_register_count) {
					assert frame.values[index].is_special_empty_value()
				} else {
					assert frame.values[index].is_undefined()
				}
			}
			assert frame.values[count].number == 42
			frame.set_argument(1, Value.from_i32(21))
			copy := frame.copy()
			assert copy.argument(1).number == 21 && copy.argument(0).is_undefined()
			frame.set_argument(1, Value.from_i32(0))
			assert copy.argument(1).number == 21
		}
		mut stack := InterpreterStack.new()
		mark := stack.top()
		frame := stack.allocate(17, [], 2) or { panic('frame') }
		assert stack.top() - mark == frame_size_in_bytes(19)
		stack.deallocate(mark)
		assert !frame.stack_allocated && stack.depth() == 0
	}
}

fn test_context_capacity_diagnostic_counts_only_physical_reservation_change() {
	defer { set_exact_context_capacity_for_testing(true) }
	mut previous := ContextAllocationActivity{}
	for enabled in [false, true] {
		set_exact_context_capacity_for_testing(enabled)
		diagnose_context_allocation_for_testing(true)
		frame := ExecutionContext.create(17, [], 2)
		assert frame.values.len == 19
		activity := diagnose_context_allocation_for_testing(false)
		assert activity.frames == 1 && activity.slots == 19
		if enabled {
			assert activity.capacity == 19 && activity.capacity < previous.capacity
		} else {
			assert activity.capacity == 64
		}
		previous = activity
	}
}
