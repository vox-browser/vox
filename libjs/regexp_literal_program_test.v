module libjs

fn test_regexp_literal_reuses_program_with_independent_match_state() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('
		function make() { return /(a+)([0-9]+)/gi; }
		var first = make(), second = make();
		var match = first.exec("xx AA73");
		if (first.lastIndex !== 7 || second.lastIndex !== 0 || match[1] !== "AA") {
			throw "The literal objects must have independent match state";
		}
		[first, second, /(a+)([0-9]+)/g];
	', vm.realm(), 'regexp-literal-program.js', unsafe { nil })!
	result := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100_000})!
	array := result.as_object()
	first_value := array.get(mut vm, PropertyName.from_str('0'))!
	first := first_value.as_object().slots.regexp_object or {
		panic('Missing first RegExp')
	}
	second_value := array.get(mut vm, PropertyName.from_str('1'))!
	second := second_value.as_object().slots.regexp_object or {
		panic('Missing second RegExp')
	}
	other_value := array.get(mut vm, PropertyName.from_str('2'))!
	other := other_value.as_object().slots.regexp_object or {
		panic('Missing RegExp with different flags')
	}
	assert voidptr(first.engine.program) == voidptr(second.engine.program)
	assert voidptr(first.engine.scratch) != voidptr(second.engine.scratch)
	assert voidptr(first.engine.program) != voidptr(other.engine.program)
}
