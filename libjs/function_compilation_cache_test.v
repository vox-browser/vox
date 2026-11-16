// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn function_cache_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'shared-functions.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_sibling_closures_share_compilation_but_retain_separate_environments_and_register_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_cache_eval(mut vm, 'function factory(value){return function add(x){return value+x}}var first=factory(10),second=factory(20);first(1)===11&&second(2)===22&&first(3)===13&&second(4)===24')!.as_bool()
	a := vm.global_object().get(mut vm, PropertyName.from_str('first'))!.as_function()
	b := vm.global_object().get(mut vm, PropertyName.from_str('second'))!.as_function()
	if a is ECMAScriptFunction {
		if b is ECMAScriptFunction {
			assert voidptr(a.executable?) == voidptr(b.executable?)
			assert a.register_bindings.len == b.register_bindings.len
		} else {
			assert false
		}
	} else {
		assert false
	}
	assert vm.realm().function_compilation_stats().reused > 0
}

fn test_shared_function_compilation_preserves_private_state_and_instance_specific_field_names() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_cache_eval(mut vm, 'function factory(value){return class Box{#value=value;read(){return this.#value}}}var A=factory(1),B=factory(2),a=new A,b=new B,denied=false;a.read();b.read();try{a.read.call(b)}catch(e){denied=e instanceof TypeError}a.read()===1&&b.read()===2&&denied')!.as_bool()
	assert function_cache_eval(mut vm, 'function make(key){return class{[key]=function(){return 1}}}var one=Symbol("one"),two=Symbol("two"),a=new (make(one)),b=new (make(two));a[one].name==="[one]"&&b[two].name==="[two]"&&a[one]()===1&&b[two]()===1')!.as_bool()
}

fn test_shared_frontend_syntax_keeps_compiled_constants_in_their_owning_realms() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	local := vm.realm()
	mut first := Script.parse('function factory(){return ()=>({})}var fn=factory();fn()', local, 'same.js', unsafe { nil })!
	a := vm.run(mut first)!
	create_simple_execution_context(mut vm)
	foreign := vm.realm()
	mut second := Script{ realm: foreign, filename: 'same.js', parsed: first.parsed, is_strict_mode: first.is_strict_mode }
	b := vm.run(mut second)!
	assert voidptr(a.as_object().internal_get_prototype_of()?) == voidptr(local.object_prototype_record())
	assert voidptr(b.as_object().internal_get_prototype_of()?) == voidptr(foreign.object_prototype_record())
	assert local.function_compilation_stats().entries > 0 && foreign.function_compilation_stats().entries > 0
}
