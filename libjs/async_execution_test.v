// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn async_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'async-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_async_body_starts_synchronously_and_returns_intrinsic_promise_before_reaction_jobs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert async_eval(mut vm, 'var log="",answer=0;async function add(a,b){log+="b";return a+b}var promise=add(20,22);var immediate=log==="b"&&promise instanceof Promise;promise.then(function(v){log+="r";answer=v});log+="s";immediate&&log==="bs"')!.as_bool()
	assert async_eval(mut vm, 'answer===42&&log==="bsr"')!.as_bool()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_async_await_pending_promise_preserves_private_brand_this_and_nested_lexical_scopes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert async_eval(mut vm, 'var release,answer=0;var pending=new Promise(resolve=>release=resolve);class Box{#number=40;async read(value){let n=this.#number;{let local=await value;return n+local+this.#number-40}}}var box=new Box(),promise=box.read(pending);promise.then(value=>answer=value);answer===0')!.as_bool()
	assert vm.interpreter_stack().depth() == 0 && vm.promise_job_count() == 0
	assert async_eval(mut vm, 'release(2);answer===0')!.as_bool()
	assert async_eval(mut vm, 'answer===42')!.as_bool()
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_await_observes_thenable_jobs_and_bypasses_replaced_promise_then_and_species() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert async_eval(mut vm, 'var log="",answer=0,thenable={get then(){log+="g";return function(resolve){log+="t";resolve(42);resolve(99)}}};async function work(){log+="a";var result=await thenable;log+="r";return result}work().then(value=>answer=value);log+="s";log==="ags"')!.as_bool()
	assert async_eval(mut vm, 'log==="agstr"&&answer===42')!.as_bool()
	async_eval(mut vm, 'var thenGets=0,constructorGets=0,result=0,p=Promise.resolve(42);Object.defineProperty(p,"then",{get(){thenGets++;throw 1}});Object.defineProperty(p,"constructor",{get(){constructorGets++;return Promise}});(async()=>await p)().then(v=>result=v)')!
	assert async_eval(mut vm, 'thenGets===0&&constructorGets===1&&result===42')!.as_bool()
}

fn test_await_rejection_enters_original_catch_scope_and_parameter_throws_reject_instead_of_escaping() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	async_eval(mut vm, 'var marker={},reject,answer=0,body=0,same=false,pending=new Promise((resolve,r)=>reject=r);async function work(){let prefix=1;try{{let value=await pending;return value}}catch(e){return e===marker?prefix+41:0}}work().then(v=>answer=v);async function defaults(value=(()=>{throw marker})()){body++}var thrown=false;try{defaults().catch(e=>same=e===marker)}catch(e){thrown=true}')!
	assert async_eval(mut vm, 'same&&!thrown&&body===0&&answer===0')!.as_bool()
	async_eval(mut vm, 'reject(marker)')!
	assert async_eval(mut vm, 'answer===42')!.as_bool()
}

fn test_async_return_adopts_thenables_and_promises_without_return_await_and_uses_intrinsic_constructor() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	async_eval(mut vm, 'var original=Promise,thenCalls=0,answer=0;var inner=Promise.resolve(42);async function work(){return inner}Promise=function(){throw 1};var outer=work();Promise=original;var distinct=outer!==inner&&outer instanceof Promise;outer.then(v=>answer=v);async function other(){return {then(resolve){thenCalls++;resolve(43)}}}var otherAnswer=0;other().then(v=>otherAnswer=v)')!
	assert async_eval(mut vm, 'distinct&&answer===42&&otherAnswer===43&&thenCalls===1')!.as_bool()
}

fn test_multiple_awaits_preserve_reference_operands_loop_bindings_arrow_this_and_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	async_eval(mut vm, 'var answer=0;var object={base:1,read(a){return (async()=>{let total=this.base+arguments[0];for(let n of [10,11,20])total+=await Promise.resolve(n);return total})()}};object.read(0).then(v=>answer=v)')!
	assert async_eval(mut vm, 'answer===42')!.as_bool()
	assert vm.take_promise_job_errors().len == 0 && vm.promise_job_count() == 0
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_async_await_rejections_and_then_getter_exceptions_keep_original_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	async_eval(mut vm, 'var marker={},same=0;async function one(){throw marker}one().catch(e=>{if(e===marker)same++});async function two(){return await {get then(){throw marker}}}two().catch(e=>{if(e===marker)same++});async function three(){return {get then(){throw marker}}}three().catch(e=>{if(e===marker)same++})')!
	assert async_eval(mut vm, 'same===3')!.as_bool()
}

fn test_async_await_loop_shares_budget_and_releases_active_frames_after_host_limit() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('async function spin(){while(true){await 0}}var pending=spin()', vm.realm(), 'async-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 1000})!
	promise := vm.global_object().get(mut vm, PropertyName.from_str('pending'))!.as_object().promise_record?
	errors := vm.take_promise_job_errors()
	if promise.state == .rejected { assert promise.result.as_object().error_message()?.contains('instruction budget') }
	else { assert errors.len > 0 && errors.any(is_throw_completion(it) && thrown_value(it).as_object().error_message() or { '' }.contains('instruction budget')) }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0 && vm.promise_job_count() == 0
	async_eval(mut vm, 'var recovered=0;(async()=>await 42)().then(v=>recovered=v)')!
	assert async_eval(mut vm, 'recovered===42')!.as_bool()
}

fn test_async_await_continuations_execute_persisted_native_code_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-async-await-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut expected := 0
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		async_eval(mut vm, 'var answer=0;async function work(value){let first=await Promise.resolve(value);return first+await 22}work(20).then(v=>answer=v)')!
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		assert vm.global_object().get(mut vm, PropertyName.from_str('answer'))!.number == 42
		if visit == 0 { expected = stats.compiled_executables; assert expected >= 3 }
		else { assert stats.cache_hits == expected && stats.compiler_invocations == 0 && activity.entries >= u64(expected+2) }
		vm.close_native_code()!
	}
}
