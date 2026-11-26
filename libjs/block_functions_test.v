// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn block_function_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source,vm.realm(),'block-functions.js',unsafe { nil })!
	return vm.run_with_limits(mut script,ExecutionLimits{max_instructions:100000}) or {
		if is_throw_completion(err) {
			value := thrown_value(err)
			if value.is_object() {
				object := value.as_object()
				return error('${object.error_message() or { err.msg() }}: ${source}')
			}
		}
		return err
	}
}

fn test_strict_block_functions_are_hoisted_mutable_and_keep_outer_bindings() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, '"use strict";let value=7,result=0;{result=value();function value(){return 42}value=()=>43;result+=value()}result===85&&value===7')!.as_bool()
	assert block_function_eval(mut vm, '"use strict";function outer(){ {function hidden(){return 42}} return typeof hidden}outer()==="undefined"&&typeof hidden==="undefined"')!.as_bool()
}

fn test_strict_block_function_closures_observe_tdz_and_escape_their_owner_scope() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, '"use strict";var saved,caught=false;{try{read()}catch(e){caught=e instanceof ReferenceError}let local=42;function read(){return local}saved=read}caught&&saved()===42&&typeof read==="undefined"&&typeof local==="undefined"')!.as_bool()
}

fn test_each_loop_entry_creates_fresh_block_functions_with_iteration_bindings() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, '"use strict";var values=[];for(let index=0;index<3;index++){values.push(read);function read(){return index}}values[0]()===0&&values[1]()===1&&values[2]()===2&&values[0]!==values[1]')!.as_bool()
}

fn test_annex_b_copies_the_current_block_binding_only_when_declaration_is_reached() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, 'function outer(){var before=typeof f;{var inside=f();function f(){return 42}}return before==="undefined"&&inside===42&&f()===42}outer()')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){var f=7;{f=()=>42;function f(){return 1}f=()=>99}return f()===42}outer()')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){if(false){function absent(){}}return absent===undefined}outer()')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){var f=7;exit:{break exit;function f(){return 42}}return f===7}outer()')!.as_bool()
}

fn test_annex_b_respects_lexical_and_parameter_conflicts_and_keeps_block_closures() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, 'function outer(f){ {function f(){return 42}}return f}outer(7)===7')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){let f=7;{function f(){return 42}}return f}outer()===7')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){let value=7;{let value=42;function f(){return value}}return f()}outer()===42')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(arg=1){ {function f(){return arg+41}}return f()}outer()===42')!.as_bool()
}

fn test_annex_b_duplicate_labelled_and_switch_functions_preserve_last_binding_and_reachability() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, 'function outer(){ {function f(){return 1}function f(){return 42}}return f()}outer()===42')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){ {label:function f(){return 42}}return f()}outer()===42')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(){label:function f(){return 42}return f()}outer()===42')!.as_bool()
	assert block_function_eval(mut vm, 'function outer(n){switch(n){case 0:function f(){return 42}break;case 1:break}return f}outer(0)()===42&&outer(1)===undefined')!.as_bool()
}

fn test_annex_b_global_candidates_do_not_overwrite_existing_lexical_or_restricted_bindings() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert block_function_eval(mut vm, 'let priorLexical=7;true')!.as_bool()
	assert block_function_eval(mut vm, '{function priorLexical(){return 42}}priorLexical===7')!.as_bool()
	assert block_function_eval(mut vm, '{function undefined(){return 42}}undefined===void 0')!.as_bool()
}

fn test_cached_annex_b_block_functions_copy_fresh_closures_without_a_compiler() {
	directory := os.join_path(os.temp_dir(),'vox-annex-b-'+rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory,if visit==0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert block_function_eval(mut vm, 'function outer(){var saved=[];for(let n=0;n<3;n++){saved.push(f);function f(){return n+40}}return saved[0]()===40&&saved[2]()===42&&f()===42&&saved[0]!==saved[2]}outer()')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit==1 { assert stats.cache_hits>0&&stats.cache_misses==0&&stats.compiler_invocations==0&&activity.entries>0 }
		vm.close_native_code()!
	}
}

fn test_cached_strict_block_functions_keep_fresh_environments_without_compiler() {
	directory := os.join_path(os.temp_dir(),'vox-block-functions-'+rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory,if visit==0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert block_function_eval(mut vm, '"use strict";var functions=[];for(let index=0;index<3;index++){functions.push(read);function read(){return index+40}}functions[2]()===42&&functions[0]()===40&&typeof read==="undefined"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit==1 { assert stats.cache_hits>0&&stats.cache_misses==0&&stats.compiler_invocations==0&&activity.entries>0 }
		vm.close_native_code()!
	}
}
