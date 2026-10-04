module libjs

fn execute_source_string_reference(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'string-reference.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_source_string_references_read_virtual_length_and_utf16_indices_in_actual_execution() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for source, expected in {
		'"".length;':           '0'
		'"AB".length;':         '2'
		'"AB"[0];':             '"A"'
		'"AB"["1"];':           '"B"'
		'"\\u{1F600}".length;': '2'
	} {
		assert execute_source_string_reference(mut vm, source)!.str() == expected, source
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	first := execute_source_string_reference(mut vm, '"\\u{1F600}"[0];')!
	second := execute_source_string_reference(mut vm, '"\\u{1F600}"[1];')!
	assert first.as_string().utf16_string().data == [u16(0xd83d)]
	assert second.as_string().utf16_string().data == [u16(0xde00)]
}

fn test_source_string_virtual_property_lookup_retains_raw_units_and_bypasses_receiver_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	units := [u16(0xd800), 0, 0xdc00]
	text := Value.from_string(vm.create_string(Utf16String.from_slice(units)))
	// Own virtual properties do not perform [[Get]] on the supplied receiver.
	length := Reference.for_value(text, PropertyName.from_str('length'), Value.from_i32(37), true)
	assert length.get_value(mut vm)!.number == 3
	for index, unit in units {
		reference := Reference.for_value(text, PropertyName.from_str(index.str()), js_null(), false)
		assert reference.get_value(mut vm)!.as_string().utf16_string().data == [unit]
	}
}
