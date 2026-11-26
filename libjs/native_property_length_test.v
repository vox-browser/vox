module libjs

import os
import platform
import rand

fn length_native_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-length.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_native_lengths_keep_live_arrays_utf16_and_exotic_getters() {
	defer { set_native_lengths_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-length-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut counts := []NativeCodeActivity{}
	for enabled in [false, true] {
		set_native_lengths_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		length_native_run(mut vm, 'function size(x){return x.length}function safely(x){try{return size(x)}catch(e){return e}}size([]);safely([])')!
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.diagnose_native_code(true)!
		for source in [
			'size("")===0&&size("😀")===2&&size("a\\u0000b")===3',
			'var a=[1];size(a)===1&&(a.length=100,size(a)===100)&&(a.length=0,size(a)===0)',
			'var n=0;var p=new Proxy([1,2],{get(t,k,r){n++;return Reflect.get(t,k,r)}});size(p)===2&&n===1',
			'size(new Uint8Array(3))===3&&size(new String("abc"))===3',
			'var o={n:42,get length(){return this.n}};size(o)===42&&safely({get length(){throw 7}})===7',
			'size(function(a,b){})===2&&(safely(null) instanceof TypeError)',
			'(function(a,b){return size(arguments)})(1,2)===2',
		] { assert length_native_run(mut vm, source)!.to_boolean(), source }
		activity := vm.diagnose_native_code(false)!
		assert (activity.native_length_steps > 0) == enabled
		counts << activity
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
		vm.close_native_code()!
	}
	assert counts[0].entries == counts[1].entries
	assert counts[1].fast_steps > counts[0].fast_steps
	assert counts[0].fast_steps + counts[0].slow_steps == counts[1].fast_steps + counts[1].slow_steps
}

fn test_native_lengths_keep_exact_budget_and_compiler_free_reopen() {
	defer { set_native_lengths_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-length-budget-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for mode in 0 .. 3 {
		set_native_lengths_for_testing(true)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function size(x){return x.length}function use(){try{return size([1,2])+size("😀")}finally{}}use()', vm.realm(), 'length-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 4
		stats := vm.compile_native_code(cache, if mode == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (mode != 0)
		set_native_lengths_for_testing(mode == 2)
		vm.use_native_code(mode != 0)!
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

fn test_native_length_guard_rejects_changed_keys_layout_storage_without_allocating() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	key := Value.from_string(vm.create_string_from_str('length'))
	mut executable := &Executable{
		registers_and_locals_count: 8
		constants: [key]
		instructions: [Instruction{op: .get_property, lhs: Operand.register(4), rhs: Operand.constant(0), dst: Operand.register(6)}]
		bytecode_length: 1
	}
	mut frame := ExecutionContext.create(8, executable.constants, 0)
	frame.values[4] = Value.from_string(vm.create_string_from_str('😀'))
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	invocation := NativeInvocation{vm: vm, executable: executable}
	plan := [u32(0), 4, 8, 6, Operand.register(4).raw, Operand.constant(0).raw, Operand.register(6).raw, 8, 1, 0, 0]
	mut result := f64(-1)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 10000 {
		assert native_length_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 1
		assert result == 2
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	frame.values[8] = Value.from_string(vm.create_string_from_str('other'))
	assert native_length_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	frame.values[8] = key
	executable.local_index_base = 1
	assert native_length_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	executable.local_index_base = 0
	assert native_length_read(voidptr(&invocation), plan.data, unsafe { nil }, &result) == 0
	frame.values = []Value{len: 4}
	assert native_length_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	assert result == 2
}
