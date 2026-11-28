// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn reduce_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-reduce.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_array_reductions_preserve_accumulators_callback_arguments_and_direction() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reduce_eval(mut vm, 'var source=[1,,3],seen="",first={};var result=source.reduce(function(a,v,i,o){"use strict";if(this!==undefined||arguments.length!==4||o!==source)throw 1;if(i===0&&a!==first)throw 2;seen+=i;return v},first);result===3&&seen==="02"&&[1,2,3].reduce((a,v)=>a-v)===-4&&[1,2,3].reduceRight((a,v)=>a-v)===0')!.as_bool()
	assert reduce_eval(mut vm, 'var initial={},calls=0;[].reduce(()=>calls++,initial)===initial&&[].reduceRight(()=>calls++,undefined)===undefined&&[,,undefined].reduce(()=>calls++)===undefined&&[,42,,].reduceRight(()=>calls++)===42&&calls===0')!.as_bool()
	assert reduce_eval(mut vm, 'Array.prototype.reduce.call("abc",(a,v)=>a+v,"")==="abc"&&Array.prototype.reduceRight.call("abc",(a,v)=>a+v,"")==="cba"')!.as_bool()
}

fn test_array_reductions_seed_from_inherited_indices_and_observe_live_mutations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reduce_eval(mut vm, 'var o=Object.create({1:21});o.length=4;o[3]=21;Array.prototype.reduce.call(o,(a,v)=>a+v)===42&&Array.prototype.reduceRight.call(o,(a,v)=>a+v)===42')!.as_bool()
	assert reduce_eval(mut vm, 'var log="",o={length:3};Object.defineProperty(o,"0",{get(){log+="g";o[1]=2;o[2]=3;return 1}});var r=Array.prototype.reduce.call(o,(a,v,i)=>{log+=i;return a+v});r===6&&log==="g12"')!.as_bool()
	assert reduce_eval(mut vm, 'var a=[1,2,3,4],seen="";var r=a.reduce(function(sum,v,i){seen+=i;if(i===0){delete a[1];a[2]=30;a[4]=50}return sum+v},0);r===35&&seen==="023"&&a.length===5')!.as_bool()
	assert reduce_eval(mut vm, 'var a=[1,2,3],seen="";var r=a.reduceRight(function(sum,v,i){seen+=i;if(i===2){delete a[0];a[1]=20;a[3]=40}return sum+v},0);r===23&&seen==="21"')!.as_bool()
}

fn test_array_reductions_capture_length_once_and_keep_large_unsigned_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reduce_eval(mut vm, 'var reads=0,o={0:1,1:2,2:3,get length(){reads++;return 3.9}};var r=Array.prototype.reduce.call(o,function(a,v,i){if(i===0){delete o[1];o[3]=100}return a+v},0);r===4&&reads===1')!.as_bool()
	assert reduce_eval(mut vm, 'var marker={},same=false,index=-1,value;try{Array.prototype.reduceRight.call({4294967296:42,length:4294967297},function(a,v,i){index=i;value=v;throw marker},0)}catch(e){same=e===marker}same&&index===4294967296&&value===42')!.as_bool()
}

fn test_array_reductions_validation_and_abrupt_getters_keep_order_and_original_reason() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reduce_eval(mut vm, 'var count=0,order="",marker={},same=0;for(var method of [Array.prototype.reduce,Array.prototype.reduceRight]){for(var run of [()=>method.call(null,()=>0),()=>method.call([],null),()=>method.call([],()=>0),()=>method.call([,,],()=>0)])try{run()}catch(e){if(e instanceof TypeError)count++}try{method.call({get length(){throw marker}},null)}catch(e){if(e===marker)same++}try{method.call({get length(){order+="l";return 0}},null)}catch(e){if(e instanceof TypeError)count++}try{method.call({get 0(){throw marker},length:1},()=>0)}catch(e){if(e===marker)same++}try{method.call([1,2],()=>{throw marker},0)}catch(e){if(e===marker)same++}}count===10&&same===6&&order==="ll"')!.as_bool()
	assert reduce_eval(mut vm, 'var seen=0,reason={},same=false,o={0:1,get 1(){throw reason},get 2(){seen++;return 3},length:3};try{Array.prototype.reduce.call(o,()=>0)}catch(e){same=e===reason}same&&seen===0')!.as_bool()
}

fn test_array_reductions_share_budget_for_sparse_seed_search_and_callback_iteration() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for method in ['reduce', 'reduceRight'] {
		for suffix in ['', ',0'] {
			if _ := reduce_eval(mut vm, 'Array.prototype.' + method + '.call({length:1000000},()=>0' + suffix + ')') { assert false }
			else { assert thrown_value(err).as_object().error_message()?.contains('budget') }
			assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
		}
	}
	assert reduce_eval(mut vm, 'var ok=true;for(var name of ["reduce","reduceRight"]){var d=Object.getOwnPropertyDescriptor(Array.prototype,name);ok=ok&&d.value.name===name&&d.value.length===1&&d.writable&&d.configurable&&!d.enumerable}ok&&[21,21].reduce((a,v)=>a+v)===42')!.as_bool()
}

fn test_array_reductions_reopen_native_callbacks_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-reduce-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert reduce_eval(mut vm, 'function add(a,v){return a+v}var values=[21,21];values.reduce(add)===42&&values.reduceRight(add,0)===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
