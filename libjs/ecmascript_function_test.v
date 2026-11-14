module libjs

fn execute_function_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'functions.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})
}

fn test_ecmascript_calls_hoist_capture_recurse_and_restore_frames() {
	for source, expected in {
		'answer(21); function answer(x){return x*2}': '42'
		'function fact(n){if(n<2)return 1; return n*fact(n-1)} fact(5)': '120'
		'function counter(x){return function(y){x+=y;return x}} var f=counter(1);f(20);f(21)': '42'
		'function f(){var x=41; function g(){return ++x} return g()} f()': '42'
		'function f(){return x; var x=42} f()': 'undefined'
		'function f(x){x=1; return function(){return x}} var g=f(2);g()': '1'
		'var f=function recur(n){return n ? recur(n-1)+1 : 0};f(42)': '42'
		'function f(){return (()=>this)()} f()===globalThis': 'true'
		'function f(){"use strict";return this} f()': 'undefined'
		'function f(a,b){return b} f(1)': 'undefined'
		'function f(){42} f()': 'undefined'
		'function f(){return 1} f=function(){return 42}; f()': '42'
		'function Box(x){this.x=x} var box=new Box(42);box.x': '42'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		value := execute_function_source(mut vm, source) or {
			if is_throw_completion(err) {
				thrown := thrown_value(err)
				if thrown.is_object() { eprintln(thrown.as_object().error_message() or { '' }) }
			}
			panic(source + ': ' + err.msg())
		}
		assert value.str() == expected, source
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_ecmascript_call_failures_and_shared_instruction_budget() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['function f(){throw 42} f()', 'function f(){while(true){}} f()',
		'function f(n){if(n)f(n-1)} f(100000)'] {
		if _ := execute_function_source(mut vm, source) { assert false }
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
		assert execute_function_source(mut vm, '6*7')!.str() == '42'
	}
}

fn test_direct_host_call_has_one_budget_and_restores_it_on_failure() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	execute_function_source(mut vm, 'function spin(){while(true){}} function answer(){return 42}')!
	spin := vm.get_global_object().get(mut vm, PropertyName.from_str('spin'))!
	if _ := vm.call_with_limits(spin, js_undefined(), [], ExecutionLimits{max_instructions: 100}) { assert false }
	assert !vm.instruction_budget_active
	assert vm.external_budget_depth == 0
	answer := vm.get_global_object().get(mut vm, PropertyName.from_str('answer'))!
	assert vm.call_with_limits(answer, js_undefined(), [], ExecutionLimits{max_instructions: 100})!.number == 42
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}
