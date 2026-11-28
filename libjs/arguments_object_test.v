// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn arguments_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'arguments.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000}) or {
		if is_throw_completion(err) { return error(thrown_value(err).as_object().error_message() or { thrown_value(err).str() }) }
		return err
	}
}

fn test_arguments_expose_actual_values_length_callee_and_array_iterator_intrinsic() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert arguments_eval(mut vm, 'function f(a){var arguments;var d=Object.getOwnPropertyDescriptor(arguments,"length");return arguments.length===3&&arguments[0]===1&&arguments[2]===3&&arguments.callee===f&&Object.getPrototypeOf(arguments)===Object.prototype&&Object.prototype.toString.call(arguments)==="[object Arguments]"&&!Array.isArray(arguments)&&d.writable&&!d.enumerable&&d.configurable}f(1,2,3)')!.as_bool()
	assert arguments_eval(mut vm, 'var iterator=Array.prototype.values;Array.prototype.values=0;function g(){return arguments[Symbol.iterator]===iterator&&arguments[Symbol.iterator]().next().value===42}g(42)')!.as_bool()
	assert arguments_eval(mut vm, 'function zero(a){return arguments.length===0&&!Object.prototype.hasOwnProperty.call(arguments,"0")};zero()')!.as_bool()
}

fn test_sloppy_arguments_alias_parameters_and_only_last_duplicate_parameter() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert arguments_eval(mut vm, 'function f(a){arguments[0]=2;if(a!==2)return false;a=3;return arguments[0]===3&&Object.getOwnPropertyDescriptor(arguments,"0").value===3};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function duplicate(a,a){arguments[0]=7;if(a!==2)return false;a=3;return arguments[0]===7&&arguments[1]===3};duplicate(1,2)')!.as_bool()
	assert arguments_eval(mut vm, 'function absent(a,a){a=3;return arguments[0]===1&&!Object.prototype.hasOwnProperty.call(arguments,"1")};absent(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function inherited(a){var child=Object.create(arguments);child[0]=5;return a===1&&arguments[0]===1&&child[0]===5};inherited(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function escape(a){return [arguments,function(v){a=v}]};var pair=escape(1);pair[1](42);pair[0][0]===42')!.as_bool()
}

fn test_arguments_definition_and_deletion_detach_only_successful_mappings() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert arguments_eval(mut vm, 'function f(a){a=2;Object.defineProperty(arguments,"0",{writable:false});a=3;return arguments[0]===2&&!Object.getOwnPropertyDescriptor(arguments,"0").writable};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){Object.defineProperty(arguments,"0",{value:2,writable:false});if(a!==2)return false;a=3;return arguments[0]===2};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){Object.defineProperty(arguments,"0",{get:function(){return 9}});a=3;return arguments[0]===9};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){delete arguments[0];a=3;arguments[0]=4;return a===3&&arguments[0]===4};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){Object.defineProperty(arguments,"0",{configurable:false});var result=delete arguments[0];a=3;var caught=false;try{Object.defineProperty(arguments,"0",{get:function(){return 9}})}catch(e){caught=e instanceof TypeError};return !result&&caught&&arguments[0]===3};f(1)')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){Object.freeze(arguments);a=3;return arguments[0]===1};f(1)')!.as_bool()
}

fn test_strict_arguments_are_unmapped_and_have_restricted_callee() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert arguments_eval(mut vm, 'function f(a){"use strict";arguments[0]=2;if(a!==1)return false;a=3;var d=Object.getOwnPropertyDescriptor(arguments,"callee"),caught=0;try{arguments.callee}catch(e){if(e instanceof TypeError)caught++}try{arguments.callee=1}catch(e){if(e instanceof TypeError)caught++}return arguments[0]===2&&caught===2&&typeof d.get==="function"&&d.get===d.set&&!d.configurable&&!d.enumerable};f(1)')!.as_bool()
}

fn test_arguments_binding_shadowing_arrows_nested_calls_and_constructs() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert arguments_eval(mut vm, 'function f(arguments){return arguments};f(42)===42')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){let arguments=42;return arguments};f(1)===42')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){function arguments(){return 42};return arguments()};f(1)===42')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){return (b=>arguments[0])(9)};function strict(a){"use strict";return (()=>(()=>arguments[0])())()};f(42)===42&&strict(42)===42')!.as_bool()
	assert arguments_eval(mut vm, 'function f(a){return (()=>{var arguments;return arguments})()};f(42)===undefined')!.as_bool()
	assert arguments_eval(mut vm, 'function outer(a){function inner(){return arguments.length};return inner()===0&&arguments[0]===42};outer(42)')!.as_bool()
	assert arguments_eval(mut vm, 'function Box(a){this.value=arguments[0]};new Box(42).value===42')!.as_bool()
}

fn test_arguments_execute_from_persisted_native_code_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-arguments-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert arguments_eval(mut vm, 'function f(a){arguments[0]+=2;return a+arguments.length};f(39)')!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
