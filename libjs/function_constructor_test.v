// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn function_constructor_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'function-constructor.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_function_intrinsic_identity_metadata_and_instanceof_cover_all_callable_families() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_constructor_eval(mut vm, r'var f=function(){},a=()=>1,b=f.bind(null),d=Object.getOwnPropertyDescriptor(globalThis,"Function");f instanceof Function&&a instanceof Function&&b instanceof Function&&parseInt instanceof Function&&Function instanceof Function&&Function.prototype.constructor===Function&&Function.length===1&&Function.name==="Function"&&Function.prototype()===undefined&&d.writable&&!d.enumerable&&d.configurable&&!Object.getOwnPropertyDescriptor(Function,"prototype").writable')!.as_bool()
}

fn test_dynamic_function_compiles_arguments_body_and_uses_global_not_callers_lexical_scope() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_constructor_eval(mut vm, r'var visible="global",f=(function(){let visible="local";return Function("a", "b=2", "return visible+\":\"+(a+b)")})();f(3)==="global:5"&&f.name==="anonymous"&&f.length===1&&Object.getPrototypeOf(f)===Function.prototype')!.as_bool()
	assert function_constructor_eval(mut vm, r'f.toString()')!.as_string().str() == 'function anonymous(a,b=2\n) {\nreturn visible+":"+(a+b)\n}'
	assert function_constructor_eval(mut vm, r'var Empty=Function(),C=new Function("value","this.value=value"),item=new C(7);Empty()===undefined&&item.value===7&&item instanceof C&&Function("return this")()===globalThis&&Function("\"use strict\";return this")()===undefined')!.as_bool()
}

fn test_dynamic_function_checks_separate_grammar_goals_and_preserves_coercion_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_constructor_eval(mut vm, r'var order="",f=Function({toString(){order+="p";return "a"}},{toString(){order+="b";return "return a"}}),n=0;for(var args of [["a){});(function injected(","return 1"],["a=1","\"use strict\";return a"],["a,a","\"use strict\";return a"],["return )"]])try{Function.apply(null,args)}catch(e){if(e instanceof SyntaxError)n++}order==="pb"&&f(8)===8&&n===4')!.as_bool()
	assert function_constructor_eval(mut vm, r'var sentinel={},seen=false;try{Function({toString(){throw sentinel}},"return 1")}catch(e){seen=e===sentinel}seen')!.as_bool()
}

fn test_dynamic_function_observes_new_target_prototype_after_parsing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert function_constructor_eval(mut vm, r'var proto={},reads=0,target=new Proxy(function(){},{get(t,k,r){if(k==="prototype"){reads++;return proto}return Reflect.get(t,k,r)}}),f=Reflect.construct(Function,["return 9"],target);Object.getPrototypeOf(f)===proto&&f()===9&&reads===1')!.as_bool()
}

fn test_dynamic_function_reuses_native_compilation_on_a_new_vm() {
	directory := os.join_path(os.temp_dir(), 'vox-dynamic-function-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert function_constructor_eval(mut vm, r'Function("a","return a+1")(41)===42')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && activity.entries > 0
		}
		vm.close_native_code()!
	}
}
