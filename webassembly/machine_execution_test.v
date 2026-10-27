module webassembly

// Recording doubles exercise the source virtual boundary. They are not a
// bytecode interpreter and are never installed in production browser code.
@[heap]
struct SourceExecutionRecorder {
	BinaryMachineInterpreterBase
mut:
	values             []BinaryMachineValue
	trapped            ?BinaryMachineTrap
	trim_labels_to     ?int
	seen_configuration voidptr
	seen_ip            u64
	calls              int
}

fn (mut recorder SourceExecutionRecorder) interpret(mut configuration BinaryMachineConfiguration) {
	recorder.seen_configuration = voidptr(&configuration)
	recorder.seen_ip = configuration.ip_
	recorder.calls++
	for value in recorder.values { configuration.value_stack_.append(value) }
	if length := recorder.trim_labels_to { configuration.label_stack_.trim(length) }
}

fn (recorder &SourceExecutionRecorder) trap() BinaryMachineTrap {
	return recorder.trapped or { panic('recording interpreter has no trap') }
}

fn (recorder &SourceExecutionRecorder) did_trap() bool { return recorder.trapped != none }

fn (mut recorder SourceExecutionRecorder) clear_trap() { recorder.trapped = none }

fn source_execution_install_frame(mut configuration BinaryMachineConfiguration, arity uint) {
	instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{})
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	mut arguments := BinaryMachineArguments{}
	configuration.set_frame(.no, instance, mut arguments, expression, arity)
}

fn test_source_execute_borrows_actual_configuration_extracts_reversed_results_and_retains_caller_stack_and_labels() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	configuration.ip_ = 91
	configuration.value_stack_.append(BinaryMachineValue.from_i32(99))
	configuration.label_stack_ << BinaryMachineLabel.create(0, 17, 0, unsafe { nil })
	source_execution_install_frame(mut configuration, 3)
	configuration.label_stack_ << BinaryMachineLabel.create(0, 28, 0, unsafe { nil })
	label_capacity := configuration.label_stack_.cap
	mut recorder := &SourceExecutionRecorder{ values: [
		BinaryMachineValue.from_i32(10),
		BinaryMachineValue.from_i32(20),
		BinaryMachineValue.from_i32(30),
	] }
	mut result := configuration.execute(mut recorder)
	assert recorder.calls == 1 && recorder.seen_configuration == voidptr(configuration)
	assert recorder.seen_ip == 91
	assert result.values().values == [BinaryMachineValue.from_i32(30), BinaryMachineValue.from_i32(20),
		BinaryMachineValue.from_i32(10)]
	assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i32() == 99
	assert configuration.label_stack_.len == 1 && configuration.label_stack_[0].continuation() == 17
	assert configuration.label_stack_.cap == label_capacity && configuration.frame_stack_.len == 1
}

fn test_source_execute_keeps_original_external_trap_and_all_interpreter_stack_changes_without_cleanup() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	source_execution_install_frame(mut configuration, 1)
	mut original := BinaryExternallyManagedTrap{}
	for index in 0 .. 64 { original.data[index] = u8(index + 17) }
	mut recorder := &SourceExecutionRecorder{ trapped: BinaryMachineTrap{ data: original }, values: [BinaryMachineValue.from_i32(73)] }
	mut result := configuration.execute(mut recorder)
	assert result.is_trap()
	actual := result.trap().data
	if actual is BinaryExternallyManagedTrap {
		assert actual.data == original.data
	} else {
		assert false
	}
	assert configuration.value_stack_.size() == 1 && configuration.label_stack_.len == 1
	assert recorder.did_trap()
	recorder.clear_trap()
	assert !recorder.did_trap()
}

fn test_source_execute_zero_results_and_return_with_an_already_popped_label() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	source_execution_install_frame(mut configuration, 0)
	mut recorder := &SourceExecutionRecorder{ trim_labels_to: 0 }
	mut result := configuration.execute(mut recorder)
	assert !result.is_trap() && result.values().values.len == 0
	assert configuration.value_stack_.is_empty() && configuration.label_stack_.len == 0
}

