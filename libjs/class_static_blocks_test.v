// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn static_block_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'static-blocks.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_static_blocks_run_once_in_source_order_after_keys_and_method_installation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert static_block_eval(mut vm, 'var order="",keys=0;function key(){keys++;order+="k";return "field"}class C{static [key()]=(order+="f",1);static{order+="b";this.value=this.method()}static tail=(order+="t",this.value+1);static method(){return 41}}new C();new C();order==="kfbt"&&keys===1&&C.value===41&&C.tail===42&&!Object.hasOwn(C,"")')!.as_bool()
	assert static_block_eval(mut vm, 'var count=0;function make(){return class{static{count++}}}make();make();count===2')!.as_bool()
}

fn test_static_blocks_keep_class_this_super_private_names_and_local_var_scopes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert static_block_eval(mut vm, 'class A{static value=40}class B extends A{static #value=2;static #method(){return this.#value}static{var local=7;let other=9;this.answer=super.value+this.#method();this.self=B;this.target=new.target;this.read=()=>this.#value}static{this.hidden=typeof local+":"+typeof other}}B.answer===42&&B.self===B&&B.target===undefined&&B.read()===2&&B.hidden==="undefined:undefined"&&typeof local==="undefined"')!.as_bool()
}

fn test_static_block_throw_stops_later_initialization_and_runs_finally() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert static_block_eval(mut vm, 'var marker={},seen="",same=false;try{class C{static first=(seen+="f",1);static{try{seen+="b";throw marker}finally{seen+="c"}}static last=(seen+="l",2)}}catch(e){same=e===marker}same&&seen==="fbc"')!.as_bool()
	assert static_block_eval(mut vm, 'var caught=false;try{class C{static{unboundStatic=1}}}catch(e){caught=e instanceof ReferenceError}caught&&typeof unboundStatic==="undefined"')!.as_bool()
}

fn test_cached_static_blocks_execute_in_fresh_vm_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-static-block-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert static_block_eval(mut vm, 'var seen=0;class C{static value=40;static{try{this.value+=2}finally{seen++}}}C.value===42&&seen===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
