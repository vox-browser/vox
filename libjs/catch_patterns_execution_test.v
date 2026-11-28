// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn catch_pattern_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'catch-patterns.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_catch_object_patterns_keep_defaults_rest_symbols_and_scoped_names() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert catch_pattern_eval(mut vm, 'var symbol=Symbol(),source={a:40,extra:7};source[symbol]=9;var value;try{throw source}catch({a,b=2,...rest}){value=a+b+rest.extra+rest[symbol]}value===58&&typeof a==="undefined"&&typeof rest==="undefined"')!.as_bool()
	assert catch_pattern_eval(mut vm, 'var order="",result;try{throw {get first(){order+="g";return undefined}}}catch({[(order+="k","first")]:x=(order+="d",42)}){result=x}result===42&&order==="kgd"')!.as_bool()
}

fn test_catch_pattern_initialization_errors_reach_outer_handlers_and_finalizers() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert catch_pattern_eval(mut vm, 'var marker={},order="",same=false;try{try{throw {get x(){throw marker}}}catch({x}){order+="body"}finally{order+="f"}}catch(e){same=e===marker}same&&order==="f"')!.as_bool()
	assert catch_pattern_eval(mut vm, 'var caught=false;try{try{throw {}}catch({a=b,b=42}){}}catch(e){caught=e instanceof ReferenceError}caught&&typeof b==="undefined"')!.as_bool()
}

fn test_catch_array_patterns_close_native_iterators_before_body_and_preserve_abrupt_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert catch_pattern_eval(mut vm, 'var closed=0,first,source={[Symbol.iterator](){return {next(){return {value:42,done:false}},return(){closed++;return {}}}}};try{throw source}catch([value]){first=value}first===42&&closed===1')!.as_bool()
	assert catch_pattern_eval(mut vm, 'var marker={},closed2=0,same=false,source2={[Symbol.iterator](){return {next(){return {value:undefined,done:false}},return(){closed2++;throw 99}}}};try{try{throw source2}catch([x=(()=>{throw marker})()]){}}catch(e){same=e===marker}same&&closed2===1')!.as_bool()
}

fn test_cached_catch_patterns_run_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-catch-patterns-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert catch_pattern_eval(mut vm, 'var cleaned=0;function f(){try{throw {a:40}}catch({a,b=2}){return a+b}finally{cleaned++}}f()===42&&cleaned===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