fn test_source_compiled_execute_pops_single_result_with_or_without_an_output_pointer_and_only_last_label() {
	for arity in [uint(0), 1] {
		for output_present in [false, true] {
			mut store := BinaryMachineStore.create()
			mut configuration := BinaryMachineConfiguration.create(mut store)
			configuration.label_stack_ << BinaryMachineLabel.create(0, 17, 0, unsafe { nil })
			source_execution_install_frame(mut configuration, arity)
			configuration.label_stack_ << BinaryMachineLabel.create(0, 28, 0, unsafe { nil })
			configuration.value_stack_.append(BinaryMachineValue.from_i32(99))
			mut recorder := &SourceExecutionRecorder{}
			if arity == 1 { recorder.values = [BinaryMachineValue.from_i32(73)] }
			mut output := BinaryMachineValue.from_i32(41)
			mut pointer := unsafe { &BinaryMachineValue(nil) }
			if output_present { pointer = &output }
			configuration.execute_for_compiled_call(mut recorder, pointer)!
			assert output.to_i32() == if arity == 1 && output_present { 73 } else { 41 }
			assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i32() == 99
			assert configuration.label_stack_.len == 2 && configuration.label_stack_[1].continuation() == 0
			configuration.destroy()
		}
	}
}

fn test_source_compiled_execute_trap_preserves_output_stack_and_labels_and_empty_labels_are_allowed() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	source_execution_install_frame(mut configuration, 1)
	mut output := BinaryMachineValue.from_i32(41)
	mut recorder := &SourceExecutionRecorder{ trapped: BinaryMachineTrap{ data: BinaryUncaughtException{ address: 91 } }, values: [BinaryMachineValue.from_i32(73)] }
	configuration.execute_for_compiled_call(mut recorder, &output) or {
		assert err is BinaryMachineTrap
		if err is BinaryMachineTrap {
			data := err.data
			if data is BinaryUncaughtException {
				assert data.address == 91
			} else {
				assert false
			}
		}
		assert output.to_i32() == 41 && configuration.value_stack_.size() == 1 && configuration.label_stack_.len == 1
		recorder.clear_trap()
		recorder.values = []
		configuration.label_stack_.clear()
		configuration.execute_for_compiled_call(mut recorder, &output)!
		assert output.to_i32() == 73 && configuration.value_stack_.is_empty() && configuration.label_stack_.len == 0
		return
	}
	assert false
}

fn test_source_call_missing_address_preserves_state_and_host_calls_borrow_arguments_without_entering_interpreter() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	configuration.ip_ = 91
	mut recorder := &SourceExecutionRecorder{}
	mut arguments := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(41)])
	mut missing := configuration.call(mut recorder, 0, mut arguments)
	assert missing.is_trap() && missing.trap().format() == 'Attempt to call nonexistent function by address'
	assert recorder.calls == 0 && configuration.ip_ == 91 && arguments.size() == 1
	callback := fn (mut current BinaryMachineConfiguration, span BinaryMachineValueSpan) BinaryMachineResult {
		current.regs[0] = *span.at(0)
		mut first := span.at(0)
		unsafe { *first = BinaryMachineValue.from_i32(73) }
		return BinaryMachineResult.from_trap(BinaryMachineTrap.from_string('actual host trap'))
	}
	address := store.allocate_host_function(BinaryMachineHostFunction.create(callback, BinaryMachineFunctionType{}, 'actual'))?
	mut result := configuration.call(mut recorder, address, mut arguments)
	assert result.is_trap() && result.trap().format() == 'actual host trap'
	assert recorder.calls == 0 && configuration.ip_ == 91 && configuration.frame_stack_.len == 0
	assert configuration.regs[0].to_i32() == 41 && arguments.at(0).to_i32() == 73
}

fn test_source_wasm_call_prepares_actual_store_frame_resets_ip_and_invokes_supplied_interpreter() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	mut module_ := &Module{ function_bodies: [BinaryFunctionBody.create(0, [], BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] })] }
	defer { module_.destroy_compilation_control() }
	type_ := BinaryDefinedType{ kind: .function_, results: [BinaryValueType{ kind: .i32 }] }
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ types: [type_] })
	mut contents := instance.contents()
	contents.canonical_types << canonicalize_binary_type(type_, BinaryTypeContext{})
	address := store.allocate_function(instance, module_, &module_.function_bodies[0], 0)?
	contents.functions << address
	configuration.ip_ = 91
	mut recorder := &SourceExecutionRecorder{ values: [BinaryMachineValue.from_i32(73)] }
	mut arguments := BinaryMachineArguments.from_values([BinaryMachineValue.from_i32(41)])
	handle := BinaryMachineCallFrameHandle.create(mut configuration)
	mut result := configuration.call(mut recorder, address, mut arguments)
	assert !result.is_trap() && result.values().values == [BinaryMachineValue.from_i32(73)]
	assert recorder.calls == 1 && recorder.seen_ip == 0 && recorder.seen_configuration == voidptr(configuration)
	assert configuration.local(0).to_i32() == 41 && arguments.size() == 0
	assert configuration.value_stack_.is_empty() && configuration.label_stack_.len == 0
	handle.destroy()
	assert configuration.depth_ == 0 && configuration.frame_stack_.len == 0 && configuration.locals_base_ == unsafe { nil }
}
