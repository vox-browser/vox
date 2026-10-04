module webassembly

fn source_prepare_function(mut store BinaryMachineStore, module_ &Module, type_ BinaryDefinedType) &BinaryMachineModuleInstance {
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ types: [type_] })
	mut contents := instance.contents()
	contents.canonical_types << canonicalize_binary_type(type_, BinaryTypeContext{})
	address := store.allocate_function(instance, module_, &module_.function_bodies[0], 0) or { panic('actual function allocation') }
	contents.functions << address
	return instance
}

fn test_source_prepare_wasm_call_keeps_arguments_adds_typed_locals_and_does_not_wait_for_compilation() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	type_ := BinaryDefinedType{
		kind:       .function_
		parameters: [BinaryValueType{ kind: .i32 }, BinaryValueType{ kind: .i32 }]
		results:    [BinaryValueType{ kind: .i32 }, BinaryValueType{ kind: .i64 }]
	}
	mut module_ := &Module{
		function_bodies: [BinaryFunctionBody.create(0, [
			BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .i64 } },
			BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .f64 } },
			BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .extern_reference } },
			BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .function_reference } },
			BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .i32 } },
		], BinaryExpression{
			instructions:          [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }]
			compiled_instructions: BinaryCompiledInstructions{ cranelift_inlined_locals: 3, max_call_rec_size: 4 }
		})]
	}
	defer { module_.destroy_compilation_control() }
	instance := source_prepare_function(mut store, module_, type_)
	started := module_.try_begin_cranelift_compilation()
	assert started
	mut arguments := BinaryMachineArguments.from_values([
		BinaryMachineValue.from_i32(41),
		BinaryMachineValue.from_i32(73),
	])
	handle := BinaryMachineCallFrameHandle.create(mut configuration)
	prepared := configuration.prepare_call(instance.functions()[0], mut arguments, false)!
	assert prepared.host_function == none
	assert !module_.has_attempted_cranelift_compilation()
	assert !instance.compiled_fn_table_built_
	assert configuration.frame().owns_locals() && configuration.frame().arity() == 2
	assert configuration.owned_locals_stack_[0].size() == 10
	assert configuration.local(0).to_i32() == 41 && configuration.local(1).to_i32() == 73
	assert configuration.local(2).low == 0 && configuration.local(2).high == 0
	assert configuration.local(3).low == 0 && configuration.local(3).high == 0
	assert configuration.local(4).low == 0 && configuration.local(4).high == 3
	assert configuration.local(5).low == 0 && configuration.local(5).high == 2
	for index in u32(6) .. u32(10) {
		assert *configuration.local(index) == BinaryMachineValue{}
	}
	assert arguments.size() == 0 && arguments.capacity() == 3
	assert configuration.call_record_stack_.size() == 4
	module_.finish_cranelift_compilation()
	handle.destroy()
	assert configuration.depth_ == 0 && configuration.call_record_stack_.size() == 0
	assert configuration.call_argument_freelist_.len == 1
}

fn test_source_prepare_host_preserves_owning_record_arguments_and_state_and_missing_address_returns_actual_trap() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	callback := fn (mut current BinaryMachineConfiguration, values []BinaryMachineValue) BinaryMachineResult {
		current.regs[0] = values[0]
		return BinaryMachineResult.from_values([values[0]])
	}
	address := store.allocate_host_function(BinaryMachineHostFunction.create(callback, BinaryMachineFunctionType{}, 'actual'))?
	mut arguments := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(41)])
	prepared := configuration.prepare_call(address, mut arguments, true)!
	mut host := prepared.host_function or { panic('actual host reference') }
	assert host.name() == 'actual'
	actual := store.get_function(address)?
	if actual is BinaryMachineHostFunction {
		assert voidptr(host) == voidptr(unsafe { &actual })
	}
	canonical := canonicalize_binary_type(BinaryDefinedType{ kind: .function_, results: [BinaryValueType{ kind: .i64 }] }, BinaryTypeContext{})
	host.set_defined_type(canonical)
	changed := store.get_function(address)?
	if changed is BinaryMachineHostFunction {
		assert voidptr(changed.defined_type()) == voidptr(canonical)
	}
	assert arguments.size() == 1 && arguments.at(0).to_i32() == 41
	assert configuration.depth_ == 0 && configuration.frame_stack_.len == 0
	for missing in [u64(1), ~u64(0)] {
		configuration.prepare_call(missing, mut arguments, false) or {
			assert err is BinaryMachineTrap
			assert err.msg() == 'Attempt to call nonexistent function by address'
			assert arguments.size() == 1 && configuration.frame_stack_.len == 0
			continue
		}
		assert false
	}
}

fn test_source_prepare_tail_call_releases_old_locals_and_reuses_call_region_before_new_frame() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	type_ := BinaryDefinedType{ kind: .function_ }
	mut module_ := &Module{
		function_bodies: [BinaryFunctionBody.create(0,
			[BinaryLocals{ count: 1, type_: BinaryValueType{ kind: .i32 } }], BinaryExpression{
				instructions:          [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }]
				compiled_instructions: BinaryCompiledInstructions{ cranelift_inlined_locals: 1, max_call_rec_size: 2 }
			})]
	}
	defer { module_.destroy_compilation_control() }
	instance := source_prepare_function(mut store, module_, type_)
	old_expression := &BinaryExpression{
		instructions:          [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }]
		compiled_instructions: BinaryCompiledInstructions{ max_call_rec_size: 9 }
	}
	mut old := BinaryMachineArguments{}
	old.ensure_capacity(8)
	old.unchecked_append(BinaryMachineValue.from_i32(91))
	old_pointer := old.data()
	configuration.depth_++
	configuration.set_frame(.no, instance, mut old, old_expression, 0)
	base := configuration.call_record_base()
	mut arguments := BinaryMachineArguments.from_values([
		BinaryMachineValue.from_i32(41),
		BinaryMachineValue.from_i32(73),
	])
	prepared := configuration.prepare_call(instance.functions()[0], mut arguments, true)!
	assert prepared.host_function == none && configuration.frame_stack_.len == 1
	assert configuration.owned_locals_stack_.len == 1 && configuration.owned_locals_stack_[0].size() == 4
	assert configuration.local(0).to_i32() == 41 && configuration.local(1).to_i32() == 73
	assert *configuration.local(2) == BinaryMachineValue{} && *configuration.local(3) == BinaryMachineValue{}
	assert voidptr(configuration.call_record_base()) == voidptr(base)
	assert configuration.call_record_stack_.size() == 2
	assert configuration.call_argument_freelist_.len == 1
	assert voidptr(configuration.call_argument_freelist_[0].data()) == voidptr(old_pointer)
	assert configuration.depth_ == 0
	configuration.depth_++
	configuration.unwind_impl()
}
