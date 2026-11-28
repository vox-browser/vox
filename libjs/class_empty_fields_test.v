// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn empty_fields_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'empty-fields.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})!
}

fn check_empty_fields(source string) !bool {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	return empty_fields_eval(mut vm, source)!.as_bool()
}

fn test_empty_public_fields_define_own_data_before_base_parameters_and_body() {
	assert check_empty_fields('class C{x;constructor(a=Object.hasOwn(this,"x")){this.saw=a}}var c=new C(),d=Object.getOwnPropertyDescriptor(c,"x");c.saw&&c.x===undefined&&d.writable&&d.enumerable&&d.configurable')!
	assert check_empty_fields('var calls=0;class C{x;set x(v){calls++}}var a=new C(),b=new C();a.x=42;calls===0&&a.x===42&&b.x===undefined&&Object.hasOwn(b,"x")')!
	assert check_empty_fields('class C{["__proto__"]}var c=new C();Object.hasOwn(c,"__proto__")&&c.__proto__===undefined&&Object.getPrototypeOf(c)===C.prototype')!
}

fn test_empty_derived_fields_initialize_after_super_and_before_remaining_body() {
	assert check_empty_fields('class B{constructor(){this.x=42}}class C extends B{x;constructor(){super();this.saw=this.x===undefined;this.x=43}}var c=new C();c.saw&&c.x===43')!
	assert check_empty_fields('class B{constructor(){this.x=42}}class C extends B{x}Object.hasOwn(new C(),"x")&&new C().x===undefined')!
	assert check_empty_fields('class C extends Object{x;constructor(){return {answer:42}}}var c=new C();c.answer===42&&!Object.hasOwn(c,"x")')!
	assert check_empty_fields('class B{x;constructor(){return {answer:42}}}class C extends B{y}var c=new C();!Object.hasOwn(c,"x")&&Object.hasOwn(c,"y")&&c.answer===42')!
	assert check_empty_fields('class B{constructor(){return Object.preventExtensions({})}}class C extends B{x;constructor(){var caught=false;try{super()}catch(e){caught=e instanceof TypeError};if(!caught)throw 1;return this}}var c=new C();!Object.hasOwn(c,"x")&&!Object.isExtensible(c)')!
}

fn test_computed_field_keys_evaluate_once_and_keep_tdz_strictness_and_symbols() {
	assert check_empty_fields('var count=0,s=Symbol("x");function key(){count++;return s};class C{[key()];[1];["quoted"]}var a=new C(),b=new C();count===1&&Object.hasOwn(a,s)&&Object.hasOwn(b,s)&&Object.hasOwn(a,"1")&&Object.hasOwn(a,"quoted")')!
	assert check_empty_fields('var caught=false;try{class C{[C]}}catch(e){caught=e instanceof ReferenceError};caught')!
	assert check_empty_fields('var caught=false;try{class C{[undeclaredFieldKey=1]}}catch(e){caught=e instanceof ReferenceError};caught&&typeof undeclaredFieldKey==="undefined"')!
}

fn test_empty_static_fields_initialize_after_methods_with_data_descriptors() {
	assert check_empty_fields('class C{static x;static x(){return 42}static name;static length}var d=Object.getOwnPropertyDescriptor(C,"x");C.x===undefined&&C.name===undefined&&C.length===undefined&&d.writable&&d.enumerable&&d.configurable')!
	assert check_empty_fields('class B{static x(){return 42}}class C extends B{static x}Object.hasOwn(C,"x")&&C.x===undefined&&B.x()===42')!
}

fn test_empty_fields_reuse_persisted_native_entries_in_a_fresh_vm() {
	directory := os.join_path(os.temp_dir(), 'vox-empty-fields-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert empty_fields_eval(mut vm, 'class C{value;static kind;constructor(v){this.value=v}read(){return this.value}}new C(42).read()')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
