module webassembly

fn source_frame_owner(mut store BinaryMachineStore, marker i32) &BinaryMachineModuleInstance {
	type_ := BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 }, mutable_: true }
	address := store.allocate_global(type_, BinaryMachineValue.from_i32(marker)) or { panic('actual global allocation') }
	return BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ globals: [address] })
}

fn source_frame_expression(records uint, dispatches int) &BinaryExpression {
	mut expression := &BinaryExpression{
		instructions:          [BinaryInstruction{ opcode: binary_op_nop },
			BinaryInstruction{ opcode: binary_op_synthetic_end_expression }]
		stack_usage_hint:      uint(5)
		compiled_instructions: BinaryCompiledInstructions{ max_call_rec_size: records, max_label_depth: 71 }
	}
	for _ in 0 .. dispatches { expression.compiled_instructions.dispatches << BinaryDispatch{} }
	return expression
}

fn test_source_owned_frame_installs_real_locals_tables_label_and_call_region_and_handle_restores_caller() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	mut owner := source_frame_owner(mut store, 41)
	expression := source_frame_expression(4, 7)
	configuration.value_stack_.append(BinaryMachineValue.from_i32(19))
	configuration.setup_call_record(3)
	saved_base := configuration.call_record_base()
	saved_mark := configuration.call_record_stack_.mark()
	handle := BinaryMachineCallFrameHandle.create(mut configuration)
	assert configuration.depth_ == 1 && configuration.call_record_base() == unsafe { nil }
	mut locals := BinaryMachineArguments{}
	locals.ensure_capacity(9)
	locals.unchecked_append(BinaryMachineValue.from_i32(73))
	allocation := locals.data()
	configuration.set_frame(.no, owner, mut locals, expression, 2)
	assert locals.size() == 0 && locals.capacity() == 3
	assert configuration.frame().owns_locals() && configuration.frame().arity() == 2
	assert voidptr(configuration.frame().module()) == voidptr(owner)
	assert voidptr(configuration.frame().expression()) == voidptr(expression)
	assert voidptr(configuration.locals_base()) == voidptr(allocation)
	assert configuration.local(0).to_i32() == 73
	assert configuration.global_instances_ == owner.resolved_globals(store)
	assert unsafe { configuration.global_instances_[0].value().to_i32() } == 41
	assert voidptr(configuration.frame().compiled_fn_table()) == voidptr(owner.compiled_fn_table(store))
	assert configuration.frame().label_index() == 0
	assert configuration.label_stack_.len == 1 && configuration.label_stack_.cap >= 71
	label := configuration.label_stack_[0]
	assert label.arity() == 2 && label.stack_height() == 1 && label.continuation() == 6
	assert voidptr(configuration.call_record_base()) == voidptr(saved_mark)
	assert configuration.call_record_stack_.size() == 7
	handle.destroy()
	assert configuration.frame_stack_.len == 0 && configuration.owned_locals_stack_.len == 0
	assert configuration.depth_ == 0 && configuration.locals_base() == unsafe { nil }
	assert configuration.memory_instances_ == unsafe { nil } && configuration.global_instances_ == unsafe { nil }
	assert voidptr(configuration.call_record_base()) == voidptr(saved_base)
	assert configuration.call_record_stack_.size() == 3
	assert configuration.call_argument_freelist_.len == 1
	assert voidptr(configuration.call_argument_freelist_[0].data()) == voidptr(allocation)
	// Source unwind does not pop labels or consume the value stack.
	assert configuration.label_stack_.len == 1 && configuration.value_stack_.size() == 1
}

