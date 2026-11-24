// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

$if gcboehm ? {
	#include "@VMODROOT/libjs/weak_cells_test.h"
	fn C.vox_libjs_weak_test_key(bytes uint) voidptr
	fn C.vox_libjs_weak_test_slot(state voidptr) voidptr
	fn C.vox_libjs_weak_test_encoded(state voidptr) u64
	fn C.vox_libjs_weak_test_collect()
}

fn weak_map_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'weak-map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 }) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_weak_map_keys_have_identity_no_coercion_and_distinguish_undefined_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert weak_map_eval(mut vm, 'var a={},b={};a.toString=function(){throw 99};var w=new WeakMap([[a,1],[b,2],[a,3]]);w.get(a)===3&&w.get(b)===2&&w.set(a,undefined)===w&&w.has(a)&&w.get(a)===undefined&&w.delete(b)&&!w.delete(b)&&!w.has(b)')!.as_bool()
	assert weak_map_eval(mut vm, 'var s=Symbol("x"),t=Symbol("x");w.set(s,42);w.get(s)===42&&!w.has(t)&&w.delete(s)&&!w.has(s)')!.as_bool()
	assert weak_map_eval(mut vm, 'new WeakMap(null) instanceof WeakMap&&Object.prototype.toString.call(w)==="[object WeakMap]"&&w.size===undefined&&w[Symbol.iterator]===undefined')!.as_bool()
}

fn test_weak_map_rejects_primitive_and_registered_symbol_keys_and_checks_brand_first() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for expression in ['undefined', 'null', '1', '"key"', 'true', '1n', 'Symbol.for("shared")'] {
		assert weak_map_eval(mut vm, 'var w=new WeakMap(),caught=false;try{w.set(${expression},1)}catch(e){caught=e instanceof TypeError};caught&&!w.has(${expression})&&w.get(${expression})===undefined&&!w.delete(${expression})')!.as_bool()
	}
	assert weak_map_eval(mut vm, 'var caught=false;try{WeakMap.prototype.has.call(new Map(),null)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	assert weak_map_eval(mut vm, 'var caught=false;try{WeakMap()}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_weak_map_constructor_closes_for_entry_getter_and_adder_failures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert weak_map_eval(mut vm, 'var original=WeakMap.prototype.set,closed=0,reason={},source={};source[Symbol.iterator]=function(){return {next:function(){return {value:[0,1]}},return:function(){closed++;throw reason}}};var caught=false;try{new WeakMap(source)}catch(e){caught=e instanceof TypeError};caught&&closed===1')!.as_bool()
	assert weak_map_eval(mut vm, 'closed=0;var entry={};Object.defineProperty(entry,"0",{get:function(){throw reason}});source[Symbol.iterator]=function(){return {next:function(){return {value:entry}},return:function(){closed++;return {}}}};try{new WeakMap(source)}catch(e){caught=e===reason};caught&&closed===1')!.as_bool()
	assert weak_map_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next:function(){throw reason},return:function(){closed++;return {}}}};try{new WeakMap(source)}catch(e){caught=e===reason};caught&&closed===0')!.as_bool()
	assert weak_map_eval(mut vm, 'var reads=0;source[Symbol.iterator]=function(){reads++;return {next:function(){return {done:true}}}};WeakMap.prototype.set=0;try{new WeakMap(source)}catch(e){caught=e instanceof TypeError};WeakMap.prototype.set=original;caught&&reads===0')!.as_bool()
}

fn test_weak_map_upsert_observes_callback_validation_and_mutations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert weak_map_eval(mut vm, 'var w=new WeakMap(),k={},calls=0;w.getOrInsert(k,undefined)===undefined&&w.has(k)&&w.getOrInsertComputed(k,function(){calls++;return 1})===undefined&&calls===0')!.as_bool()
	assert weak_map_eval(mut vm, 'var k2={};w.getOrInsertComputed(k2,function(key){if(key!==k2)throw 1;w.set(key,99);return 42})===42&&w.get(k2)===42')!.as_bool()
	assert weak_map_eval(mut vm, 'var caught=false;try{w.getOrInsertComputed(k,0)}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
}

fn test_weak_map_uses_persisted_native_code_in_fresh_realms() {
	directory := os.join_path(os.temp_dir(), 'vox-weak-map-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert weak_map_eval(mut vm, 'var w=new WeakMap(),k={};function update(key,v){w.set(key,v);return w.get(key)};update(k,42)')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}

@[noinline]
fn allocate_unrooted_weak_map(mut vm VM) !WeakCellReference {
	object := create_weak_map(mut vm, vm.realm().weak_map_prototype or { panic('Missing WeakMap prototype') })!
	return WeakCellReference.create(voidptr(object.slots.weak_map or { panic('Missing WeakMap data') }))
}

fn test_weak_map_dead_keys_and_unreachable_containers_are_not_strong_registry_roots() {
	$if gcboehm ? {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		object := create_weak_map(mut vm, vm.realm().weak_map_prototype or { panic('Missing WeakMap prototype') })!
		mut collection := object.slots.weak_map or { panic('Missing WeakMap data') }
		state := C.vox_libjs_weak_test_key(sizeof(Object))
		encoded := C.vox_libjs_weak_test_encoded(state)
		collection.entries[encoded] = WeakMapEntry{ key: WeakCellReference{ encoded: encoded, slot: C.vox_libjs_weak_test_slot(state) }, value: Value.from_i32(42) }
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		vm.finish_execution_generation()
		assert collection.entries.len == 0
		unrooted := allocate_unrooted_weak_map(mut vm)!
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		assert unrooted.cell() == unsafe { nil }
		vm.finish_execution_generation()
		assert (vm.weak_collection_registry or { panic('Missing weak registry') }).collections.len == 1
	}
}

fn test_weak_map_keeps_live_keys_and_values_through_collection() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	weak_map_eval(mut vm, 'var w=new WeakMap(),key={};w.set(key,{answer:42})')!
	$if gcboehm ? { for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() } }
	assert weak_map_eval(mut vm, 'w.has(key)&&w.get(key).answer===42')!.as_bool()
}

@[noinline]
fn watch_weak_map_value(mut vm VM) !WeakCellReference {
	object := vm.global_object().get(mut vm, PropertyName.from_str('w'))!.as_object()
	collection := object.slots.weak_map or { panic('Missing WeakMap data') }
	for _, entry in collection.entries { return WeakCellReference.create(entry.value.cell) }
	return error('Missing WeakMap entry')
}

fn test_weak_map_releases_completed_script_keys_and_then_their_values() {
	$if gcboehm ? {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		weak_map_eval(mut vm, 'var w=new WeakMap();function make(){var k={};w.set(k,{answer:42})};make()')!
		watcher := watch_weak_map_value(mut vm)!
		object := vm.global_object().get(mut vm, PropertyName.from_str('w'))!.as_object()
		collection := object.slots.weak_map or { panic('Missing WeakMap data') }
		assert collection.entries.len == 1
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		vm.finish_execution_generation()
		assert collection.entries.len == 0
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		assert watcher.cell() == unsafe { nil }
	}
}
