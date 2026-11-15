// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn super_spread_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'super-spread.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_super_spread_combines_scalar_rest_and_unicode_values_with_fields_and_new_target() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert super_spread_eval(mut vm, 'class Base{constructor(...values){this.values=values;this.target=new.target}}class Child extends Base{answer=42;#secret=43;constructor(...args){super(0,...args,..."A😀B",9)}read(){return this.#secret}}var child=new Child(20,21);child instanceof Child&&child instanceof Base&&child.target===Child&&child.values.length===7&&child.values.join(":")==="0:20:21:A:😀:B:9"&&child.answer===42&&child.read()===43')!.as_bool()
	assert super_spread_eval(mut vm, 'class Empty extends Base{constructor(){super(...[],...new Set([1,2,1]))}}new Empty().values.join(":")==="1:2"')!.as_bool()
}

fn test_super_spread_captures_superclass_before_ordered_observable_argument_iteration() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert super_spread_eval(mut vm, 'var log="",source={};class Base{constructor(a,b,c){log+="b";this.values=[a,b,c]}}class Other{constructor(){throw 99}}class Child extends Base{constructor(){super(mark("a"),...source,mark("z"))}}function mark(v){log+=v;return v}Object.defineProperty(source,Symbol.iterator,{get(){log+="g";return function(){log+="i";Object.setPrototypeOf(Child,Other);var n=0;return {get next(){log+="n";return function(){log+="s";n++;return {get done(){log+="d";return n>1},get value(){log+="v";return 42}}}}}}}});var child=new Child();log==="aginsdvsdzb"&&child.values.join(":")==="a:42:z"&&Object.getPrototypeOf(Child)===Other&&child instanceof Base')!.as_bool()
	assert super_spread_eval(mut vm, 'var count=0;class Bad extends Base{constructor(){super(...(count++,[1]))}}Object.setPrototypeOf(Bad,null);var caught=false;try{new Bad()}catch(e){caught=e instanceof TypeError}caught&&count===1')!.as_bool()
}

fn test_super_spread_abrupt_iterators_preserve_original_exception_and_super_side_effects() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert super_spread_eval(mut vm, 'var marker={},closed=0,later=0,calls=0,source={};source[Symbol.iterator]=function(){return {next(){throw marker},return(){closed++;return {}}}};class Base{constructor(){calls++}}class Child extends Base{constructor(value){super(...value,later++)}}var caught=false;try{new Child(source)}catch(e){caught=e===marker}caught&&closed===0&&later===0&&calls===0')!.as_bool()
	assert super_spread_eval(mut vm, 'var failures=0;for(var value of [null,undefined,{},42])try{new Child(value)}catch(e){if(e instanceof TypeError)failures++}failures===4&&later===0&&calls===0')!.as_bool()
	assert super_spread_eval(mut vm, 'class Twice extends Base{constructor(){super(...[]);try{super(...[])}catch(e){this.duplicate=e instanceof ReferenceError}}}var twice=new Twice();twice.duplicate&&calls===2')!.as_bool()
}

fn test_default_derived_constructor_forwards_arguments_without_array_iteration() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert super_spread_eval(mut vm, 'var marker={},original=Array.prototype[Symbol.iterator];class Base{constructor(a,b){this.sum=a+b}}class Default extends Base{}class Explicit extends Base{constructor(...values){super(...values)}}Array.prototype[Symbol.iterator]=function(){throw marker};var value=new Default(20,22),caught=false;try{new Explicit(20,22)}catch(e){caught=e===marker}Array.prototype[Symbol.iterator]=original;value.sum===42&&caught')!.as_bool()
}

fn test_super_spread_infinite_iterator_uses_shared_budget_and_restores_frames() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	super_spread_eval(mut vm, 'var infinite={};infinite[Symbol.iterator]=function(){return {next(){return {value:1,done:false}}}};class Base{constructor(a){this.a=a}}class Child extends Base{constructor(value){super(...value)}}')!
	mut script := Script.parse('new Child(infinite)', vm.realm(), 'super-spread-budget.js', unsafe { nil })!
	if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100}) { assert false }
	else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	assert super_spread_eval(mut vm, 'new Child([42]).a')!.number == 42
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_super_spread_native_cache_executes_in_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-super-spread-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert super_spread_eval(mut vm, 'class Base{constructor(a,b){this.answer=a+b}}class Child extends Base{constructor(...values){super(...values)}}new Child(20,22).answer===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