fn test_source_lightweight_same_module_reuses_cached_table_and_skips_owned_locals_labels_and_zero_record_reset() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	mut owner := source_frame_owner(mut store, 41)
	expression := source_frame_expression(2, 0)
	handle := BinaryMachineCallFrameHandle.create(mut configuration)
	mut locals := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(31)])
	configuration.set_frame(.no, owner, mut locals, expression, 0)
	assert configuration.label_stack_[0].continuation() == 1
	table := configuration.frame().compiled_fn_table()
	owner.compiled_fn_table_built_ = false
	borrowed := [BinaryMachineValue.from_i32(91)]
	record := configuration.call_record_base()
	configuration.depth_++
	configuration.set_frame_lightweight(owner, unsafe { &borrowed[0] }, expression, 1, 0)
	assert !owner.compiled_fn_table_built_
	assert voidptr(configuration.frame().compiled_fn_table()) == voidptr(table)
	assert !configuration.frame().owns_locals() && configuration.frame().label_index() == 0
	assert configuration.local(0).to_i32() == 91
	assert configuration.owned_locals_stack_.len == 1 && configuration.label_stack_.len == 1
	assert voidptr(configuration.call_record_base()) == voidptr(record)
	configuration.unwind_impl()
	assert configuration.depth_ == 1 && configuration.local(0).to_i32() == 31
	assert configuration.call_argument_freelist_.len == 0
	handle.destroy()
	assert configuration.depth_ == 0 && configuration.frame_stack_.len == 0
}

fn test_source_cross_module_unwind_restores_borrowed_caller_and_owned_inline_caller_after_vector_relocation() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	mut first := source_frame_owner(mut store, 41)
	mut second := source_frame_owner(mut store, 73)
	expression := source_frame_expression(0, 0)
	borrowed := [BinaryMachineValue.from_i32(11)]
	configuration.depth_++
	configuration.set_frame_lightweight(first, unsafe { &borrowed[0] }, expression, 0, 2)
	caller_record := configuration.call_record_base()
	handle := BinaryMachineCallFrameHandle.create(mut configuration)
	mut locals := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(23)])
	configuration.set_frame(.no, second, mut locals, expression, 0)
	assert configuration.call_record_base() == unsafe { nil }
	assert unsafe { configuration.global_instances_[0].value().to_i32() } == 73
	handle.destroy()
	assert configuration.depth_ == 1 && configuration.local(0).to_i32() == 11
	assert voidptr(configuration.locals_base()) == voidptr(unsafe { &borrowed[0] })
	assert unsafe { configuration.global_instances_[0].value().to_i32() } == 41
	assert voidptr(configuration.call_record_base()) == voidptr(caller_record)
	configuration.unwind_impl()
	configuration.reset_after_invoke()
	configuration.depth_++
	mut parent := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(97)])
	configuration.set_frame(.no, first, mut parent, expression, 0)
	// Force the actual outer owner vector to relocate its inline local buffers.
	configuration.owned_locals_stack_.ensure_cap(128)
	configuration.depth_++
	mut child := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(101)])
	configuration.set_frame(.no, second, mut child, expression, 0)
	configuration.unwind_impl()
	assert configuration.local(0).to_i32() == 97
	assert voidptr(configuration.locals_base()) == voidptr(configuration.owned_locals_stack_[0].data())
	assert unsafe { configuration.global_instances_[0].value().to_i32() } == 41
	configuration.unwind_impl()
	assert configuration.depth_ == 0 && configuration.owned_locals_stack_.len == 0
}

fn test_source_tail_frame_releases_previous_call_record_before_allocating_replacement() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	owner := source_frame_owner(mut store, 41)
	initial := source_frame_expression(9, 0)
	replacement := source_frame_expression(3, 0)
	mut arguments := BinaryMachineArguments{}
	configuration.depth_++
	configuration.set_frame(.no, owner, mut arguments, initial, 0)
	base := configuration.call_record_base()
	configuration.unwind_impl()
	configuration.depth_++
	configuration.set_frame(.yes, owner, mut arguments, replacement, 0)
	assert voidptr(configuration.call_record_base()) == voidptr(base)
	assert configuration.call_record_stack_.size() == 3
	configuration.unwind_impl()
}
