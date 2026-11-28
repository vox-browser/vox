module libjs

import os
import rand

fn native_binding_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'native-binding.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_native_binding_reads_keep_live_scopes_receivers_and_lookup_hooks() {
	defer { set_native_binding_reads_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-binding-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for enabled in [false, true] {
		set_native_binding_reads_for_testing(enabled)
		mut vm := VM.create()
		vm.use_immutable_compiler_executables(true)!
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		native_binding_eval(mut vm, 'globalThis.x=1;function read(){return x}function strictFn(){"use strict";return this}function invoke(){return strictFn()}function captured(x){return function(){return x}}function withRead(o){with(o){return x}}function withCall(o){with(o){return f()}}function tdzRead(){try{{return shadow;let shadow=1}}catch(e){return e instanceof ReferenceError}}function evalRead(){eval("var z=42");return z===42}var get=captured(7);read();invoke();get();withRead({x:1});withCall({f(){return 1}});tdzRead();evalRead()')!
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.diagnose_native_code(true)!
		mut samples := []string{}
		for source in [
			'x=42;read()===42&&get()===7&&invoke()===undefined',
			'var n=0;Object.defineProperty(globalThis,"x",{configurable:true,get(){n++;return 8}});read()===8&&n===1',
			'var n=0,o={get x(){n++;return 9}};withRead(o)===9&&n===1',
			'var n=0,p=new Proxy({x:9},{has(t,k){if(k==="x")n++;return Reflect.has(t,k)}});withRead(p)===9&&n===2',
			'tdzRead()',
			'evalRead()',
			'var o={f(){return this}};withCall(o)===o',
			'var o={x:1};o[Symbol.unscopables]={x:true};withRead(o)===8',
		] { samples << native_binding_eval(mut vm, source)!.str() }
		activity := vm.diagnose_native_code(false)!
		assert (activity.native_binding_steps > 0) == enabled
		for sample in samples { assert sample == 'true' }
		results << samples
		vm.close_native_code()!
	}
	assert results[0] == results[1]
}

fn test_native_binding_reads_preserve_exact_instruction_budgets() {
	defer { set_native_binding_reads_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-native-binding-budget-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut results := [][]string{}
	for mode in 0 .. 3 {
		set_native_binding_reads_for_testing(mode == 2)
		mut vm := VM.create()
		vm.use_immutable_compiler_executables(true)!
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('var x=42;function read(){return x}function invoke(){try{return read()}finally{}}invoke()', vm.realm(), 'native-binding-budget.js', unsafe { nil })!
		assert vm.run(mut script)!.number == 42
		vm.compile_native_code(cache, '/usr/bin/clang', 1)!
		vm.use_native_code(mode != 0)!
		mut samples := []string{}
		for budget in 1 .. 100 {
			if value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: u64(budget) }) {
				samples << value.str()
			} else {
				assert is_throw_completion(err)
				samples << thrown_value(err).as_object().error_message() or { '' }
			}
		}
		results << samples
		vm.close_native_code()!
	}
	assert results[0] == results[1] && results[1] == results[2]
}
