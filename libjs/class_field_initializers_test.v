// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn field_init_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'field-initializers.js', unsafe { nil }) or {
		if is_throw_completion(err) {
			value := thrown_value(err)
			if value.is_object() { return error(value.as_object().error_message() or { err.msg() }) }
		}
		return err
	}
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000}) or {
		if is_throw_completion(err) {
			value := thrown_value(err)
			if value.is_object() { return error(value.as_object().error_message() or { err.msg() }) }
		}
		return err
	}
}

fn check_field_initializer(source string) !bool {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	return field_init_eval(mut vm, source)!.as_bool()
}

fn test_class_field_initializers_run_per_receiver_before_base_body() {
	assert check_field_initializer('var count=0;class C{x=++count;y=this.x+1;items=[];constructor(a=this.y){this.saw=a}}var a=new C(),b=new C();a.x===1&&b.x===2&&a.y===2&&b.y===3&&a.saw===2&&a.items!==b.items')!
	assert check_field_initializer('var calls=0;class C{x=42;set x(v){calls++}}var c=new C(),d=Object.getOwnPropertyDescriptor(c,"x");calls===0&&d.value===42&&d.writable&&d.enumerable&&d.configurable')!
}

fn test_field_initializers_capture_class_environment_not_constructor_parameters() {
	assert check_field_initializer('var x=42;class C{a=x;self=C;read=()=>this.a;constructor(x){this.body=x}}var c=new C(7);c.a===42&&c.body===7&&c.self===C&&c.read()===42&&c.read.name==="read"')!
	assert check_field_initializer('function factory(x){return class Named{value=x;self=Named;target=new.target}}var C=factory(42),c=new C();c.value===42&&c.self===C&&c.target===undefined&&!Object.hasOwn(C.prototype,"value")')!
}

fn test_derived_fields_run_after_super_before_remaining_body_and_retain_bind_this_on_failure() {
	assert check_field_initializer('var order="";class B{x=(order+="b",1);constructor(){order+="B"}}class C extends B{x=(order+="c",2);constructor(){order+="s";super();order+="C"}}var c=new C();order==="sbBcC"&&c.x===2')!
	assert check_field_initializer('class B{constructor(){return {answer:42}}}class C extends B{x=this.answer+1}new C().x===43')!
	assert check_field_initializer('var count=0;class C extends Object{x=(count++,42);constructor(){return {answer:7}}}new C().answer===7&&count===0')!
	assert check_field_initializer('var caught=false;class C extends Object{x=(()=>{throw 42})();constructor(){try{super()}catch(e){caught=e===42};this.ok=7}}new C().ok===7&&caught')!
}

fn test_static_initializers_run_in_order_after_keys_and_methods_with_class_this() {
	assert check_field_initializer('var order="",count=0;function key(){order+="k";return "x"}class C{static [key()]=(order+="i",42);static y=(order+="j",this.x+1);static same=this;static methodValue=this.method();static method(){return this.y}}order==="kij"&&C.y===43&&C.same===C&&C.methodValue===43')!
	assert check_field_initializer('var count=0,s=Symbol("field");function key(){count++;return s}class C{[key()]=function(){};static f=()=>this}var a=new C(),b=new C();count===1&&a[s]!==b[s]&&a[s].name==="[field]"&&C.f()===C')!
}

fn test_field_initializers_are_strict_and_stop_after_abrupt_completion() {
	assert check_field_initializer('var caught=false;class C{x=undeclaredField=1}try{new C()}catch(e){caught=e instanceof ReferenceError};caught&&typeof undeclaredField==="undefined"')!
	assert check_field_initializer('var count=0,caught=false;function fail(){throw 42}class C{x=fail();y=++count}try{new C()}catch(e){caught=e===42};caught&&count===0')!
}

fn test_field_initializer_bytecode_validation_and_shared_instruction_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('class C{x=42}', vm.realm(), 'invalid-field.js', unsafe { nil })!
	mut executable := script.compile(mut vm)!
	for mut instruction in executable.instructions {
		if instruction.op == .new_class_field_initializer { instruction.identifier = 0xffffffff }
	}
	if _ := executable.validate(0) { assert false } else { assert err.msg() == 'Class field initializer index out of range' }
	if _ := field_init_eval(mut vm, 'function spin(){while(true){}}class Forever{x=spin()}new Forever()') { assert false }
	assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
}

fn test_field_initializer_native_entries_reuse_in_a_fresh_vm_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-field-init-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert field_init_eval(mut vm, 'var count=0;class B{x=++count}class C extends B{y=this.x+40;static kind="cached"}var a=new C(),b=new C();a.y===41&&b.y===42&&C.kind==="cached"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 4 && stats.compiler_invocations == 0 && activity.entries >= 4 }
		vm.close_native_code()!
	}
}
