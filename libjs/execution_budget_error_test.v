module libjs

fn test_exhausted_entry_preserves_first_stack_while_unwinding_and_resets_for_next_entry() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut previous := js_undefined()
	for name in ['first', 'second'] {
		mut script := Script.parse('function ${name}(){while(true){}}try{${name}()}catch(e){42}', vm.realm(), '${name}.js', unsafe { nil })!
		vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100}) or {
			assert is_throw_completion(err)
			value := thrown_value(err)
			assert value.is_object()
			assert value.as_object().error_message()? == 'LibJS instruction budget exceeded'
			assert value.as_object().slots.error_data?.stack_string(false).contains('${name} (${name}.js:')
			if previous.is_object() { assert voidptr(previous.as_object()) != voidptr(value.as_object()) }
			previous = value
			continue
		}
		assert false, 'An exhausted entry cannot execute a catch body'
	}
}
