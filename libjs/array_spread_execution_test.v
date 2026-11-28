// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn array_spread_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-spread.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_array_spread_values_holes_multiple_sources_and_unicode_iteration() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_spread_eval(mut vm, 'var a=[,...[,42],,...[]];a.length===4&&!(0 in a)&&(1 in a)&&a[1]===undefined&&a[2]===42&&!(3 in a)')!.as_bool()
	assert array_spread_eval(mut vm, 'var a=[0,...[1,2],3,..."A😀B",4];a.length===8&&a.join(":")==="0:1:2:3:A:😀:B:4"')!.as_bool()
	assert array_spread_eval(mut vm, 'var a=[...new Set([1,2,1]),...new Map([[3,4]])];a.length===3&&a[0]===1&&a[1]===2&&a[2][0]===3&&a[2][1]===4')!.as_bool()
}

fn test_array_spread_observes_iterator_getters_and_argument_order_exactly_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_spread_eval(mut vm, 'var log="",source={};Object.defineProperty(source,Symbol.iterator,{get(){log+="g";return function(){log+="i";var n=0;return {get next(){log+="n";return function(){log+="s";n++;return {get done(){log+="d";return n>1},get value(){log+="v";return 42}}}}}}}});function mark(v){log+=v;return v}var a=[mark("a"),...source,mark("z")];a.length===3&&a[1]===42&&log==="aginsdvsdz"')!.as_bool()
}

fn test_array_spread_original_exceptions_invalid_iterators_and_native_data_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert array_spread_eval(mut vm, 'var marker={},closed=0,later=0,source={};source[Symbol.iterator]=function(){return {next(){throw marker},return(){closed++;return {}}}};var caught=false;try{[...source,later++]}catch(e){caught=e===marker}caught&&closed===0&&later===0')!.as_bool()
	assert array_spread_eval(mut vm, 'var n=0;for(var value of [null,undefined,{},42])try{[...value]}catch(e){if(e instanceof TypeError)n++}n===4')!.as_bool()
	assert array_spread_eval(mut vm, 'Object.defineProperty(Array.prototype,"0",{set(){throw 42},configurable:true});var a=[...[7]];delete Array.prototype[0];a.length===1&&a[0]===7&&Object.getOwnPropertyDescriptor(a,"0").writable')!.as_bool()
}

fn test_array_spread_infinite_iterators_share_instruction_budget_and_restore_vm_state() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	array_spread_eval(mut vm, 'var infinite={};infinite[Symbol.iterator]=function(){return {next(){return {value:1,done:false}}}}')!
	mut script := Script.parse('[...infinite]', vm.realm(), 'spread-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	assert array_spread_eval(mut vm, 'var recovered=[1,...[20,21]];recovered[0]+recovered[1]+recovered[2]')!.number == 42
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_array_spread_native_cache_executes_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-array-spread-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert array_spread_eval(mut vm, 'function spread(v){return [1,...v,,..."😀"]}var a=spread([20,21]);a.length===5&&a[1]+a[2]+a[0]===42&&!(3 in a)&&a[4]==="😀"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 && activity.fast_steps > 0 }
		vm.close_native_code()!
	}
}
