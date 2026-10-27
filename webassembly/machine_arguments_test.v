module webassembly

fn source_arguments_frame(mut configuration BinaryMachineConfiguration, minimum uint) {
	module_ := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
		minimum_call_record_size: minimum
	})
	expression := &BinaryExpression{}
	configuration.frame_stack_ << BinaryMachineFrame.create(module_, unsafe { nil }, expression, 0, false)
}

fn source_heap_arguments(capacity uint, marker i32) BinaryMachineArguments {
	mut arguments := BinaryMachineArguments{}
	arguments.ensure_capacity(capacity)
	arguments.unchecked_append(BinaryMachineValue.from_i32(marker))
	return arguments
}

fn test_source_argument_vector_inline_and_outline_moves_preserve_actual_values_and_ownership() {
	mut inline := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(41),
		BinaryMachineValue.from_reference(BinaryExternReference{ address: 71 })])
	assert inline.capacity() == 3 && inline.size() == 2
	assert voidptr(inline.data()) == voidptr(unsafe { &inline.inline_values[0] })
	before := inline.data()
	mut moved := BinaryMachineArguments.move_construct(mut inline)
	defer { moved.destroy() }
	assert inline.size() == 0 && inline.capacity() == 3
	assert voidptr(moved.data()) != voidptr(before)
	assert moved.at(0).to_i32() == 41 && moved.at(1).low == 71 && moved.at(1).high == 1
	mut slot := moved.at(0)
	unsafe { *slot = BinaryMachineValue.from_i32(99) }
	moved.ensure_capacity(8)
	assert moved.capacity() == 8 && moved.at(0).to_i32() == 99 && moved.at(1).high == 1
	heap := moved.data()
	mut outline := BinaryMachineArguments.move_construct(mut moved)
	defer { outline.destroy() }
	assert voidptr(outline.data()) == voidptr(heap)
	assert moved.capacity() == 3 && moved.size() == 0
	outline.move_assign(mut outline)
	assert voidptr(outline.data()) == voidptr(heap) && outline.size() == 2
	outline.clear_with_capacity()
	assert outline.size() == 0 && outline.capacity() == 8 && voidptr(outline.data()) == voidptr(heap)
}

fn test_source_argument_reuse_chooses_first_sufficient_allocation_before_cached_minimum() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	source_arguments_frame(mut configuration, 40)
	mut first := source_heap_arguments(8, 1)
	mut second := source_heap_arguments(10, 2)
	mut third := source_heap_arguments(12, 3)
	second_pointer := second.data()
	configuration.release_arguments_allocation(mut first)
	configuration.release_arguments_allocation(mut second)
	configuration.release_arguments_allocation(mut third)
	mut arguments := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(91)])
	defer { arguments.destroy() }
	configuration.get_arguments_allocation_if_possible(mut arguments, 9)
	assert arguments.capacity() == 10 && arguments.size() == 0
	assert voidptr(arguments.data()) == voidptr(second_pointer)
	assert configuration.call_argument_freelist_.len == 2
	assert configuration.call_argument_freelist_[0].capacity() == 8
	assert configuration.call_argument_freelist_[1].capacity() == 12
	// Already outline, and static requests, do not consume another allocation.
	configuration.get_arguments_allocation_if_possible(mut arguments, 100)
	assert arguments.capacity() == 10 && configuration.call_argument_freelist_.len == 2
	mut small := BinaryMachineArguments{}
	configuration.get_arguments_allocation_if_possible(mut small, 3)
	assert small.capacity() == 3 && configuration.call_argument_freelist_.len == 2
}

fn test_source_argument_reuse_takes_last_then_grows_and_caps_retained_allocations_at_sixteen() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	source_arguments_frame(mut configuration, 40)
	mut first := source_heap_arguments(4, 1)
	mut last := source_heap_arguments(5, 2)
	configuration.release_arguments_allocation(mut first)
	configuration.release_arguments_allocation(mut last)
	mut arguments := BinaryMachineArguments{}
	configuration.get_arguments_allocation_if_possible(mut arguments, 6)
	assert arguments.capacity() == 40 && arguments.size() == 0
	assert configuration.call_argument_freelist_.len == 1
	assert configuration.call_argument_freelist_[0].capacity() == 4
	configuration.release_arguments_allocation(mut arguments)
	assert arguments.capacity() == 3 && arguments.size() == 0
	for index in 0 .. 14 {
		mut next := source_heap_arguments(uint(6 + index), index)
		configuration.release_arguments_allocation(mut next)
		assert next.capacity() == 3 && next.size() == 0
	}
	assert configuration.call_argument_freelist_.len == 16
	mut excess := source_heap_arguments(53, 5)
	defer { excess.destroy() }
	excess_pointer := excess.data()
	configuration.release_arguments_allocation(mut excess)
	assert configuration.call_argument_freelist_.len == 16
	assert excess.capacity() == 53 && excess.size() == 0 && voidptr(excess.data()) == voidptr(excess_pointer)
	mut inline := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(7)])
	configuration.release_arguments_allocation(mut inline)
	assert inline.capacity() == 3 && inline.size() == 0 && configuration.call_argument_freelist_.len == 16
	configuration.reset_after_invoke()
	assert configuration.call_argument_freelist_.len == 0
}
