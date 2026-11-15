module libjs

import os
import rand

fn register_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'registers.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_register_bindings_preserve_reads_writes_missing_arguments_and_shadowing() {
	for enabled in [false, true] {
		set_register_bindings_for_testing(enabled)
		for source in [
			'function f(a,b){var c=a+1; a=c; b=2; return a*b}f(20)',
			'function f(a){var a=42;return a}f(1)',
			'function f(a){return a+(a=21)}f(21)',
			'function f(a,b){return b(a,a=0)}f(42,function(x,y){return x})',
			'function f(a){var b=42;try{throw 1}catch(b){b=0}return b}f(0)',
			'function f(a){var b;({x:b}={x:42});return b}f(0)',
			'function f(a){var b;for(b of [42]){}return b}f(0)',
			'function f(a){a+=1;return a++ + --a}f(20)',
			'function f(a){var x;return typeof x=="undefined" && typeof a=="undefined"?42:0}f()',
			'function f(a){ {let a=0;a=1}return a}f(42)',
			'function f(a){try{throw 0}catch(a){a=1}return a}f(42)',
			'function f(a){var x=0;for(var i=0;i<6;i++){x+=7}return x}f(1)',
			'function f(a){[a]=[42];return a}f(0)',
			'function f(a){({x:a}={x:42});return a}f(0)',
			'function f(a){for(a of [42]){}return a}f(0)',
			'function f(a){for(var a in {42:1}){}return +a}f(0)',
			'function f(a){return delete a ? 0 : 42}f(0)',
			'function f(a){return a(21)}f(function(x){"use strict";return this===undefined?x*2:0})',
		] {
			assert register_eval(source)!.number == 42, source
		}
	}
	set_register_bindings_for_testing(true)
}

fn test_register_bindings_keep_captures_arguments_eval_and_complex_parameters() {
	for source in [
		'function f(a){var b=1;return ()=>a+b}f(41)()',
		'function f(a,b){b=1;return ()=>a+b}f(41,0)()',
		'function f(a){arguments[0]=42;return a}f(0)',
		'function f(a){return ()=>arguments[0]}f(42)()',
		'function f(a,a){return a}f(0,42)',
		'function f(a=42){return a}f()',
		'function f({a}){return a}f({a:42})',
		'function f(a){function a(){return 42}return a()}f(0)',
	] {
		assert register_eval(source)!.number == 42, source
	}
}

fn test_register_bindings_emit_native_eligible_local_moves() {
	set_register_bindings_for_testing(true)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function f(a){var b=a+1;return b}f(41)', vm.realm(), 'registers.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 42
	global := script.realm.global_object or { panic('Missing global') }
	value := global.internal_get(mut vm, PropertyName.from_str('f'), Value.from_object(global))!
	mut callable := value.as_object().callable or { panic('Missing function') }
	if mut callable is ECMAScriptFunction {
		executable := callable.executable or { panic('Missing bytecode') }
		assert callable.register_bindings.len == 2
		assert executable.local_variable_names.len == 2
		assert !executable.instructions.any(it.op in [.get_binding, .set_binding, .set_variable])
	} else {
		assert false
	}
}

fn test_register_bindings_native_cache_revisit_preserves_values_and_frame_cleanup() {
	directory := os.join_path(os.temp_dir(), 'vox-register-bindings-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		mut script := Script.parse('function sum(n){var a=0;while(n>0){a+=n;n--}return a}sum(6)', vm.realm(), 'register-native.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 21
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.compiler_invocations == 0 && stats.cache_misses == 0 && stats.cache_hits == 2
			assert activity.entries > 0 && activity.fast_steps > 0
		}
		assert vm.interpreter_stack().depth() == 0 && vm.execution_context_stack().len == 1
		vm.close_native_code()!
	}
}

fn test_register_bindings_preserve_loop_budget_boundaries_and_cleanup() {
	defer { set_register_bindings_for_testing(true) }
	for budget in 1 .. 100 {
		mut completed := []bool{}
		for enabled in [false, true] {
			set_register_bindings_for_testing(enabled)
			mut vm := VM.create()
			create_simple_execution_context(mut vm)
			mut script := Script.parse('function sum(n){var a=0;while(n>0){a+=n;n--}return a}sum(6)', vm.realm(), 'register-budget.js', unsafe { nil })!
			if value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				assert value.number == 21
				completed << true
			} else {
				assert is_throw_completion(err)
				assert thrown_value(err).as_object().error_message()?.contains('budget')
				completed << false
			}
			assert vm.interpreter_stack().depth() == 0 && vm.execution_context_stack().len == 1
			assert !vm.instruction_budget_active
		}
		assert completed[0] == completed[1], 'Budget ${budget}'
	}
}
