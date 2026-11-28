// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn reflect_intrinsics_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'reflect-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_default_reflect_uses_native_properties_receivers_and_constructor_new_target() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reflect_intrinsics_eval(mut vm, 'var receiver={},target={get value(){return this===receiver},set value(v){this.saved=v}};Reflect.get(target,"value",receiver)&&Reflect.set(target,"value",42,receiver)&&receiver.saved===42&&Object.prototype.toString.call(Reflect)==="[object Reflect]"')!.as_bool()
	assert reflect_intrinsics_eval(mut vm, 'function C(a,b){this.sum=a+b;this.target=new.target}function N(){}var value=Reflect.construct(C,[20,22],N);Object.getPrototypeOf(value)===N.prototype&&value.target===N&&value.sum===42&&Reflect.apply(function(a,b){return this.value+a+b},{value:1},[20,21])===42')!.as_bool()
	assert reflect_intrinsics_eval(mut vm, 'var x={};Reflect.defineProperty(x,"a",{value:1,configurable:true})&&Reflect.has(x,"a")&&Reflect.getOwnPropertyDescriptor(x,"a").value===1&&Reflect.ownKeys(x)[0]==="a"&&Reflect.deleteProperty(x,"a")&&!Reflect.has(x,"a")&&Reflect.isExtensible(x)&&Reflect.preventExtensions(x)&&!Reflect.isExtensible(x)&&!Reflect.defineProperty(x,"b",{value:2})')!.as_bool()
}

fn test_reflect_constructor_checks_precede_observable_argument_list_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert reflect_intrinsics_eval(mut vm, 'var reads=0,args={get length(){reads++;throw 1}},n=0;for(var run of [()=>Reflect.construct({},args),()=>Reflect.construct(Number,args,undefined),()=>Reflect.apply({},null,args)])try{run()}catch(e){if(e instanceof TypeError)n++}n===3&&reads===0')!.as_bool()
}

fn test_cached_reflect_calls_load_native_code_without_compiler() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-reflect-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert reflect_intrinsics_eval(mut vm, 'function Wrapper(value){return Reflect.construct(Number,[value],new.target)}Wrapper.prototype=Object.create(Number.prototype);var n=new Wrapper(42);n instanceof Wrapper&&n.valueOf()===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
