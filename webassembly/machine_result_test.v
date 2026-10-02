module webassembly

struct ExternalMachineCompletion {
	kind       u64
	value_low  u64
	value_high u64
}

fn test_machine_traps_preserve_external_completion_bytes_and_exact_format() {
	message := BinaryMachineTrap.from_string('Memory access out of bounds')
	assert message.format() == 'Memory access out of bounds'
	exception := BinaryMachineTrap{ data: BinaryUncaughtException{ address: 19 } }
	assert exception.format() == 'uncaught exception'
	if exception.data is BinaryUncaughtException {
		assert exception.data.address == 19
	} else {
		assert false
	}
	completion := ExternalMachineCompletion{ kind: 3, value_low: 0x7ff800000000cafe, value_high: 17 }
	mut external := BinaryMachineTrap.from_external_object(completion)
	assert external.format() == '<Externally managed Trap Data>'
	assert sizeof(BinaryExternallyManagedTrap) == 64
	if external.data is BinaryExternallyManagedTrap {
		retained := external.data.unsafe_external_object_as[ExternalMachineCompletion]()
		assert retained.kind == 3 && retained.value_low == completion.value_low && retained.value_high == 17
	} else {
		assert false
	}
}

fn test_machine_result_accessors_mutate_the_actual_selected_variant() {
	mut result := BinaryMachineResult.from_values([BinaryMachineValue.from_i64(13)])
	assert !result.is_trap()
	mut values := result.values()
	values.values << BinaryMachineValue.from_i32(21)
	values.values[0] = BinaryMachineValue.from_i64(34)
	assert result.values().values.len == 2
	assert result.values().values[0].to_i64() == 34
	assert result.values().values[1].to_i32() == 21
	mut trapped := BinaryMachineResult.from_trap(BinaryMachineTrap.from_string('before'))
	assert trapped.is_trap()
	mut trap := trapped.trap()
	trap.data = BinaryUncaughtException{ address: 8 }
	assert trapped.trap().format() == 'uncaught exception'
	mut empty := BinaryMachineResult.from_values([]BinaryMachineValue{})
	assert !empty.is_trap() && empty.values().values.len == 0
}

fn test_machine_instantiation_error_retains_start_trap_and_source_defaults() {
	initial := BinaryInstantiationError{}
	assert initial.error == 'Unknown error' && initial.source == .linking
	assert initial.relevant_trap == none
	failed_start := BinaryInstantiationError{ error: 'Start function trapped', source: .start_function, relevant_trap: BinaryMachineTrap.from_string('unreachable') }
	assert failed_start.source == .start_function
	trap := failed_start.relevant_trap or { panic('missing start trap') }
	assert trap.format() == 'unreachable'
	link := BinaryMachineLinkError{ missing_imports: ['env::a', 'env::b'], other_errors: [.invalid_imported_module] }
	assert link.missing_imports == ['env::a', 'env::b'] && link.other_errors == [.invalid_imported_module]
}
