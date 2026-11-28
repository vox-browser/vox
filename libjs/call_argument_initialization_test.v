module libjs

import os
import rand

fn test_bulk_call_arguments_preserve_prefix_partial_tail_and_heap_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	values := [Value.from_i32(42), Value.from_string(vm.create_string_from_str('owned')), Value.from_object(Object.create(vm.realm(), none)), js_null(), Value.from_bool(true), Value.from_f64(-0.0)]
	for prefix in 0 .. 8 {
		for argc in 0 .. 8 {
			limit := if argc < values.len { argc } else { values.len }
			for count in 0 .. limit + 1 {
				mut expected := ExecutionContext{values: []Value{len: prefix + argc, init: Value.from_i32(99)}, argument_count: u32(argc)}
				mut actual := ExecutionContext{values: expected.values.clone(), argument_count: u32(argc)}
				for index, value in values[..count] { expected.set_argument(u32(index), value) }
				assert actual.initialize_call_arguments(values[..count])
				for index, value in expected.values { assert same_value(value, actual.values[index]) }
			}
		}
	}
	mut invalid := ExecutionContext{values: [Value.from_i32(7)], argument_count: 2}
	assert !invalid.initialize_call_arguments([Value.from_i32(1)])
	assert invalid.values[0].number == 7
	invalid.argument_count = 1
	assert !invalid.initialize_call_arguments(values)
	assert invalid.values[0].number == 7
	mut empty := ExecutionContext{}
	assert empty.initialize_call_arguments([]Value{})
}

fn test_bulk_call_arguments_preserve_forward_aliasing_order() {
	for count in [1, 4, 6] {
		for prefix in 0 .. 9 {
			for start in 0 .. 17 - count {
				mut expected := ExecutionContext{values: []Value{len: 16}, argument_count: u32(16 - prefix)}
				for index in 0 .. expected.values.len { expected.values[index] = Value.from_i32(i32(index + 100)) }
				mut actual := ExecutionContext{values: expected.values.clone(), argument_count: expected.argument_count}
				for index, value in expected.values[start..start + count] { expected.set_argument(u32(index), value) }
				assert actual.initialize_call_arguments(actual.values[start..start + count])
				for index, value in expected.values { assert same_value(value, actual.values[index]) }
			}
		}
	}
}

fn test_bulk_call_arguments_keep_budget_unwinding_and_native_cache_reopen() {
	defer { set_direct_call_arguments_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-argument-copy-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut all := [][]string{}
	for mode in 0 .. 3 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function add(a,b){return a+b}function use(){try{return add.apply(null,[40,2])}finally{}}use()', vm.realm(), 'argument-copy-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		stats := vm.compile_native_code(cache, if mode == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (mode != 0)
		vm.use_native_code(mode != 0)!
		set_direct_call_arguments_for_testing(mode == 2)
		mut samples := []string{}
		for budget in 1 .. 140 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) {
				samples << value.str()
			} else {
				assert is_throw_completion(err)
				samples << thrown_value(err).as_object().error_message() or { '' }
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert vm.interpreter_stack().native_depth == 0 && !vm.instruction_budget_active
		}
		all << samples
		vm.close_native_code()!
	}
	assert all[0] == all[1] && all[1] == all[2]
}
