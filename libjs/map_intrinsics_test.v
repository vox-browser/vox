// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn test_map_bucket_collisions_preserve_distinct_keys_and_iterator_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, '
		var m=new Map(), tiny=Number.MIN_VALUE;
		m.set(undefined,7).set(tiny,8);
		var iterator=m.keys();
		var first=iterator.next().value===undefined;
		var tail=m.delete(undefined)&&m.size===1&&m.get(tiny)===8;
		m.set(undefined,9);
		var head=m.delete(undefined)&&m.get(tiny)===8;
		var remaining=iterator.next().value===tiny&&iterator.next().done;
		first&&tail&&head&&remaining&&m.delete(tiny)&&m.size===0;
	')!.as_bool()
}

fn map_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_map_same_value_zero_distinct_key_types_and_object_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var a={},b={};a.toString=function(){throw 1};var m=new Map([[NaN,1],[NaN,2],[-0,3],[0,4],[a,5],[b,6],["0",7],[undefined,8]]);m.size===6&&m.get(NaN)===2&&m.get(-0)===4&&m.get(a)===5&&m.get(b)===6&&m.get("0")===7&&m.get(undefined)===8&&m.get(null)===undefined&&m.set(null,9)===m&&m.has(null)&&m.delete(b)&&!m.delete(b)')!.as_bool()
	assert map_eval(mut vm, '1/m.keys().next().value!==-Infinity&&new Map(null).size===0&&Object.prototype.toString.call(m)==="[object Map]"')!.as_bool()
	assert map_eval(mut vm, 'var x=Symbol("x"),y=Symbol("x");new Map([[x,1],[y,2],[1n,3],[1,4]]).size===4')!.as_bool()
}

fn test_map_iteration_live_updates_deletes_clear_and_permanent_exhaustion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var m=new Map([[1,"a"],[2,"b"],[3,"c"]]);var i=m.entries();var out=i.next().value.join(":");m.delete(2);m.set(3,"C");m.set(4,"d");out+","+i.next().value.join(":")+","+i.next().value.join(":")')!.as_string().str() == '1:a,3:C,4:d'
	assert map_eval(mut vm, 'm.clear();m.set(5,"e");var next=i.next().value.join(":");var done=i.next().done;m.set(6,"f");next==="5:e"&&done&&i.next().done')!.as_bool()
	assert map_eval(mut vm, 'm.entries===m[Symbol.iterator]&&m.keys().next().value===5&&m.values().next().value==="e"')!.as_bool()
}

fn test_map_callback_mutations_and_brand_checks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var m=new Map([[1,"a"],[2,"b"]]),ctx={},out="";m.forEach(function(v,k,self){if(self!==m||this!==ctx)throw 1;out+=k+v;if(k===1){m.delete(2);m.set(3,"c")}},ctx);out')!.as_string().str() == '1a3c'
	assert map_eval(mut vm, 'var caught=false;try{Map.prototype.has.call(new Set(),1)}catch(e){caught=e instanceof TypeError};caught&&Map[Symbol.species]===Map')!.as_bool()
	assert map_eval(mut vm, 'var caught=false;try{Map()}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_map_iterable_constructor_closes_for_bad_entries_getters_and_adder_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert map_eval(mut vm, 'var original=Map.prototype.set,closed=0,reason={},source={};source[Symbol.iterator]=function(){return {next:function(){return {value:1}},return:function(){closed++;return {}}}};var caught=false;try{new Map(source)}catch(e){caught=e instanceof TypeError};caught&&closed===1')!.as_bool()
	assert map_eval(mut vm, 'closed=0;var entry={};Object.defineProperty(entry,"0",{get:function(){throw reason}});source[Symbol.iterator]=function(){return {next:function(){return {value:entry}},return:function(){closed++;throw 99}}};try{new Map(source)}catch(e){caught=e===reason};caught&&closed===1')!.as_bool()
	assert map_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){return {value:[1,2]}},return:function(){closed++;return {}}}};Map.prototype.set=function(){throw reason};try{new Map(source)}catch(e){caught=e===reason};Map.prototype.set=original;caught&&closed===1')!.as_bool()
	assert map_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){throw reason},return:function(){closed++;return {}}}};try{new Map(source)}catch(e){caught=e===reason};caught&&closed===0')!.as_bool()
}

fn test_collections_execute_through_persisted_native_code_in_a_fresh_realm() {
	directory := os.join_path(os.temp_dir(), 'vox-collections-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	source := 'var total=0;var keys=new Set([1,2,2,3]);var values=new Map();keys.forEach(function(key){values.set(key,key*2)});values.forEach(function(v,k){total+=v+k});total'
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert map_eval(mut vm, source)!.number == 18
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert activity.entries >= 7 && activity.slow_steps > 0
			assert stats.cache_hits == 3 && stats.compiler_invocations == 0
		}
		vm.close_native_code()!
	}
}
