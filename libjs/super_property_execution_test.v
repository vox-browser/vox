// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn super_property_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'super-properties.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:100000})
}

fn test_super_methods_accessors_and_extracted_calls_keep_actual_receiver_and_home() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert super_property_eval(mut vm, 'class A{get value(){return this.number}set value(v){this.number=v}method(x){return this.number+x}}class B extends A{read(){return super.value}write(v){super.value=v;return this.number}call(){return super.method(2)}extract(){return super.method}}var b=new B();b.number=40;b.read()===40&&b.call()===42&&b.write(41)===41&&b.extract().call({number:40},2)===42&&B.prototype.read.call({number:42})===42')!.as_bool()
	assert super_property_eval(mut vm, 'var parent={method(){return this.answer}},o={__proto__:parent,answer:42,method(){return super.method()}};o.method()===42&&o.method.call({answer:7})===7')!.as_bool()
}

fn test_super_static_constructor_private_and_field_initializer_home_objects() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert super_property_eval(mut vm, 'class A{method(){return this.number}static method(){return this.number}get value(){return 42}static get value(){return 43}}class B extends A{number=42;field=super.value;arrow=()=>super.method();static number=41;static field=super.value;static call(){return super.method()+1}#read(){return super.method()}read(){return this.#read()}constructor(){super();this.fromConstructor=super.method()}}var b=new B();b.field===42&&B.field===43&&b.arrow()===42&&b.read()===42&&B.call()===42&&b.fromConstructor===42')!.as_bool()
}

fn test_super_computed_keys_resolve_this_before_key_and_base_after_key_evaluation() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert super_property_eval(mut vm, 'var touched=0;class A{}class B extends A{constructor(){var caught=false;try{super[(touched++,"value")]}catch(e){caught=e instanceof ReferenceError}super();this.correct=caught}}new B().correct&&touched===0')!.as_bool()
	assert super_property_eval(mut vm, 'var one={value:1},two={value:42},o={__proto__:one,read(){return super[(Object.setPrototypeOf(o,two),"value")]}};o.read()===42')!.as_bool()
	assert super_property_eval(mut vm, 'var a={value:1},b={value:2},o={__proto__:a,read(){return super.value}};o.read()===1&&(Object.setPrototypeOf(o,b),o.read()===2)')!.as_bool()
}

fn test_super_updates_logical_assignments_and_optional_calls_preserve_references() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert super_property_eval(mut vm, 'class A{get value(){return this.number}set value(v){this.number=v}method(x){return this.number+x}}class B extends A{number=40;run(){var old=super.value++;super.value+=1;var skipped=0;super.value||=(skipped++,99);return old===40&&this.number===42&&skipped===0&&super.method?.(0)===42&&super.missing?.(skipped++)===undefined&&skipped===0}}new B().run()')!.as_bool()
	assert super_property_eval(mut vm, 'class A{method(s,v){return this.number+v}}class B extends A{number=40;run(){return super.method`x\${2}`}}new B().run()===42')!.as_bool()
}

fn test_super_writes_define_receiver_properties_and_keep_native_errors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert super_property_eval(mut vm, 'class A{}A.prototype.value=1;class B extends A{write(){super.value=42}remove(){return delete super.value}}var b=new B();b.write();var rejected=false;try{b.remove()}catch(e){rejected=e instanceof ReferenceError}b.value===42&&A.prototype.value===1&&Object.hasOwn(b,"value")&&rejected')!.as_bool()
	assert super_property_eval(mut vm, 'var marker={},o={__proto__:{get value(){throw marker}},read(){return super.value}},same=false;try{o.read()}catch(e){same=e===marker}same')!.as_bool()
}

fn test_cached_super_properties_and_finally_run_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-super-properties-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert super_property_eval(mut vm, 'var cleaned=0;class A{method(x){return this.number+x}}class B extends A{number=40;run(){try{return super.method(2)}finally{cleaned++}}}new B().run()===42&&cleaned===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 4 && stats.compiler_invocations == 0 && activity.entries >= 4 }
		vm.close_native_code()!
	}
}
