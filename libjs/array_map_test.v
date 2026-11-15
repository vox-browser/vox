// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn map_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_map_preserves_holes_callback_arguments_this_and_generic_receivers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var source=[1,,3],context={},calls="";var result=source.map(function(v,i,o){"use strict";if(this!==context||o!==source)throw 1;calls+=i;return v+i},context);result!==source&&result.length===3&&result[0]===1&&!(1 in result)&&result[2]===5&&calls==="02"&&source[2]===3&&Array.prototype.map.length===1')!.as_bool()
	assert map_eval(mut vm, 'Array.prototype.map.call("ab",(v,i)=>v+i).join(",")==="a0,b1"&&Array.prototype.map.call({0:2,length:1},v=>v*21)[0]===42')!.as_bool()
	assert map_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Array.prototype,"map");d.writable&&d.configurable&&!d.enumerable&&d.value.name==="map"')!.as_bool()
}

fn test_map_captures_length_and_observes_inherited_indices_and_live_mutations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var log="",p={1:8},o=Object.create(p);Object.defineProperty(o,"length",{get(){log+="l";return 3}});Object.defineProperty(o,"0",{get(){log+="g";o[2]=9;return 7}});var r=Array.prototype.map.call(o,function(v,i){log+=i;return v+1});log==="lg012"&&r.join(",")==="8,9,10"&&Object.hasOwn(r,"1")')!.as_bool()
	assert map_eval(mut vm, 'var a=[1,2,3],n=0,r=a.map(function(v,i){n++;if(i===0){a.length=1;a[3]=4}return v});n===1&&r.length===3&&r[0]===1&&!(1 in r)&&!(2 in r)')!.as_bool()
	assert map_eval(mut vm, 'var a=[1],n=0;a.map(function(v){a.push(2);n++});n===1&&a.length===2')!.as_bool()
}

fn test_map_species_order_data_properties_and_no_final_length_assignment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var a=[1,,3],log="",target={},setters=0;Object.defineProperty(Object.prototype,"0",{set(v){setters++},configurable:true});Object.defineProperty(target,"length",{value:7,writable:false});function Species(n){log+="s"+n;return target}Object.defineProperty(a,"constructor",{get(){log+="c";var c={};Object.defineProperty(c,Symbol.species,{get(){log+="p";return Species}});return c}});var r=a.map(v=>v*2);delete Object.prototype[0];r===target&&log==="cps3"&&setters===0&&r.length===7&&r[0]===2&&!(1 in r)&&r[2]===6')!.as_bool()
	assert map_eval(mut vm, 'var a=[];a.constructor={};a.constructor[Symbol.species]=null;Array.isArray(a.map(v=>v))')!.as_bool()
	assert map_eval(mut vm, 'var a=[],reads=0,caught=false;Object.defineProperty(a,"constructor",{get(){reads++;throw 9}});try{a.map(null)}catch(e){caught=e instanceof TypeError}caught&&reads===0')!.as_bool()
}

fn test_map_preserves_abrupt_getter_callback_and_result_definition_completions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var reason={},caught=false,reads=0,o={length:1};Object.defineProperty(o,"0",{get(){throw reason}});try{Array.prototype.map.call(o,()=>reads++)}catch(e){caught=e===reason}caught&&reads===0')!.as_bool()
	assert map_eval(mut vm, 'caught=false;var calls=0;try{[1,2].map(function(){calls++;throw reason})}catch(e){caught=e===reason}caught&&calls===1')!.as_bool()
	assert map_eval(mut vm, 'caught=false;var target={};Object.defineProperty(target,"1",{value:9});function Species(){return target}var a=[1,2];a.constructor={};a.constructor[Symbol.species]=Species;try{a.map(v=>v*2)}catch(e){caught=e instanceof TypeError}caught&&target[0]===2&&target[1]===9')!.as_bool()
	assert map_eval(mut vm, 'caught=false;var log="",o={};Object.defineProperty(o,"length",{get(){log+="l";return 0}});try{Array.prototype.map.call(o,null)}catch(e){caught=e instanceof TypeError}caught&&log==="l"')!.as_bool()
	assert map_eval(mut vm, 'caught=false;try{Array.prototype.map.call(null,()=>1)}catch(e){caught=e instanceof TypeError}caught')!.as_bool()
}

fn test_map_sparse_array_likes_consume_the_shared_execution_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	if _ := map_eval(mut vm, 'Array.prototype.map.call({length:1000000},v=>v)') { assert false }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_map_executes_persisted_native_code_in_a_fresh_vm_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-map-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert map_eval(mut vm, 'function transform(v){return v*2}var a=[21].map(transform);a[0]===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
