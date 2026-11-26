// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn call_spread_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'call-spread.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_spread_calls_keep_callee_receiver_and_ordered_iterator_evaluation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert call_spread_eval(mut vm, 'var order="",receiver={get method(){order+="m";return function(a,b,c){order+="c";return this===receiver&&a===1&&b===2&&c===3}}},source={};source[Symbol.iterator]=function(){order+="i";var n=1;return {next(){order+="n";return n<3?{value:n++,done:false}:{done:true}}}};receiver.method(...source,(order+="a",3))&&order==="minnnac"')!.as_bool()
	assert call_spread_eval(mut vm, 'function f(a,b,c,d){"use strict";return this===undefined&&a===1&&b===2&&c===3&&d===4}f(1,...[2,3],4)&&((...values)=>values.join(":"))(..."😀x")==="😀:x"')!.as_bool()
}

fn test_spread_constructs_use_actual_new_target_and_subclass_prototypes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert call_spread_eval(mut vm, 'class C{constructor(a,b){this.sum=a+b;this.target=new.target}}var c=new C(...[20],22);c instanceof C&&c.sum===42&&c.target===C')!.as_bool()
	assert call_spread_eval(mut vm, 'class N extends Number{}var n=new N(...[42]);n instanceof N&&n instanceof Number&&n.valueOf()===42')!.as_bool()
}

fn test_optional_spread_calls_skip_arguments_and_preserve_method_receivers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert call_spread_eval(mut vm, 'var touched=0,missing=null,values={[Symbol.iterator](){touched++;return [42][Symbol.iterator]()}},o={method(x){return this===o&&x===42}};missing?.(...values)===undefined&&missing?.method(...values)===undefined&&touched===0&&o.method?.(...values)&&touched===1')!.as_bool()
}

fn test_spread_call_abrupt_completion_precedes_later_arguments_and_invalid_callee_error() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert call_spread_eval(mut vm, 'var marker={},later=0,closed=0,calls=0,source={[Symbol.iterator](){return {next(){throw marker},return(){closed++;return {}}}}},f=(...args)=>{calls++},same=0;for(var run of [()=>f(...source,later++),()=>new f(...source,later++),()=>42(...source,later++)])try{run()}catch(e){if(e===marker)same++}same===3&&later===0&&closed===0&&calls===0')!.as_bool()
	call_spread_eval(mut vm, 'var infinite={[Symbol.iterator](){return {next(){return {value:1,done:false}}}}};function f(){return 42}')!
	mut script := Script.parse('f(...infinite)', vm.realm(), 'spread-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100}) { assert false }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	assert call_spread_eval(mut vm, 'f(...[1])')!.number == 42
}

fn test_cached_spread_calls_and_construction_execute_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-call-spread-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert call_spread_eval(mut vm, 'function add(a,b){return a+b}class C{constructor(v){this.value=v}}new C(...[add(...[20,22])]).value===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.compiler_invocations == 0 && stats.cache_hits >= 3 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
