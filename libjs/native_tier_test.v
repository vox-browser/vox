module libjs

import os
import rand

fn native_test_script(mut vm VM, source string) !&Script {
	return Script.parse(source, vm.realm(), 'native-tier-test.js', unsafe { nil })
}

fn native_test_run(mut vm VM, source string) !Value {
	mut script := native_test_script(mut vm, source)!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn native_test_cache() string {
	return os.join_path(os.temp_dir(), 'vox-native-test-' + rand.uuid_v4())
}

fn test_native_code_preserves_dynamic_types_properties_calls_and_exceptions() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	native_test_run(mut vm, 'function add(a,b){return a+b} function read(o){return o.x} function invoke(f){return f()} function caught(f){try{return f()}catch(e){return e}} function truth(x){if(x)return 1;return 2} function num(x){return -x} add(1,2);read({x:1});invoke(function(){return 1});caught(function(){throw 7});truth(1);num(1)')!
	stats := vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	assert stats.compiled_executables > 5
	assert stats.fast_instructions > 0
	vm.diagnose_native_code(true)!
	assert native_test_run(mut vm, 'add("a","b")')!.as_string().str() == 'ab'
	assert native_test_run(mut vm, 'add(4n,5n)')!.as_bigint().big_integer.str() == '9'
	assert native_test_run(mut vm, 'var o={x:2};read(o);o.x="changed";read(o)')!.as_string().str() == 'changed'
	assert native_test_run(mut vm, 'invoke(function(){return "new function"})')!.as_string().str() == 'new function'
	assert native_test_run(mut vm, 'caught(function(){throw "changed"})')!.as_string().str() == 'changed'
	for source in ['truth("")===2', 'truth("x")===1', 'truth(0n)===2', 'truth(3n)===1', 'truth(NaN)===2',
		'truth({})===1', '1/num(0)===-Infinity', '1/num(-0)===Infinity',
		'add(Infinity,-Infinity)!==add(Infinity,-Infinity)'] {
		assert native_test_run(mut vm, source)!.to_boolean(), source
	}
	activity := vm.diagnose_native_code(false)!
	assert activity.entries > 0 && activity.fast_steps > 0 && activity.slow_steps > 0
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_native_loops_share_budgets_with_recursive_calls_and_restore_the_vm() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	native_test_run(mut vm, 'function loop(n){var x=0;while(n>0){x=x+n;n--}return x} function recurse(n){if(n===0)return 0;return recurse(n-1)+1} loop(5);recurse(5)')!
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	assert native_test_run(mut vm, 'loop(10)+recurse(10)')!.number == 65
	for source in ['loop(10000)', 'recurse(1000)'] {
		mut script := native_test_script(mut vm, source)!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100 }) {
			assert false, 'Expected shared budget exhaustion'
		} else {
			assert is_throw_completion(err)
			assert thrown_value(err).as_object().error_message() or { '' }.contains('budget')
		}
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		assert !vm.instruction_budget_active
		assert native_test_run(mut vm, 'loop(3)')!.number == 6
	}
}

fn test_native_binary_cache_rebinds_values_in_a_fresh_vm() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut previous_hash := ''
	for index in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		// Same code layout, different heap strings and constants in each realm.
		mut script := native_test_script(mut vm, '"realm-${index}"')!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		stats := vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		assert stats.cache_hit == (index == 1)
		if index == 1 {
			assert stats.library_sha256 == previous_hash
		}
		previous_hash = stats.library_sha256
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.use_native_code(false)!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.use_native_code(true)!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
		vm.close_native_code()!
		assert vm.run(mut script)!.as_string().str() == 'realm-${index}'
	}
}

fn test_failed_native_compilation_keeps_interpreter_execution_available() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	mut script := native_test_script(mut vm, '6*7')!
	assert vm.run(mut script)!.number == 42
	if _ := vm.compile_native_code(cache, '/usr/bin/false', 1) {
		assert false
	}
	assert vm.run(mut script)!.number == 42
	vm.close_native_code()!
}

fn test_native_and_interpreted_paths_exhaust_exactly_the_same_instruction_budget() {
	cache := native_test_cache()
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	mut script := native_test_script(mut vm, 'var n=3;while(n>0){n--} n')!
	assert vm.run(mut script)!.number == 0
	vm.compile_native_code(cache, '/usr/bin/clang', 1)!
	for budget in 1 .. 65 {
		mut completed := []bool{}
		for enabled in [false, true] {
			vm.use_native_code(enabled)!
			if result := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				assert result.number == 0
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message() or { '' }.contains('budget')
				completed << false
			}
			assert vm.execution_context_stack().len == 1
			assert vm.interpreter_stack().depth() == 0
		}
		assert completed[0] == completed[1], 'Different budget boundary at ${budget}'
	}
}
