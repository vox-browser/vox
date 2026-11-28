// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn from_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-from.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_array_from_iterables_unicode_holes_and_mapper_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var seen="",receiver={},a=Array.from([1,,3],function(v,i){"use strict";if(this!==receiver||arguments.length!==2)throw 1;seen+=i;return v===undefined?7:v+i},receiver);a.join(",")==="1,7,5"&&seen==="012"&&Object.hasOwn(a,"1")&&Array.from("a😀b").join(",")==="a,😀,b"&&Array.from(new Set([1,2,1])).join(",")==="1,2"')!.as_bool()
	assert from_eval(mut vm, 'var a=[1,2],b=Array.from(a,function(v,i){if(i===0)a.push(3);return v});b.join(",")==="1,2,3"&&Array.from({length:36}).map((v,i)=>i).length===36')!.as_bool()
}

fn test_array_from_array_like_snapshots_length_and_uses_live_get_for_every_index() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var log="",o=Object.create({1:8});Object.defineProperty(o,"length",{get(){log+="l";return 3.9}});Object.defineProperty(o,"0",{get(){log+="g";o[2]=9;return 7}});var a=Array.from(o,function(v,i){log+=i;return v+1});a.join(",")==="8,9,10"&&log==="lg012"&&Array.from({length:-1}).length===0&&Array.from(42).length===0')!.as_bool()
	assert from_eval(mut vm, 'var a=[1,,3];a[Symbol.iterator]=null;var b=Array.from(a,function(v,i){if(i===0)a.length=1;return v});b.length===3&&Object.hasOwn(b,"1")&&Object.hasOwn(b,"2")&&b[1]===undefined&&b[2]===undefined')!.as_bool()
}

fn test_array_from_generic_constructors_subclasses_and_data_property_definitions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var args=[],writes="",target={};Object.defineProperty(target,"length",{set(v){writes+="l"+v},configurable:true});function C(n){args.push(arguments.length===0?"none":n);return target}var a=Array.from.call(C,[1,2]);var b=Array.from.call(C,{0:3,length:1});a===target&&b===target&&args.join(",")==="none,1"&&writes==="l2l1"&&target[0]===3&&Array.isArray(Array.from.call(()=>0,[4]))')!.as_bool()
	assert from_eval(mut vm, 'class A extends Array{answer=42}var a=A.from([7,8]),b=A.from({0:9,length:1}),c=new A(3),d=new A("x");a instanceof A&&Array.isArray(a)&&a.answer===42&&a.join(",")==="7,8"&&b instanceof A&&b[0]===9&&c instanceof A&&c.length===3&&d instanceof A&&d[0]==="x"&&d.length===1')!.as_bool()
	from_eval(mut vm, 'function Target(){}Target.prototype=null')!
	constructor := vm.global_object().get(mut vm, PropertyName.from_str('Array'))!
	target := vm.global_object().get(mut vm, PropertyName.from_str('Target'))!.as_object()
	created := construct(mut vm, constructor, [Value.from_i32(2)], target)!
	assert voidptr(created.internal_get_prototype_of() or { panic('Missing Array prototype') }) == voidptr(vm.realm().array_prototype_record())
	assert created.get(mut vm, PropertyName.from_str('length'))!.number == 2
	assert from_eval(mut vm, 'var setters=0;Object.defineProperty(Array.prototype,"0",{set(){setters++},configurable:true});var a=Array.from([42]);delete Array.prototype[0];a[0]===42&&Object.hasOwn(a,"0")&&setters===0')!.as_bool()
}

fn test_array_from_get_method_constructor_iterator_and_mapping_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var log="",source={get [Symbol.iterator](){log+="g";return function(){log+="i";var n=0;return {get next(){log+="n";return function(){log+="s";return n++?{done:true}:{value:21,done:false}}}}}}};function C(){log+="c"}var a=Array.from.call(C,source,function(v,i){log+="m";return v*2});log==="gcinsms"&&a[0]===42&&a.length===1')!.as_bool()
	assert from_eval(mut vm, 'var marker={},same=false,reads=0,source={get [Symbol.iterator](){reads++;return function(){throw 7}}};function C(){throw marker}try{Array.from.call(C,source)}catch(e){same=e===marker}same&&reads===1')!.as_bool()
	assert from_eval(mut vm, 'var reads=0,caught=false,o={get [Symbol.iterator](){reads++;throw 1}};try{Array.from(o,null)}catch(e){caught=e instanceof TypeError}caught&&reads===0')!.as_bool()
}

fn test_array_from_closes_on_mapping_and_definition_failure_preserving_original_throw() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var marker={},closed=0,same=false,source={[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){closed++;throw 99}}}};try{Array.from(source,()=>{throw marker})}catch(e){same=e===marker}same&&closed===1')!.as_bool()
	assert from_eval(mut vm, 'var closed=0,target={};Object.defineProperty(target,"0",{value:9});function C(){return target}var source={[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){closed++;return {}}}}},caught=false;try{Array.from.call(C,source)}catch(e){caught=e instanceof TypeError}caught&&closed===1&&target[0]===9')!.as_bool()
}

fn test_array_from_does_not_close_after_step_value_or_completed_length_failures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert from_eval(mut vm, 'var marker={},closed=0,same=0;for(var next of [()=>{throw marker},()=>({get done(){throw marker}}),()=>({done:false,get value(){throw marker}})]){var source={[Symbol.iterator](){return {next:next,return(){closed++;return {}}}}};try{Array.from(source)}catch(e){if(e===marker)same++}}same===3&&closed===0')!.as_bool()
	assert from_eval(mut vm, 'var closed=0,target={};Object.defineProperty(target,"length",{value:0});function C(){return target}var source={[Symbol.iterator](){return {next(){return {done:true}},return(){closed++;return {}}}}},caught=false;try{Array.from.call(C,source)}catch(e){caught=e instanceof TypeError}caught&&closed===0')!.as_bool()
	assert from_eval(mut vm, 'var count=0;for(var run of [()=>Array.from(null),()=>Array.from(undefined),()=>Array.from({[Symbol.iterator]:1}),()=>Array.from([],{}),()=>Array.from.call(null,{length:4294967296})])try{run()}catch(e){if(e instanceof TypeError||e instanceof RangeError)count++}count===5')!.as_bool()
}

fn test_array_from_both_paths_share_execution_budget_and_unwind_frames() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['Array.from({length:1000000})', 'Array.from({[Symbol.iterator](){return {next(){return {value:1,done:false}}}}})'] {
		if _ := from_eval(mut vm, source) { assert false }
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
	assert from_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(Array,"from");d.writable&&d.configurable&&!d.enumerable&&d.value.name==="from"&&d.value.length===1&&Array.from({0:42,length:1})[0]===42')!.as_bool()
}

fn test_array_from_reuses_native_callbacks_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-array-from-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert from_eval(mut vm, 'function transform(value,index){return value+index}Array.from([21,41],transform).join(",")==="21,42"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
