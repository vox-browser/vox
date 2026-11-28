// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

@[heap]
struct PromiseRejectionLog {
mut:
	operations []RejectionOperation
}

fn promise_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'promise.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000}) or { return error(promise_test_error(err)) }
}

fn promise_test_error(err IError) string {
	if is_throw_completion(err) {
		value := thrown_value(err)
		if value.is_object() { return value.as_object().error_message() or { err.msg() } }
	}
	return err.msg()
}

fn test_promise_constructor_executor_is_synchronous_and_resolves_only_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	promise_eval(mut vm, 'var order="",result=0,p=new Promise(function(resolve,reject){order+="e";resolve(42);reject(7);throw 8});p.then(function(x){order+="t";result=x});order+="s"')!
	assert promise_eval(mut vm, 'order==="est"&&result===42&&p instanceof Promise&&Object.prototype.toString.call(p)==="[object Promise]"&&Promise.length===1&&Promise.prototype.then.length===2')!.as_bool()
	for source in ['Promise(function(){})', 'new Promise(1)', 'Promise.prototype.then.call({})', 'Promise.resolve.call(null,1)'] {
		assert promise_eval(mut vm, 'var caught=false;try{'+source+'}catch(e){caught=e instanceof TypeError};caught')!.as_bool()
	}
}

fn test_promise_reactions_are_fifo_jobs_and_chained_values_and_throws_propagate() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	promise_eval(mut vm, 'var order="",answer=0,reason=0;Promise.resolve().then(function(){order+="a";Promise.resolve().then(function(){order+="c"})});Promise.resolve().then(function(){order+="b"});order+="s";Promise.resolve(40).then(function(x){return x+2}).then(function(x){answer=x;throw 7}).catch(function(x){reason=x})')!
	assert promise_eval(mut vm, 'order==="sabc"&&answer===42&&reason===7')!.as_bool()
	promise_eval(mut vm, 'var identity=0,rejection=0;Promise.resolve(42).then(null).then(function(x){identity=x});Promise.reject(7).then(1).catch(function(x){rejection=x})')!
	assert promise_eval(mut vm, 'identity===42&&rejection===7')!.as_bool()
}

fn test_promise_thenable_getter_is_synchronous_but_call_and_handlers_are_jobs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	promise_eval(mut vm, 'var order="",answer=0,identity=false,o={get then(){order+="g";return function(resolve,reject){order+="t";identity=this===o;resolve(42);reject(7);throw 8}}};Promise.resolve(o).then(function(x){order+="r";answer=x});order+="s"')!
	assert promise_eval(mut vm, 'order==="gstr"&&answer===42&&identity')!.as_bool()
	promise_eval(mut vm, 'var token={},reason;Promise.resolve({get then(){throw token}}).catch(function(x){reason=x})')!
	assert promise_eval(mut vm, 'reason===token')!.as_bool()
}

fn test_promise_self_resolution_rejects_and_adoption_reuses_intrinsic_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	promise_eval(mut vm, 'var resolve,p=new Promise(function(r){resolve=r}),selfError=false;resolve(p);p.catch(function(e){selfError=e instanceof TypeError});var original=Promise.resolve(42),answer=0;new Promise(function(r){r(original)}).then(function(x){answer=x})')!
	assert promise_eval(mut vm, 'selfError&&answer===42&&Promise.resolve(original)===original')!.as_bool()
}

fn test_promise_subclasses_and_custom_species_use_generic_capabilities() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	promise_eval(mut vm, 'class P extends Promise{}var p=P.resolve(42),q=p.then(function(x){return x+1}),answer=0;q.then(function(x){answer=x})')!
	assert promise_eval(mut vm, 'p instanceof P&&q instanceof P&&answer===43&&P.resolve(p)===p')!.as_bool()
	promise_eval(mut vm, 'var settled=0,receiver=0;function Custom(executor){executor(function(v){settled=v},function(e){settled=-1});this.custom=true}var p=Promise.resolve(42);p.constructor={};p.constructor[Symbol.species]=Custom;var q=p.then(function(x){return x+1})')!
	assert promise_eval(mut vm, 'q.custom&&settled===43')!.as_bool()
	assert promise_eval(mut vm, 'var called=false,o={then:function(a,b){called=a===undefined;return b(42)}};Promise.prototype.catch.call(o,function(x){return x+1})===43&&called')!.as_bool()
}

fn test_native_promise_capability_can_settle_outside_bytecode_and_drain_jobs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	capability := new_promise_capability(mut vm, Value.from_object(vm.realm().promise_constructor_record())) or { panic(promise_test_error(err)) }
	mut global := vm.global_object()
	global.define_direct_property(PropertyName.from_str('external'), capability.promise, attribute_configurable)
	promise_eval(mut vm, 'var answer=0;external.then(function(x){answer=x})')!
	call(mut vm, capability.resolve, js_undefined(), [Value.from_i32(42)])!
	assert vm.promise_job_count() == 1
	vm.run_queued_promise_jobs()
	assert promise_eval(mut vm, 'answer')!.number == 42
}

fn test_external_promise_checkpoint_finishes_each_reaction_before_the_next_job() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	capability := new_promise_capability(mut vm, Value.from_object(vm.realm().promise_constructor_record()))!
	mut global := vm.global_object()
	global.define_direct_property(PropertyName.from_str('external'), capability.promise, attribute_configurable)
	promise_eval(mut vm, 'var order="";external.then(function(){order+="a";return{get then(){order+="g"}}});external.then(function(){order+="b"})')!
	call(mut vm, capability.resolve, js_undefined(), [js_undefined()])!
	vm.run_queued_promise_jobs()
	assert promise_eval(mut vm, 'order')!.as_string().str() == 'agb'
	assert vm.native_code_cache_is_idle()
}

fn test_promise_rejection_tracker_observes_reject_then_handle_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	log := &PromiseRejectionLog{}
	vm.host_promise_rejection_tracker = fn [log] (_ mut Promise, operation RejectionOperation) {
		mut record := unsafe { &PromiseRejectionLog(log) }
		record.operations << operation
	}
	promise_eval(mut vm, 'var p=Promise.reject(42);p.catch(function(){});p.catch(function(){})')!
	assert log.operations == [.reject, .handle]
}

fn test_promise_reaction_scripts_reuse_native_code_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-promise-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		promise_eval(mut vm, 'var answer=0;Promise.resolve(40).then(function(x){return x+2}).then(function(x){answer=x})')!
		assert vm.global_object().get(mut vm, PropertyName.from_str('answer'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
