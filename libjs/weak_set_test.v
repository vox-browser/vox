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

fn weak_set_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'weak-set.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_weak_set_identity_symbols_metadata_and_new_target() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert weak_set_eval(mut vm, 'var a={},b={},s=Symbol("x"),t=Symbol("x"),w=new WeakSet([a,a,s]);a.toString=function(){throw 99};w.has(a)&&w.has(s)&&!w.has(b)&&!w.has(t)&&w.add(b)===w&&w.has(b)&&w.delete(a)&&!w.delete(a)&&!w.has(a)&&w.delete(s)&&!w.has(s)')!.as_bool()
	assert weak_set_eval(mut vm, 'class W extends WeakSet{answer=42}var q=new W([b]);q instanceof W&&q instanceof WeakSet&&q.answer===42&&q.has(b)&&Object.getPrototypeOf(q)===W.prototype&&Object.prototype.toString.call(q)==="[object WeakSet]"&&q.size===undefined&&q[Symbol.iterator]===undefined&&WeakSet.length===0')!.as_bool()
	assert weak_set_eval(mut vm, 'var ok=true;for(var name of ["add","delete","has"]){var d=Object.getOwnPropertyDescriptor(WeakSet.prototype,name);ok=ok&&d.value.name===name&&d.value.length===1&&d.writable&&d.configurable&&!d.enumerable}var d=Object.getOwnPropertyDescriptor(WeakSet.prototype,Symbol.toStringTag);ok&&!d.writable&&!d.enumerable&&d.configurable')!.as_bool()
}

fn test_weak_set_rejects_invalid_members_and_distinguishes_weak_map_brand() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for expression in ['undefined', 'null', '1', '"key"', 'true', '1n', 'Symbol.for("shared")'] {
		assert weak_set_eval(mut vm, 'var w=new WeakSet(),caught=false;try{w.add(${expression})}catch(e){caught=e instanceof TypeError}caught&&!w.has(${expression})&&!w.delete(${expression})')!.as_bool()
	}
	assert weak_set_eval(mut vm, 'var n=0;for(var action of [()=>WeakSet(),()=>WeakSet.prototype.add.call(new WeakMap(),{}),()=>WeakSet.prototype.has.call(WeakSet.prototype,{}),()=>WeakSet.prototype.delete.call({},{}),()=>WeakMap.prototype.has.call(new WeakSet(),{})])try{action()}catch(e){if(e instanceof TypeError)n++}n===5')!.as_bool()
}

fn test_weak_set_iterable_add_lookup_closes_abrupt_completions_and_preserves_reason() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert weak_set_eval(mut vm, 'var original=WeakSet.prototype.add,closed=0,reason={},source={};source[Symbol.iterator]=function(){return {next(){return {value:0}},return(){closed++;throw reason}}};var caught=false;try{new WeakSet(source)}catch(e){caught=e instanceof TypeError}caught&&closed===1')!.as_bool()
	assert weak_set_eval(mut vm, 'closed=0;WeakSet.prototype.add=function(){throw reason};source[Symbol.iterator]=function(){return {next(){return {value:{}}},return(){closed++;return {}}}};try{new WeakSet(source)}catch(e){caught=e===reason}caught&&closed===1')!.as_bool()
	assert weak_set_eval(mut vm, 'closed=0;source[Symbol.iterator]=function(){return {next(){throw reason},return(){closed++;return {}}}};try{new WeakSet(source)}catch(e){caught=e===reason}caught&&closed===0')!.as_bool()
	assert weak_set_eval(mut vm, 'var reads=0;source[Symbol.iterator]=function(){reads++;return {next(){return {done:true}}}};WeakSet.prototype.add=0;try{new WeakSet(source)}catch(e){caught=e instanceof TypeError}var empty=new WeakSet(null);WeakSet.prototype.add=original;caught&&reads===0&&empty instanceof WeakSet')!.as_bool()
	assert weak_set_eval(mut vm, 'var calls=0,receiver;class W extends WeakSet{add(key){calls++;receiver=this;return original.call(this,key)}}var key={},w=new W([key,key]);calls===2&&receiver===w&&w.has(key)')!.as_bool()
}

fn test_weak_set_uses_persisted_native_entries_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-weak-set-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert weak_set_eval(mut vm, 'var w=new WeakSet(),key={};function touch(k){w.add(k);return w.has(k)&&w.delete(k)&&!w.has(k)}touch(key)')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}

@[noinline]
fn allocate_unrooted_weak_set(mut vm VM) !WeakCellReference {
	object := create_weak_set(mut vm, vm.realm().weak_set_prototype or { panic('Missing WeakSet prototype') })!
	return WeakCellReference.create(voidptr(object.weak_set or { panic('Missing WeakSet data') }))
}

fn test_weak_set_drops_collected_members_and_does_not_root_unreachable_sets() {
	$if gcboehm ? {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		object := create_weak_set(mut vm, vm.realm().weak_set_prototype or { panic('Missing WeakSet prototype') })!
		mut collection := object.weak_set or { panic('Missing WeakSet data') }
		state := C.vox_libjs_weak_test_key(sizeof(Object))
		encoded := C.vox_libjs_weak_test_encoded(state)
		collection.values[encoded] = WeakCellReference{encoded: encoded, slot: C.vox_libjs_weak_test_slot(state)}
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		vm.finish_execution_generation()
		assert collection.values.len == 0
		unrooted := allocate_unrooted_weak_set(mut vm)!
		for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() }
		assert unrooted.cell() == unsafe { nil }
		vm.finish_execution_generation()
		assert (vm.weak_collection_registry or { panic('Missing weak registry') }).sets.len == 1
	}
}

fn test_weak_set_keeps_reachable_members_through_gc() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	weak_set_eval(mut vm, 'var w=new WeakSet(),key={};w.add(key)')!
	$if gcboehm ? { for _ in 0 .. 5 { C.vox_libjs_weak_test_collect() } }
	assert weak_set_eval(mut vm, 'w.has(key)')!.as_bool()
}
