// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn generator_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'generator-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_generator_parameters_run_at_call_but_body_waits_for_first_next() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'var log="";function* g(a=(log+="parameter;",20)){log+="body;";yield a;return 42}var it=g();var before=log;var first=it.next(99),last=it.next(),done=it.next();before==="parameter;"&&log==="parameter;body;"&&first.value===20&&!first.done&&last.value===42&&last.done&&done.value===undefined&&done.done&&it[Symbol.iterator]()===it')!.as_bool()
	assert generator_eval(mut vm, 'function* empty(){return 42}var e=empty();e.next().value===42&&e.next().done')!.as_bool()
}

fn test_generators_keep_independent_frames_arguments_this_and_lexical_scope() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'function* g(x){let outer=x;{let inner=yield this.value+arguments[0];yield outer+inner}return x}var a=g.call({value:20},1),b=g.call({value:30},2);a.next().value===21&&b.next().value===32&&a.next(21).value===22&&b.next(10).value===12&&a.next().value===1&&b.next().value===2')!.as_bool()
	assert generator_eval(mut vm, 'class A{get value(){return 20}}class B extends A{#value=22;*values(){yield super.value;yield this.#value}}var i=new B().values();i.next().value+i.next().value===42')!.as_bool()
	assert generator_eval(mut vm, 'function factory(){let value=20;return function*(){yield value;yield ()=>++value}}var i=factory()(),a=i.next(),b=i.next(),closure=b.value;i.next();a.value===20&&closure()===21')!.as_bool()
	global := vm.realm().global_object_record()
	completed := global.get(mut vm, PropertyName.from_str('i'))!.as_object().generator_execution?
	assert completed.context == none && completed.function == none
	assert vm.interpreter_stack().depth() == 0
}

fn test_generator_throw_and_return_before_start_and_after_completion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'var ran=0,marker={};function* g(){ran++;yield 1}var a=g(),b=g(),same=false;try{a.throw(marker)}catch(e){same=e===marker}var r=b.return(42);same&&ran===0&&a.next().done&&r.done&&r.value===42&&b.next().done')!.as_bool()
	assert generator_eval(mut vm, 'var same=false;try{b.throw(marker)}catch(e){same=e===marker}var r=b.return(7);same&&r.done&&r.value===7')!.as_bool()
}

fn test_generator_injected_throw_uses_catch_and_return_runs_suspending_finally() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'var marker={},same=false,cleaned=0;function* g(){try{try{yield 1}catch(e){same=e===marker;yield 2}}finally{cleaned++;yield 3}return 4}var i=g();var a=i.next(),b=i.throw(marker),c=i.return(42),d=i.next();a.value===1&&b.value===2&&c.value===3&&!c.done&&d.value===42&&d.done&&same&&cleaned===1')!.as_bool()
	assert generator_eval(mut vm, 'function* g(){try{yield 1}finally{return 7}}var i=g();i.next();var result=i.return(42);result.done&&result.value===7')!.as_bool()
}

fn test_generator_return_closes_nested_for_of_iterators_before_outer_finally() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'var log="",source={};source[Symbol.iterator]=function(){return {next(){return {value:1}},return(){log+="close;";return {}}}};function* g(){try{for(var value of source){yield value}}finally{log+="finally;"}}var i=g();i.next();var result=i.return(42);result.value===42&&result.done&&log==="close;finally;"')!.as_bool()
	assert generator_eval(mut vm, 'var cleaned=0;function* g(){try{yield 20;yield 22}finally{cleaned++}}for(var value of g()){break}cleaned===1')!.as_bool()
}

fn test_generator_reentrancy_brand_and_uncaught_error_close_the_generator() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert generator_eval(mut vm, 'var it,rejected=false;function* g(){try{it.next()}catch(e){rejected=e instanceof TypeError}yield 42}it=g();it.next().value===42&&rejected')!.as_bool()
	assert generator_eval(mut vm, 'var marker={},same=false;function* fail(){yield 1;throw marker}var i=fail();i.next();try{i.next()}catch(e){same=e===marker}var rejected=false;try{i.next.call({})}catch(e){rejected=e instanceof TypeError}same&&i.next().done&&rejected')!.as_bool()
}

fn test_generator_suspension_and_resumption_share_the_callers_instruction_budget() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	generator_eval(mut vm, 'function* infinite(){while(true)yield 1}var endless=infinite()')!
	mut script := Script.parse('for(var n of endless){}', vm.realm(), 'generator-budget.js', unsafe { nil })!
	vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) or {
		assert thrown_value(err).as_object().error_message()?.contains('instruction budget')
		assert generator_eval(mut vm, '6*7')!.number == 42
		return
	}
	assert false, 'Generator resumes must share the active instruction budget'
}

fn test_cached_generators_suspend_and_resume_without_a_compiler_on_reopening() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-generators-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert generator_eval(mut vm, 'function* g(){try{yield 20;yield 22}finally{}}var i=g(),a=i.next(),b=i.next(),c=i.next();a.value+b.value===42&&!a.done&&!b.done&&c.done')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 5 }
		vm.close_native_code()!
	}
}
