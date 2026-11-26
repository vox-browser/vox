// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

$if gcboehm ? {
	#include "@VMODROOT/libjs/weak_cells_test.h"
	fn C.vox_libjs_weak_test_collect()
}

fn weak_ref_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'weak-ref.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_weak_ref_retains_object_and_non_registered_symbol_identity_with_brand_checks() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert weak_ref_eval(mut vm, 'var object={},symbol=Symbol("target"),a=new WeakRef(object),b=new WeakRef(symbol);a.deref()===object&&b.deref()===symbol&&a.deref()===a.deref()&&Object.prototype.toString.call(a)==="[object WeakRef]"&&WeakRef.length===1&&WeakRef.prototype.deref.length===0')!.as_bool()
	for source in ['WeakRef({})', 'new WeakRef(1)', 'new WeakRef(null)', 'new WeakRef(Symbol.for("registered"))', 'WeakRef.prototype.deref.call({})', 'WeakRef.prototype.deref.call(WeakRef.prototype)'] {
		weak_ref_eval(mut vm, source) or {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			continue
		}
		assert false, source
	}
	assert weak_ref_eval(mut vm, 'class W extends WeakRef{}var w=new W(object);w instanceof W&&w instanceof WeakRef&&w.deref()===object')!.as_bool()
}

fn test_weak_ref_checks_target_before_new_target_prototype_and_retains_abrupt_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut state := &WeakRefPrototypeObservation{marker: Object.create(vm.realm(), none)}
	target := NativeFunction.create_constructor(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return js_undefined() },
		fn (mut vm VM, _ &Object) !&Object { return Object.create(vm.realm(), none) },
		0, PropertyName.from_str('Target')).object
	mut constructor := target
	constructor.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('prototype'), fn [state] (mut vm VM) !Value {
		mut seen := unsafe { &WeakRefPrototypeObservation(state) }; seen.reads++
		return throw_completion(Value.from_object(seen.marker))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('Target'), Value.from_object(target), 0)
	global.define_direct_property(PropertyName.from_str('marker'), Value.from_object(state.marker), 0)
	assert weak_ref_eval(mut vm, 'var rejected=false;try{Reflect.construct(WeakRef,[1],Target)}catch(e){rejected=e instanceof TypeError}rejected')!.as_bool()
	assert state.reads == 0
	assert weak_ref_eval(mut vm, 'var same=false;try{Reflect.construct(WeakRef,[{}],Target)}catch(e){same=e===marker}same')!.as_bool()
	assert state.reads == 1
}

@[heap]
struct WeakRefPrototypeObservation {
	marker &Object
mut:
	reads int
}

fn test_weak_ref_kept_targets_survive_collection_until_explicit_host_checkpoint() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	vm.set_external_promise_job_queue(true)
	weak_ref_eval(mut vm, 'var a=new WeakRef({answer:42})')!
	assert vm.kept_objects.len == 1
	$if gcboehm ? { for _ in 0 .. 8 { C.vox_libjs_weak_test_collect() } }
	assert weak_ref_eval(mut vm, 'a.deref().answer===42')!.as_bool()
	assert vm.kept_objects.len == 1
	vm.clear_kept_objects()
	assert vm.kept_objects.len == 0
	vm.set_external_promise_job_queue(false)
	weak_ref_eval(mut vm, 'var stillReachable={},b=new WeakRef(stillReachable);b.deref()===stillReachable')!
	assert vm.kept_objects.len == 0
}

fn test_cached_weak_ref_functions_run_without_a_compiler_on_reopening() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-weak-ref-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert weak_ref_eval(mut vm, 'function read(){var target={answer:42},ref=new WeakRef(target);return ref.deref().answer}read()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
