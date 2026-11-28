// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn labelled_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'labelled-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn labelled_iterables(mut vm VM) ! {
	labelled_eval(mut vm, 'var closed="";function iterable(values,name){return {[Symbol.iterator](){var index=0;return {next(){return index<values.length?{value:values[index++],done:false}:{done:true}},return(){closed+=name;return {}}}}}}')!
}

fn test_labelled_blocks_preserve_completion_unwind_scopes_and_hoist_var_bindings() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert labelled_eval(mut vm, 'exit:{let hidden=7;42;break exit;99}')!.number == 42
	assert labelled_eval(mut vm, 'typeof hidden==="undefined"')!.as_bool()
	assert labelled_eval(mut vm, 'var value=0;outer:{inner:{value=42;break outer}value=1}outer:{value++}value===43')!.as_bool()
	assert labelled_eval(mut vm, 'var before="hoisted" in globalThis;stop:{if(false){var hoisted=1}break stop}before&&hoisted===undefined')!.as_bool()
}

fn test_labels_target_nested_while_for_do_while_and_for_in_iterations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert labelled_eval(mut vm, 'var count=0,i=0;outer:while(i<3){i++;for(var j=0;j<3;j++){count++;continue outer}}count===3&&i===3')!.as_bool()
	assert labelled_eval(mut vm, 'var n=0;a:b:for(var i=0;i<4;i++){for(var j=0;j<3;j++){n++;if(i===2)break a;continue b}}n===3&&i===2')!.as_bool()
	assert labelled_eval(mut vm, 'var n=0;again:do{n++;if(n<3)continue again;break again}while(n<10);n===3')!.as_bool()
	assert labelled_eval(mut vm, 'var keys="";outer:for(let key in {a:1,b:2}){for(let inner in {x:1,y:2}){keys+=key;continue outer}}keys==="ab"&&typeof key==="undefined"&&typeof inner==="undefined"')!.as_bool()
}

fn test_labelled_for_of_break_closes_crossed_iterators_in_order_and_continue_keeps_target_open() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	labelled_iterables(mut vm)!
	assert labelled_eval(mut vm, 'var count=0;outer:for(let a of iterable([1,2],"o")){for(let b of iterable([3,4],"i")){count++;break outer}}count===1&&closed==="io"&&typeof a==="undefined"&&typeof b==="undefined"')!.as_bool()
	assert labelled_eval(mut vm, 'closed="";var count=0;outer:for(let a of iterable([1,2],"o")){for(let b of iterable([3,4],"i")){count++;continue outer}}count===2&&closed==="ii"')!.as_bool()
	assert labelled_eval(mut vm, 'closed="";exit:{for(let a of iterable([1],"o"))for(let b of iterable([2],"i"))break exit}closed==="io"')!.as_bool()
}

fn test_break_from_inner_label_keeps_surrounding_iterator_open_even_without_a_body_block() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	labelled_iterables(mut vm)!
	assert labelled_eval(mut vm, 'var count=0;for(var a of iterable([1,2],"o"))exit:{count++;break exit}count===2&&closed===""')!.as_bool()
	assert labelled_eval(mut vm, 'var count=0;for(let a of iterable([1,2],"o")){exit:{for(let b of iterable([3],"i")){count++;break exit}}}count===2&&closed==="ii"')!.as_bool()
}

fn test_labelled_iterator_close_errors_escape_body_catches_but_reach_enclosing_handlers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	labelled_iterables(mut vm)!
	assert labelled_eval(mut vm, 'var reason={},source={[Symbol.iterator](){return {next(){return {value:1}},return(){closed+="x";throw reason}}}};function work(){try{outer:for(let a of iterable([1],"o"))for(let b of source){try{break outer}catch(e){closed+="bad"}}}catch(e){return e===reason}}work()&&closed==="xo"')!.as_bool()
	assert labelled_eval(mut vm, 'closed="";function work(){try{outer:for(let a of source){try{break outer}catch(e){closed+="bad"}}}catch(e){return e===reason}}work()&&closed==="x"')!.as_bool()
}

fn test_labelled_control_retains_async_suspension_scopes_and_native_cache_reuse() {
	directory := os.join_path(os.temp_dir(), 'vox-labels-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut expected := 0
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		labelled_eval(mut vm, 'var answer=0;async function work(){var sum=0;outer:for(let a of [20,22]){for(let b of [1,2]){sum+=await a;continue outer}}return sum}work().then(v=>answer=v)')!
		assert vm.global_object().get(mut vm, PropertyName.from_str('answer'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 0 { expected = stats.compiled_executables; assert expected >= 3 }
		else { assert stats.cache_hits == expected && stats.compiler_invocations == 0 && activity.entries > u64(expected) }
		vm.close_native_code()!
	}
}
