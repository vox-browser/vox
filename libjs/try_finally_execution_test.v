// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn finally_exec_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'finally-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_finally_preserves_normal_completion_and_runs_after_catch() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert finally_exec_eval(mut vm, 'try{42}finally{7}')!.number == 42
	assert finally_exec_eval(mut vm, '42;try{}finally{7}')!.is_undefined()
	assert finally_exec_eval(mut vm, 'try{throw 1}catch(e){e+41}finally{99}')!.number == 42
	assert finally_exec_eval(mut vm, 'var order="";try{order+="t";throw 1}catch(e){order+="c"}finally{order+="f"}order')!.as_string().str() == 'tcf'
}

fn test_finally_return_and_throw_preserve_values_or_override_pending_completions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert finally_exec_eval(mut vm, 'var marker={};function a(){try{return marker}finally{marker.changed=42}}a()===marker&&marker.changed===42')!.as_bool()
	assert finally_exec_eval(mut vm, 'function b(){try{return 1}finally{return 42}}function c(){try{throw 1}finally{return 42}}b()===42&&c()===42')!.as_bool()
	assert finally_exec_eval(mut vm, 'var original={},replacement={},same=0;function d(){try{return 1}finally{throw replacement}}try{d()}catch(e){if(e===replacement)same++}try{try{throw original}finally{try{throw replacement}catch(e){if(e!==replacement)throw 99}}}catch(e){if(e===original)same++}same===2')!.as_bool()
	assert finally_exec_eval(mut vm, 'var undefinedCaught=false;try{try{throw undefined}finally{}}catch(e){undefinedCaught=e===undefined}undefinedCaught')!.as_bool()
}

fn test_nested_finalizers_restore_scopes_and_route_finalizer_failures_to_outer_catches() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert finally_exec_eval(mut vm, 'var order="";let x=40;function f(){try{try{let x=1;return x}finally{order+="i"}}finally{order+="o"}}f()===1&&x===40&&order==="io"')!.as_bool()
	assert finally_exec_eval(mut vm, 'var seen=0;try{try{throw 1}catch(e){throw e+1}finally{seen++}}catch(e){seen+=e}seen===3')!.as_bool()
	assert finally_exec_eval(mut vm, 'var seen2=0;try{try{returned()}finally{throw 42}}catch(e){seen2=e}seen2===42')!.as_bool()
}

fn test_finally_routes_labelled_break_continue_and_allows_cleanup_to_override_them() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert finally_exec_eval(mut vm, 'var seen="";for(var i=0;i<3;i++){try{if(i===0)continue;if(i===1)break}finally{seen+=i}}seen==="01"')!.as_bool()
	assert finally_exec_eval(mut vm, 'var log="";outer:for(var j=0;j<2;j++){try{inner:for(var k=0;k<2;k++){try{continue outer}finally{log+="i"}}}finally{log+="o"}}log==="ioio"')!.as_bool()
	assert finally_exec_eval(mut vm, 'function f(){outer:for(var i=0;i<2;i++){try{return 1}finally{if(i===0)continue outer;break outer}}return 42}f()===42')!.as_bool()
	assert finally_exec_eval(mut vm, 'var flag=0;outer:{try{throw 1}finally{flag=42;break outer}}flag===42')!.as_bool()
}

fn test_finally_and_iterator_closing_follow_source_nesting_in_both_directions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	finally_exec_eval(mut vm, 'var order="";function iterable(name){return {[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){order+=name;return {}}}}}}')!
	assert finally_exec_eval(mut vm, 'function f(){try{for(var x of iterable("c")){return 42}}finally{order+="f"}}f()===42&&order==="cf"')!.as_bool()
	assert finally_exec_eval(mut vm, 'order="";function g(){for(var x of iterable("c")){try{return 42}finally{order+="f"}}}g()===42&&order==="fc"')!.as_bool()
	assert finally_exec_eval(mut vm, 'order="";outer:for(var x of iterable("o")){try{for(var y of iterable("i")){break outer}}finally{order+="f"}}order==="ifo"')!.as_bool()
	assert finally_exec_eval(mut vm, 'order="";var once=0;for(var x of iterable("c")){try{if(once++===0)continue;break}finally{order+="f"}}order==="ffc"')!.as_bool()
}

fn test_finally_await_keeps_pending_return_or_throw_across_suspension() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	finally_exec_eval(mut vm, 'var release,result,reason,marker={},order="",gate=new Promise(r=>release=r);async function f(){try{return 42}finally{order+="a";await gate;order+="b"}}async function g(){try{throw marker}finally{await gate;try{throw 1}catch(e){}}}f().then(v=>result=v);g().catch(e=>reason=e)')!
	assert finally_exec_eval(mut vm, 'result===undefined&&reason===undefined&&order==="a"')!.as_bool()
	finally_exec_eval(mut vm, 'release()')!
	assert finally_exec_eval(mut vm, 'result===42&&reason===marker&&order==="ab"')!.as_bool()
}

fn test_finally_body_is_emitted_once_and_budget_exhaustion_releases_frames() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	finally_exec_eval(mut vm, 'function f(){try{return 1}finally{while(true){}}}')!
	mut script := Script.parse('f()', vm.realm(), 'finally-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100}) { assert false }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	assert finally_exec_eval(mut vm, '42')!.number == 42
}

fn test_cached_finally_cleanup_runs_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-finally-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert finally_exec_eval(mut vm, 'var seen=0;function f(x){try{return x+1}finally{seen++}}f(41)===42&&seen===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
