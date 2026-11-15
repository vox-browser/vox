// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn predicate_query_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-predicate-query.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_array_predicate_queries_generic_receivers_callback_arguments_this_and_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert predicate_query_eval(mut vm, 'var source={0:21,1:42,length:2},context={},calls="";var found=Array.prototype.find.call(source,function(v,i,o){"use strict";if(this!==context||o!==source)throw 1;calls+=i;return v===42},context);found===42&&calls==="01"&&Array.prototype.some.call("ab",v=>v==="b")&&![].some(()=>true)&&[].find(()=>true)===undefined')!.as_bool()
	assert predicate_query_eval(mut vm, 'var ok=true;for(var name of ["find","some"]){var d=Object.getOwnPropertyDescriptor(Array.prototype,name);ok=ok&&d.value.name===name&&d.value.length===1&&d.writable&&d.configurable&&!d.enumerable}ok')!.as_bool()
}

fn test_array_find_visits_holes_while_some_observes_only_present_live_and_inherited_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert predicate_query_eval(mut vm, 'var found="",some="",a=[,2,,4];a.find(function(v,i){found+=i;return false});a.some(function(v,i){some+=i;return false});found==="0123"&&some==="13"&&a.find(v=>v===undefined)===undefined')!.as_bool()
	assert predicate_query_eval(mut vm, 'var proto={1:42},o=Object.create(proto);o.length=3;var log="";Object.defineProperty(o,"0",{get(){log+="g";o[2]=43;return 41}});Array.prototype.some.call(o,function(v,i){log+=i;return v===43})&&log==="g012"&&Array.prototype.find.call(o,v=>v===42)===42')!.as_bool()
	assert predicate_query_eval(mut vm, 'var a=[1,2,3],f="",s="";a.find(function(v,i){if(i===0){a.length=1;a[3]=4}f+=i+":"+v+";";return false});a=[1,2,3];a.some(function(v,i){if(i===0){a.length=1;a[3]=4}s+=i;return false});f==="0:1;1:undefined;2:undefined;"&&s==="0"')!.as_bool()
}

fn test_array_predicate_queries_snapshot_length_and_short_circuit_before_later_getters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert predicate_query_eval(mut vm, 'var reads=0,o={0:42};Object.defineProperty(o,"length",{get(){reads++;return 2}});Object.defineProperty(o,"1",{get(){throw 1}});Array.prototype.find.call(o,v=>({}))===42&&Array.prototype.some.call(o,v=>({}))&&reads===2')!.as_bool()
	assert predicate_query_eval(mut vm, 'var a=[1],calls=0;a.find(function(){a.push(42);calls++;return false});a.some(function(v,i){if(i===0)a.push(43);return false});calls===1&&a.length===3')!.as_bool()
}

fn test_array_predicate_queries_validation_and_original_abrupt_completions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert predicate_query_eval(mut vm, 'var count=0,marker={},same=0;for(var method of [Array.prototype.find,Array.prototype.some]){try{method.call(null,()=>true)}catch(e){if(e instanceof TypeError)count++}var o={get length(){same++;return 0}};try{method.call(o,null)}catch(e){if(e instanceof TypeError)count++}try{method.call({get length(){throw marker}},null)}catch(e){if(e===marker)same++}try{method.call({0:1,length:1},()=>{throw marker})}catch(e){if(e===marker)same++}try{method.call({get 0(){throw marker},length:1},()=>true)}catch(e){if(e===marker)same++}}count===4&&same===8')!.as_bool()
}

fn test_array_predicate_query_sparse_ranges_share_instruction_budget_and_restore_frames() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for method in ['find','some'] {
		if _ := predicate_query_eval(mut vm, 'Array.prototype.'+method+'.call({length:1000000},()=>false)') { assert false }
		else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_predicate_queries_execute_persisted_native_callbacks_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-array-predicates-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert predicate_query_eval(mut vm, 'function match(v){return v===42}[21,42].find(match)===42&&[42].some(match)')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
