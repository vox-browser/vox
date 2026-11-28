module libjs

import os
import rand

fn test_native_primitive_operations_preserve_strings_identity_coercion_and_truthiness() {
	defer { set_native_primitive_ops_for_testing(true) }
	mut fast_counts := []u64{}
	mut slow_counts := []u64{}
	for enabled in [false, true] {
		set_native_primitive_ops_for_testing(enabled)
		cache := os.join_path(os.temp_dir(), 'vox-native-primitives-' + rand.uuid_v4())
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut setup := Script.parse('function eq(a,b){return a==b}function ne(a,b){return a!=b}function same(a,b){return a===b}function diff(a,b){return a!==b}function type(a){return typeof a}function truth(a){if(a)return !a;return !a}type(1);eq(1,1);ne(1,1);same(1,1);diff(1,1);truth(1)', vm.realm(), 'native-primitives.js', unsafe { nil })!
		vm.run(mut setup)!
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		assert vm.native_type_names.len == 7
		for name in vm.native_type_names { assert vm.heap_roots().contains(voidptr(name)) }
		vm.diagnose_native_code(true)!
		for source in [
			'type(undefined)==="undefined" && type(null)==="object" && type(false)==="boolean" && type(42)==="number" && type("x")==="string" && type(Symbol())==="symbol" && type(1n)==="bigint"',
			'type({})==="object" && type(function(){})==="function" && type(new Proxy(function(){},{}))==="function"',

			'same("","") && ne("","x") && ne("x","xy") && same("long class name","long "+"class name")',
			'eq("function","function") && !ne("a","a") && ne("a","b")',
			'same("x\\u0000y","x\\u0000y") && diff("x\\u0000y","x\\u0000z")',
			'same("\\ud800","\\ud800") && diff("\\ud800","\\ud801") && same("😀","😀")',
			'!same(NaN,NaN) && same(0,-0) && !diff(42,42.0)',
			'eq(null,undefined) && !same(null,undefined) && diff(null,undefined)',
			'var o={};same(o,o) && !same(o,{}) && eq(o,o) && ne(o,{})',
			'var s=Symbol();same(s,s) && ne(s,Symbol()) && !same(s,"x")',
			'eq(true,1) && eq(false,"0") && eq("42",42) && !same("42",42)',
			'eq(42n,42) && same(42n,42n) && ne(42n,43n)',
			'var n=0;var o={valueOf(){n++;return 42}};eq(o,42) && n===1 && !same(o,42) && n===1',
			'var threw=false;try{eq({valueOf(){throw 42}},42)}catch(e){threw=e===42}threw',
			'truth("") && !truth("x") && !truth("\\u0000") && !truth("\\ud800") && truth(0n) && !truth(1n)',
		] {
			mut script := Script.parse(source, vm.realm(), 'native-primitives-check.js', unsafe { nil })!
			assert vm.run(mut script)!.to_boolean(), source
		}
		activity := vm.diagnose_native_code(false)!
		fast_counts << activity.fast_steps
		slow_counts << activity.slow_steps
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
		vm.close_native_code()!
		os.rmdir_all(cache)!
	}
	assert fast_counts[1] > fast_counts[0] && slow_counts[1] < slow_counts[0]
}

fn test_native_primitive_operations_preserve_exact_budget_exhaustion() {
	defer { set_native_primitive_ops_for_testing(true) }
	mut results_by_mode := [][]string{}
	for mode in 0 .. 3 {
		set_native_primitive_ops_for_testing(mode == 2)
		cache := os.join_path(os.temp_dir(), 'vox-native-primitives-budget-' + rand.uuid_v4())
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function check(a,b){if(a){return typeof a==="string" && a==b && a===b}return a!=b}check("class name","class name")', vm.realm(), 'native-primitives-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.to_boolean()
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.use_native_code(mode != 0)!
		mut results := []string{}
		for budget in 1 .. 100 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: u64(budget)}) {
				results << value.str()
			} else {
				assert is_throw_completion(err)
				results << thrown_value(err).as_object().error_message() or { '' }
			}
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
			assert !vm.instruction_budget_active
		}
		results_by_mode << results
		vm.close_native_code()!
		os.rmdir_all(cache)!
	}
	assert results_by_mode[0] == results_by_mode[1] && results_by_mode[1] == results_by_mode[2]
}
