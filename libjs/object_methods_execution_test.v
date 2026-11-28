// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn methods_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'object-methods.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!
}

fn test_object_accessors_merge_descriptors_and_use_the_actual_receiver() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert methods_eval(mut vm, 'var o={value:1,get x(){return this.value},set x(v){this.value=v}};o.x=42;var d=Object.getOwnPropertyDescriptor(o,"x"),child=Object.create(o);child.value=7;o.x===42&&child.x===7&&d.enumerable&&d.configurable&&d.get.name==="get x"&&d.set.name==="set x"&&d.get.length===0&&d.set.length===1&&!("value" in d)')!.as_bool()
	assert methods_eval(mut vm, 'var o={get x(){return 1},set x(v){this.stored=v},get x(){return 42}};o.x=7;o.x===42&&o.stored===7')!.as_bool()
	assert methods_eval(mut vm, 'var a={get x(){return 1},x:42},b={x:1,get x(){return 42}};a.x===42&&b.x===42&&Object.getOwnPropertyDescriptor(a,"x").writable&&Object.getOwnPropertyDescriptor(b,"x").get.name==="get x"')!.as_bool()
}

fn test_object_methods_are_named_non_constructors_and_enumerable() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert methods_eval(mut vm, 'var o={x:42,read(){return this.x},plain:function(){}};var d=Object.getOwnPropertyDescriptor(o,"read"),caught=false;try{new o.read()}catch(e){caught=e instanceof TypeError};o.read()===42&&o.read.name==="read"&&caught&&d.writable&&d.enumerable&&d.configurable&&!Object.hasOwn(o.read,"prototype")&&Object.hasOwn(o.plain,"prototype")')!.as_bool()
	assert methods_eval(mut vm, 'var o={get x(){return typeof this}};Object.getOwnPropertyDescriptor(o,"x").get.call(1)==="object"')!.as_bool()
}

fn test_computed_accessor_keys_convert_once_and_symbol_names_keep_prefixes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert methods_eval(mut vm, 'var order="",s=Symbol("key"),key={toString(){order+="k";return "x"}};var o={get [key](){return 42},get [s](){return 7}};var d=Object.getOwnPropertyDescriptor(o,s);order==="k"&&o.x===42&&o[s]===7&&d.get.name==="get [key]"&&Object.keys(o).join()==="x"')!.as_bool()
	assert methods_eval(mut vm, 'var caught=false;try{var o={get x(){throw 42}};o.x}catch(e){caught=e===42};caught')!.as_bool()
}

fn test_object_methods_and_getters_execute_from_persisted_native_code() {
	directory := os.join_path(os.temp_dir(), 'vox-object-methods-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert methods_eval(mut vm, 'var o={value:42,get x(){return this.value},read(){return this.x}};o.read()')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 3 && stats.compiler_invocations == 0 && activity.entries >= 3 }
		vm.close_native_code()!
	}
}
