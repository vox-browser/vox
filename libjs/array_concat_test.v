// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn concat_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'concat.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!
}

fn test_concat_spreads_arrays_preserves_holes_and_borrows_without_iteration() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert concat_eval(mut vm, 'var a=[1,,3],b=a.concat([4,5],6);b.length===6&&b[0]===1&&!(1 in b)&&b[4]===5&&b[5]===6&&a.length===3&&a!==b&&Array.prototype.concat.length===1')!.as_bool()
	assert concat_eval(mut vm, 'var a=[1],b=[2];b[Symbol.isConcatSpreadable]=false;var c=a.concat(b);c[1]===b&&c.length===2')!.as_bool()
	assert concat_eval(mut vm, 'var o={0:42,length:2};o[Symbol.isConcatSpreadable]=true;o[Symbol.iterator]=function(){throw 9};var c=[].concat(o);c.length===2&&c[0]===42&&!(1 in c)')!.as_bool()
	assert concat_eval(mut vm, 'var o={};Object.defineProperty(o,"length",{get:function(){throw 9}});Array.prototype.concat.call(o)[0]===o&&Array.prototype.concat.call("hi")[0].valueOf()==="hi"')!.as_bool()
	assert concat_eval(mut vm, 'var caught=false;try{Array.prototype.concat.call(null)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_concat_observes_spread_length_getters_inherited_indices_and_live_changes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert concat_eval(mut vm, 'var order="",p={1:8},o=Object.create(p);Object.defineProperty(o,Symbol.isConcatSpreadable,{get:function(){order+="s";return true}});Object.defineProperty(o,"length",{get:function(){order+="l";return 3}});Object.defineProperty(o,"0",{get:function(){order+="g";o[2]=9;return 7}});var c=[].concat(o);order==="slg"&&c.join()==="7,8,9"&&Object.prototype.hasOwnProperty.call(c,"1")')!.as_bool()
	assert concat_eval(mut vm, 'var o={0:1,1:2,length:2};o[Symbol.isConcatSpreadable]=true;Object.defineProperty(o,"0",{get:function(){o.length=4;delete o[1];o[2]=3;return 1}});var c=[].concat(o);c.length===2&&c[0]===1&&!(1 in c)')!.as_bool()
	assert concat_eval(mut vm, 'var o={length:9007199254740991};o[Symbol.isConcatSpreadable]=true;var caught=false;try{[1].concat(o)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	assert concat_eval(mut vm, 'var o={};Object.defineProperty(o,Symbol.isConcatSpreadable,{get:function(){throw 42}});var caught=false;try{[].concat(o)}catch(e){caught=e===42};caught')!.as_bool()
}

fn test_concat_species_creates_data_properties_and_sets_final_length() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert concat_eval(mut vm, 'var a=[1,,3],target={},initial=-1,setters=0;Object.defineProperty(Object.prototype,"0",{set:function(){setters++},configurable:true});function Species(n){initial=n;return target};a.constructor={};a.constructor[Symbol.species]=Species;var c=a.concat(4);delete Object.prototype[0];c===target&&initial===0&&setters===0&&c.length===4&&c[0]===1&&!(1 in c)&&c[3]===4')!.as_bool()
	assert concat_eval(mut vm, 'var a=[],o={};Object.defineProperty(o,"length",{value:0,writable:false});function Species(){return o};a.constructor={};a.constructor[Symbol.species]=Species;var caught=false;try{a.concat(1)}catch(e){caught=e instanceof TypeError};caught&&o[0]===1')!.as_bool()
	assert concat_eval(mut vm, 'var a=[];a.constructor={};a.constructor[Symbol.species]=null;Array.isArray(a.concat(42))')!.as_bool()
}

fn test_concat_retains_shared_execution_budget_for_large_sparse_inputs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	if _ := concat_eval(mut vm, 'var o={length:1000000};o[Symbol.isConcatSpreadable]=true;[].concat(o)') { assert false }
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_concat_executes_with_persisted_native_code_and_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-concat-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert concat_eval(mut vm, 'function f(a){return a.concat([42])[1]};f([1])')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
