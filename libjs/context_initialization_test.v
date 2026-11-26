module libjs

import os
import platform
import rand

fn legacy_context_prefix(mut context ExecutionContext, registers u32, constants []Value) {
	reserved := if registers < reserved_register_count { registers } else { reserved_register_count }
	for index in 0 .. int(reserved) { context.values[index] = js_special_empty_value() }
	for index, value in constants { context.values[int(registers) + index] = value }
}

fn assert_context_values_equal(left []Value, right []Value) {
	assert left.len == right.len
	for index, value in left {
		assert value.tag == right[index].tag
		if !value.is_special_empty_value() { assert same_value(value, right[index]) }
	}
}

fn test_direct_context_initialization_matches_reserved_constants_and_argument_boundaries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	constants := [Value.from_i32(42), Value.from_string(vm.create_string_from_str('owned')), Value.from_object(Object.create(vm.realm(), none)), js_null(), js_undefined()]
	for registers in 0 .. 10 {
		for count in 0 .. constants.len + 1 {
			mut expected := ExecutionContext{values: []Value{len: registers + count + 3, init: Value.from_i32(99)}}
			mut actual := ExecutionContext{values: expected.values.clone(), program_counter: 17, frame_id: 42}
			legacy_context_prefix(mut expected, u32(registers), constants[..count])
			assert actual.initialize_reused_values(u32(registers), constants[..count])
			assert_context_values_equal(expected.values, actual.values)
			assert actual.program_counter == 17 && actual.frame_id == 42
		}
	}
	mut empty := ExecutionContext{}
	assert empty.initialize_reused_values(0, []Value{})
	mut short := ExecutionContext{values: [Value.from_i32(1), Value.from_i32(2)]}
	assert !short.initialize_reused_values(3, []Value{})
	assert !short.initialize_reused_values(2, [Value.from_i32(3)])
	assert short.values[0].number == 1 && short.values[1].number == 2
}

fn test_direct_context_initialization_preserves_forward_copy_for_aliasing_constants() {
	for registers in [u32(0), 2, 5, 6] {
		for start in 0 .. 9 {
			mut expected := ExecutionContext{values: []Value{len: 16}}
			for index in 0 .. expected.values.len { expected.values[index] = Value.from_i32(i32(index + 100)) }
			mut actual := ExecutionContext{values: expected.values.clone()}
			legacy_context_prefix(mut expected, registers, expected.values[start..start + 4])
			assert actual.initialize_reused_values(registers, actual.values[start..start + 4])
			assert_context_values_equal(expected.values, actual.values)
		}
	}
}

fn test_direct_context_initialization_keeps_reuse_counts_and_retains_no_per_call_storage() {
	defer { set_direct_context_initialization_for_testing(true) }
	for direct in [false, true] {
		set_direct_context_initialization_for_testing(direct)
		mut stack := InterpreterStack.new()
		constants := [Value.from_i32(42)]
		stack.allocate_reusable(6, constants, 2) or { panic('warm') }
		stack.deallocate(0)
		diagnose_context_reuse_for_testing(true)
		before := platform.thread_arena_usage().used
		for _ in 0 .. 10000 {
			frame := stack.allocate_reusable(6, constants, 2) or { panic('reuse') }
			assert frame.values[0].is_special_empty_value() && frame.values[6].number == 42
			assert frame.values[5].is_undefined() && frame.argument(0).is_undefined()
			stack.deallocate(0)
		}
		$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
		activity := diagnose_context_reuse_for_testing(false)
		assert activity.reused == 10000 && activity.allocated == 0 && activity.exposed == 0
		assert activity.direct_initializations == if direct { u64(10000) } else { u64(0) }
		assert stack.depth() == 0 && stack.top() == 0
	}
}

fn test_direct_context_initialization_keeps_native_and_interpreted_budget_unwinding() {
	defer { set_direct_context_initialization_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-context-init-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for mode in 0 .. 3 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function compute(x){var text="owned";if(x)return x+1;throw text}function use(){try{return compute(41)}finally{}}use()', vm.realm(), 'context-init-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		stats := vm.compile_native_code(cache, if mode == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (mode != 0)
		vm.use_native_code(mode != 0)!
		set_direct_context_initialization_for_testing(mode == 2)
		mut samples := []string{}
		for budget in 1 .. 120 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) {
				samples << value.str()
			} else {
				assert is_throw_completion(err)
				samples << thrown_value(err).as_object().error_message() or { '' }
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert vm.interpreter_stack().native_depth == 0 && !vm.instruction_budget_active
		}
		results << samples
		vm.close_native_code()!
	}
	assert results[0] == results[1] && results[1] == results[2]
}
