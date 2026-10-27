module webassembly

@[heap]
struct SourceHostSpanObservation {
mut:
	pointer voidptr
	length  uint
	calls   int
}

fn test_source_host_callable_borrows_actual_inline_and_outline_argument_slots_and_configuration() {
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	observation := &SourceHostSpanObservation{}
	callable := fn [observation] (mut current BinaryMachineConfiguration, span BinaryMachineValueSpan) BinaryMachineResult {
		mut actual := unsafe { &SourceHostSpanObservation(observation) }
		actual.pointer = voidptr(span.data)
		actual.length = span.size
		actual.calls++
		current.regs[0] = *span.at(0)
		mut first := span.at(0)
		unsafe { *first = BinaryMachineValue.from_i32(211) }
		return BinaryMachineResult.from_values([*span.at(span.size - 1)])
	}
	address := store.allocate_host_function(BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, 'span'))?
	for count in [2, 9] {
		mut arguments := BinaryMachineArguments{}
		arguments.ensure_capacity(uint(count))
		for index in 0 .. count {
			arguments.unchecked_append(BinaryMachineValue.from_i32(i32(index + 41)))
		}
		prepared := configuration.prepare_call(address, mut arguments, false)!
		host := prepared.host_function or { panic('actual HostFunction') }
		span := arguments.span()
		mut result := host.invoke(mut configuration, span)
		assert observation.pointer == voidptr(arguments.data())
		assert observation.length == uint(count) && arguments.size() == uint(count)
		assert configuration.regs[0].to_i32() == 41
		assert arguments.at(0).to_i32() == 211
		assert result.values().values[0].to_i32() == count + 40
		mut first := arguments.at(0)
		unsafe { *first = BinaryMachineValue.from_i32(97) }
		mut repeated := host.invoke(mut configuration, span)
		assert configuration.regs[0].to_i32() == 97
		assert arguments.at(0).to_i32() == 211
		assert repeated.values().values[0].to_i32() == count + 40
		arguments.destroy()
	}
	assert observation.calls == 4
}
