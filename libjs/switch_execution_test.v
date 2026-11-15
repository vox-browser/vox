// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn switch_exec_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'switch-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_switch_uses_strict_matching_evaluates_discriminant_once_and_falls_through() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert switch_exec_eval(mut vm, 'var reads=0,order="";switch((reads++,2)){case (order+="a",1):order+="x";break;case (order+="b",2):order+="y";case (order+="c",3):order+="z"}reads===1&&order==="abyz"')!.as_bool()
	assert switch_exec_eval(mut vm, 'var result=0;switch("1"){case 1:result=1;break;case "1":result=42;break}result')!.number == 42
	assert switch_exec_eval(mut vm, 'var result2=0;switch(NaN){case NaN:result2=1;break;default:result2=42}result2')!.number == 42
}

fn test_switch_default_waits_for_later_tests_and_preserves_statement_completion() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert switch_exec_eval(mut vm, 'var order="";switch(2){case 1:order+="a";break;default:order+="d";case (order+="t",2):order+="b"}order')!.as_string().str() == 'tb'
	assert switch_exec_eval(mut vm, 'var order2="";switch(9){case 1:order2+="a";break;default:order2+="d";case (order2+="t",2):order2+="b"}order2')!.as_string().str() == 'tdb'
	assert switch_exec_eval(mut vm, 'switch(1){case 1:42;break;default:7}')!.number == 42
	assert switch_exec_eval(mut vm, '42;switch(1){case 2:7}')!.is_undefined()
}

fn test_switch_owns_one_lexical_scope_and_collects_var_declarations_before_execution() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert switch_exec_eval(mut vm, 'var result=typeof hoisted;switch(1){case 1:var hoisted=42;let local=1;break;case 2:let other=2}result==="undefined"&&hoisted===42&&typeof local==="undefined"&&typeof other==="undefined"')!.as_bool()
	assert switch_exec_eval(mut vm, 'let outside=1;var answer=0;switch(outside){case 1:let outside=42;answer=outside}answer')!.number == 42
	assert switch_exec_eval(mut vm, 'var caught=false;try{switch(1){case 1:local;break;case 2:let local=42}}catch(e){caught=e instanceof ReferenceError}caught')!.as_bool()
	assert switch_exec_eval(mut vm, '"use strict";var answer2=0;switch(42){case f():function f(){return 42}answer2=f()}answer2')!.number == 42
	assert switch_exec_eval(mut vm, '"use strict";var hidden=false;try{switch(f()){case 42:function f(){return 42}}}catch(e){hidden=e instanceof ReferenceError}hidden')!.as_bool()
}

fn test_switch_continue_targets_iteration_and_breaks_run_crossed_finalizers() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert switch_exec_eval(mut vm, 'var order="";for(var i=0;i<3;i++){switch(i){case 0:continue;case 1:try{break}finally{order+="f"}default:order+="d"}order+="x"}order')!.as_string().str() == 'fxdx'
	assert switch_exec_eval(mut vm, 'var value=0;outer:for(var j=0;j<2;j++){switch(j){case 0:continue outer;default:value=42;break outer}}value')!.number == 42
}

fn test_switch_inside_for_of_keeps_iterator_open_for_local_break_and_closes_outer_break() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert switch_exec_eval(mut vm, 'var closed=0,source={[Symbol.iterator](){return {next(){return {value:1,done:false}},return(){closed++;return {}}}}},count=0;for(var x of source){switch(x){case 1:count++;break}if(count===2)break}count===2&&closed===1')!.as_bool()
}

fn test_cached_switch_dispatch_and_finally_run_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-switch-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert switch_exec_eval(mut vm, 'var cleanup=0;function f(x){try{switch(x){case 1:return 42;default:return 0}}finally{cleanup++}}f(1)===42&&cleanup===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
