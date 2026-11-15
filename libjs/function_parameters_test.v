// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn parameters_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'parameters.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000}) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_default_parameters_initialize_left_to_right_and_only_for_undefined() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parameters_eval(mut vm, 'var order="";function f(a=(order+="a",40),b=(order+="b",a+2)){return b};f()===42&&order==="ab"&&f(1,null)===null&&f(1,false)===false&&f(1,0)===0')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a,b=2,c){return a+b};f.length===1&&f(40)===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a,b=(a=42)){return a};f(1)===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=function(){},b=()=>1){return a.name+":"+b.name};f()==="a:b"')!.as_bool()
	assert parameters_eval(mut vm, 'function Box(a=42){this.value=a};new Box().value===42')!.as_bool()
}

fn test_default_parameter_tdz_and_body_environment_separation() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for declaration in ['function f(a=a){}', 'function f(a=b,b=1){}', 'function f(a=typeof b,b=1){}', 'function f(a=inside){var inside=42}', 'function f(a=inside()){function inside(){return 42}}'] {
		assert parameters_eval(mut vm, declaration+';var caught=false;try{f()}catch(e){caught=e instanceof ReferenceError};caught')!.as_bool()
	}
	assert parameters_eval(mut vm, 'function f(a=1,b=()=>a){var a;a=42;return b()};f()===1')!.as_bool()
	assert parameters_eval(mut vm, 'var outside=42;function f(a=()=>outside){var outside=1;return a()};f()===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=1,b=()=>a){var a;return a===1&&b()===1};f()')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=1){try{throw 2}catch(e){return a+e}};f(40)===42')!.as_bool()
}

fn test_rest_parameters_make_fresh_arrays_without_mapping_arguments() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parameters_eval(mut vm, 'function f(a,...rest){rest[0]=40;arguments[0]=99;return a===1&&rest.length===2&&Array.isArray(rest)&&rest[0]+rest[1]===42&&arguments.length===3};f(1,2,2)&&f.length===1')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a,...rest){return rest};f().length===0&&f(1)!==f(1)')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=1){var caught=false;try{arguments.callee}catch(e){caught=e instanceof TypeError};arguments[0]=2;return caught&&a===1};f(1)')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=arguments){var arguments;return a===arguments};f()')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=()=>arguments){var arguments=42;return typeof a()==="object"&&arguments===42};f()')!.as_bool()
}

fn test_parameter_patterns_defaults_rest_and_iterator_closing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parameters_eval(mut vm, 'function f({a:x=40,n:{b=2},...rest}={n:{}}){return x+b+(rest.extra||0)};f()===42&&f({a:20,n:{b:20},extra:2})===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f([a=40,,...rest]){return a+rest[0]};f([undefined,1,2])===42')!.as_bool()
	assert parameters_eval(mut vm, 'var closed=0,o={};o[Symbol.iterator]=function(){return {next:function(){return {value:42,done:false}},return:function(){closed++;return {}}}};function f([a]){return a};f(o)===42&&closed===1')!.as_bool()
	assert parameters_eval(mut vm, 'var closed=0,o={};o[Symbol.iterator]=function(){return {next:function(){return {value:undefined,done:false}},return:function(){closed++;return {}}}};function fail(){throw 42};function f([a=fail()]){};var caught=false;try{f(o)}catch(e){caught=e===42};caught&&closed===1')!.as_bool()
}

fn test_arrow_parameter_expressions_keep_lexical_arguments_and_this() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert parameters_eval(mut vm, 'function f(a){return ((b=arguments[0])=>b)()};f(42)===42')!.as_bool()
	assert parameters_eval(mut vm, 'var o={value:42,f:function(){return ((a=this.value)=>a)()}};o.f()===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f({arguments}){return arguments};f({arguments:42})===42')!.as_bool()
	assert parameters_eval(mut vm, 'function f(a=arguments[0]){function arguments(){return 42};return arguments()};f()===42')!.as_bool()
}

fn test_non_simple_parameters_reuse_native_code_in_a_fresh_vm() {
	directory := os.join_path(os.temp_dir(), 'vox-parameters-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert parameters_eval(mut vm, 'function f({a=1}={},...rest){return a+rest[0]};f(undefined,41)')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
