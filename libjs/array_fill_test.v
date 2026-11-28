// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn fill_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'fill.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!
}

fn test_fill_preserves_receiver_identity_holes_values_and_relative_bounds() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert fill_eval(mut vm, 'var a=Array(10),r=a.fill(null);r===a&&a.length===10&&Object.keys(a).length===10&&a[0]===null&&a[9]===null&&Array.prototype.fill.length===1')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1,2,3,4];a.fill(42,-3,-1);a.join()==="1,42,42,4"')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1,2];a.fill(0,99);a.fill(0,1,0);a.join()==="1,2"')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1,2];a.fill(42,-Infinity,undefined);a.join()==="42,42"')!.as_bool()
	assert fill_eval(mut vm, 'var s=Symbol(),o={toString:function(){throw 1}},a=[1,2];a.fill(o);a[0]===o&&a[1]===o&&[1].fill(s)[0]===s')!.as_bool()
}

fn test_fill_snapshots_length_then_converts_start_and_end_in_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert fill_eval(mut vm, 'var order="",o={};Object.defineProperty(o,"length",{get:function(){order+="l";return 3}});var start={valueOf:function(){order+="s";return 1}},end={valueOf:function(){order+="e";return 3}};Array.prototype.fill.call(o,42,start,end);order==="lse"&&o[1]===42&&o[2]===42&&!Object.hasOwn(o,"0")')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1,2,3],start={valueOf:function(){a.length=1;return 0}};a.fill(42,start);a.length===3&&a.join()==="42,42,42"')!.as_bool()
}

fn test_fill_observes_setters_read_only_indices_and_abrupt_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert fill_eval(mut vm, 'var calls="",p={};Object.defineProperty(p,"0",{set:function(v){calls+="0:"+v}});var o=Object.create(p);o.length=2;Array.prototype.fill.call(o,42);calls==="0:42"&&!Object.hasOwn(o,"0")&&o[1]===42')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1,2,3];Object.defineProperty(a,"1",{writable:false});var caught=false;try{a.fill(42)}catch(e){caught=e instanceof TypeError};caught&&a[0]===42&&a[1]===2&&a[2]===3')!.as_bool()
	assert fill_eval(mut vm, 'var a=[1],caught=false;try{a.fill(42,Symbol())}catch(e){caught=e instanceof TypeError};caught&&a[0]===1')!.as_bool()
	assert fill_eval(mut vm, 'var caught=false;try{Array.prototype.fill.call(null,42)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_fill_large_array_like_uses_the_shared_instruction_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	if _ := fill_eval(mut vm, 'Array.prototype.fill.call({length:9007199254740991},42)') { assert false }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_fill_reuses_native_code_with_compiler_disabled_in_a_fresh_vm() {
	directory := os.join_path(os.temp_dir(), 'vox-fill-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert fill_eval(mut vm, 'function f(a){return a.fill(42)[0]};f(Array(10))')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
