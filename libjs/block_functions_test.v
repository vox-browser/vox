// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn block_function_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source,vm.realm(),'block-functions.js',unsafe { nil })!
	return vm.run_with_limits(mut script,ExecutionLimits{max_instructions:100000})
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

fn test_annex_b_block_function_semantics_remain_explicitly_unsupported() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	block_function_eval(mut vm, '{function sloppy(){return 1}}') or {
		assert err.msg().contains('Annex B block function declarations')
		return
	}
	assert false, 'Sloppy Annex B functions must not silently receive strict semantics'
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
