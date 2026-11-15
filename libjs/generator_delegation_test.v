// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn delegation_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'generator-delegation.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_yield_from_composes_recursive_generators_arrays_and_unicode_strings() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'function* walk(tree){yield tree.value;for(var child of tree.children||[])yield* walk(child)}var out=[...walk({value:20,children:[{value:22}]})];out.length===2&&out[0]+out[1]===42')!.as_bool()
	assert delegation_eval(mut vm, 'function* inner(){yield 20;return 22}function* outer(){var result=yield* inner();yield result;return 42}var i=outer();i.next().value===20&&i.next().value===22&&i.next().value===42&&i.next().done')!.as_bool()
	assert delegation_eval(mut vm, 'function* letters(){yield* "A😀B"}var a=[...letters()];a.length===3&&a[1]==="😀"')!.as_bool()
}

fn test_yield_from_preserves_delegate_result_identity_without_reading_its_value() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'var reads=0,calls=0,argumentsSeen=[],result={done:false,get value(){reads++;return 42}},source={};source[Symbol.iterator]=function(){return {next(value){argumentsSeen.push(arguments.length,value);calls++;return calls===1?result:{done:true,value:7}}}};function* g(){return yield* source}var i=g(),a=i.next(99),before=reads,b=i.next(22);a===result&&before===0&&b.done&&b.value===7&&argumentsSeen[0]===1&&argumentsSeen[1]===undefined&&argumentsSeen[2]===1&&argumentsSeen[3]===22')!.as_bool()
}

fn test_yield_from_forwards_throw_and_return_with_live_method_lookup() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'var log="",marker={},child={next(v){log+="next;";return {value:1}},throw(e){if(e!==marker||this!==child)throw 9;log+="throw;";return {done:false,value:2}},return(v){log+="return;";return {done:true,value:v+1}}},source={};source[Symbol.iterator]=()=>child;function* g(){try{yield* source}finally{log+="finally;"}}var i=g();i.next();var a=i.throw(marker),b=i.return(41);a.value===2&&!a.done&&b.value===42&&b.done&&log==="next;throw;return;finally;"')!.as_bool()
	assert delegation_eval(mut vm, 'var child={next(){return {value:1}},throw(e){return {done:true,value:20}}},source={};source[Symbol.iterator]=()=>child;function* g(){return (yield* source)+22}var i=g();i.next();var r=i.throw(1);r.done&&r.value===42')!.as_bool()
}

fn test_yield_from_missing_throw_closes_with_no_arguments_and_preserves_close_errors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'var closed=0,args=-1,source={};source[Symbol.iterator]=()=>({next(){return {value:1}},return(){closed++;args=arguments.length;return {}}});function* g(){yield* source}var i=g();i.next();var rejected=false;try{i.throw(9)}catch(e){rejected=e instanceof TypeError}rejected&&closed===1&&args===0&&i.next().done')!.as_bool()
	assert delegation_eval(mut vm, 'var marker={},same=false;source[Symbol.iterator]=()=>({next(){return {value:1}},return(){throw marker}});var i=g();i.next();try{i.throw(9)}catch(e){same=e===marker}same')!.as_bool()
}

fn test_yield_from_return_without_method_and_suspending_delegate_cleanup() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'var ran=0,source={};source[Symbol.iterator]=()=>({next(){return {value:1}}});function* g(){try{yield* source;ran++}finally{ran+=2}}var i=g();i.next();var r=i.return(42);r.done&&r.value===42&&ran===2')!.as_bool()
	assert delegation_eval(mut vm, 'function* inner(){try{yield 1}finally{yield 2}}function* outer(){return yield* inner()}var i=outer();i.next();var a=i.return(42),b=i.next();a.value===2&&!a.done&&b.value===42&&b.done')!.as_bool()
}

fn test_yield_from_caches_next_but_checks_delegate_results_and_does_not_close_failed_next() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert delegation_eval(mut vm, 'var reads=0,calls=0,child={get next(){reads++;return function(){calls++;return {value:calls,done:calls>1}}}},source={};source[Symbol.iterator]=()=>child;function* g(){yield* source}var i=g();i.next();Object.defineProperty(child,"next",{value:()=>{throw 1}});i.next().done&&reads===1&&calls===2')!.as_bool()
	assert delegation_eval(mut vm, 'var closed=0,marker={},same=false,source={};source[Symbol.iterator]=()=>({next(){throw marker},return(){closed++;return {}}});function* g(){yield* source}var i=g();try{i.next()}catch(e){same=e===marker}same&&closed===0&&i.next().done')!.as_bool()
	assert delegation_eval(mut vm, 'var rejected=false,source={};source[Symbol.iterator]=()=>({next(){return 1}});function* g(){yield* source}try{g().next()}catch(e){rejected=e instanceof TypeError}rejected')!.as_bool()
}

fn test_cached_yield_from_uses_native_resumption_with_compiler_disabled() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-yield-from-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert delegation_eval(mut vm, 'function* inner(){yield 20;return 22}function* outer(){return yield* inner()}var i=outer();i.next().value+i.next().value===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 6 }
		vm.close_native_code()!
	}
}
