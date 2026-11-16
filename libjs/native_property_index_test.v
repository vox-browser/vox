module libjs

import os
import platform
import rand

fn index_native_run(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-index.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_native_indices_read_live_data_and_fall_back_for_holes_coercion_and_exotics() {
	defer { set_native_indices_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-index-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut counts := []NativeCodeActivity{}
	for enabled in [false, true] {
		set_native_indices_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		index_native_run(mut vm, 'function at(o,k){return o[k]}function zero(o){return o[0]}function safe(o,k){try{return at(o,k)}catch(e){return e}}at([1],0);zero([1]);safe([1],0)')!
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.diagnose_native_code(true)!
		for source in [
			'var a=[1];at(a,0)===1&&(a[0]="live",zero(a)==="live")',
			'var a=[42];delete a[0];var n=0;Object.setPrototypeOf(a,{get 0(){n++;return 7}});at(a,0)===7&&n===1',
			'at(Object.create({0:42}),0)===42&&at([,],0)===undefined',
			'var n=0;var p=new Proxy([42],{get(t,k,r){n++;return Reflect.get(t,k,r)}});at(p,0)===42&&n===1',
			'at(new Uint8Array([42]),0)===42&&at("abc",1)==="b"&&at(new String("abc"),1)==="b"',
			'var n=0;var k={toString(){n++;return "0"}};at([42],k)===42&&n===1',
			'var n=0;safe(null,{toString(){n++;return "0"}});n===0',
			'safe({get 0(){throw 7}},0)===7',
			'var a={0:42,"-1":7,"1.5":8,"NaN":9,"Infinity":10,"4294967295":11};at(a,-0)===42&&at(a,-1)===7&&at(a,1.5)===8&&at(a,NaN)===9&&at(a,Infinity)===10&&at(a,4294967295)===11&&at(a,0n)===42',
			'var a=[];for(var i=0;i<25;i++)a[i]=i;at(a,24)===24&&(delete a[0],at(a,24)===24)&&(a[24]="changed",at(a,24)==="changed")',
		] { assert index_native_run(mut vm, source)!.to_boolean(), source }
		activity := vm.diagnose_native_code(false)!
		assert (activity.native_index_steps > 0) == enabled
		counts << activity
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
		vm.close_native_code()!
	}
	assert counts[0].entries == counts[1].entries
	assert counts[1].fast_steps - counts[0].fast_steps == counts[1].native_index_steps
	assert counts[0].fast_steps + counts[0].slow_steps == counts[1].fast_steps + counts[1].slow_steps
}

fn test_native_indices_keep_exact_budgets_and_compiler_free_fresh_vm_reuse() {
	defer { set_native_indices_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-index-budget-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for mode in 0 .. 3 {
		set_native_indices_for_testing(true)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function at(o,k){return o[k]}function use(){try{return at([42],0)}finally{}}use()', vm.realm(), 'index-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		stats := vm.compile_native_code(cache, if mode == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (mode != 0)
		set_native_indices_for_testing(mode == 2)
		vm.use_native_code(mode != 0)!
		mut samples := []string{}
		for budget in 1 .. 100 {
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

fn test_native_index_guard_uses_owned_values_without_allocation_and_rejects_changed_inputs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_number(0), Value.from_i32(42), attribute_writable | attribute_enumerable | attribute_configurable)
	mut executable := &Executable{
		registers_and_locals_count: 8
		constants: [Value.from_i32(0)]
		instructions: [Instruction{op: .get_property, lhs: Operand.register(4), rhs: Operand.constant(0), dst: Operand.register(6)}]
		bytecode_length: 1
	}
	mut frame := ExecutionContext.create(8, executable.constants, 0)
	frame.values[4] = Value.from_object(object)
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	invocation := NativeInvocation{vm: vm, executable: executable}
	plan := [u32(0), 4, 8, 6, Operand.register(4).raw, Operand.constant(0).raw, Operand.register(6).raw, 8, 1, 0, 0]
	mut result := js_undefined()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 10000 {
		assert native_index_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 1
		assert result.number == 42
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	frame.values[8] = Value.from_f64(0.5)
	assert native_index_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	frame.values[8] = Value.from_i32(0)
	executable.local_index_base = 1
	assert native_index_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	executable.local_index_base = 0
	assert native_index_read(voidptr(&invocation), plan.data, unsafe { nil }, &result) == 0
	object.define_direct_accessor(PropertyName.from_number(0), none, none, attribute_configurable)
	assert native_index_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	frame.values = []Value{len: 4}
	assert native_index_read(voidptr(&invocation), plan.data, frame.values.data, &result) == 0
	assert result.number == 42
}
