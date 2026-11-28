module libjs

fn call_plan_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'call-plan.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 200000 })
}

// Register parameters, environment parameters and vars, captured vars and
// closures sharing one compiled body keep their FunctionDeclarationInstantiation values.
fn test_call_plan_preserves_parameters_and_var_bindings() {
	for enabled in [false, true] {
		set_register_call_metadata_for_testing(enabled)
		for source, expected in {
			'function f(a,b){var c=1,d=2,e=3,g=4,h=5,i=6,j=7,k=8;return a+b+c+d+e+g+h+i+j+k}f(1,2)+f(3,4)':                 82.0
			'function f(a,b){var c=1,d=2,e=3,g=4,h=5,i=6,j=7,k=8,m;return typeof m=="undefined"&&b===undefined?a:0}f(42)': 42.0
			'function f(a){var a;return a}f(42)':                                                                       42.0
			'function f(a,b){var a,b,c,d,e,g,h,i,j;return a+b}f(40,2)':                                                 42.0
			'function f(a){var x=1,y=2,z=3,w=4,v=5,u=6,t=7,s=8,r=9;var g=function(){return a+x};return g()}f(41)':     42.0
			'function f(a){var x=1,y=2,z=3,w=4,v=5,u=6,t=7,s=8,captured=34;function g(){return captured+x+y+z}return g()+a-a}f(0)': 40.0
			'function mk(n){return function(a){var b=1,c=2,d=3,e=4,g=5,h=6,i=7,j=8;return a+n+b+c+d+e+g+h+i+j}}mk(1)(1)+mk(2)(2)': 78.0
			'function f(a,a){var b=1,c=2,d=3,e=4,g=5,h=6,i=7,j=8;return a}f(1,42)':                                    42.0
			'function f(a,b=a){var c=1,d=2,e=3,g=4,h=5,i=6,j=7,k=8;return a+b}f(21)':                                  42.0
			'function f(){var n=0;for(var i=0;i<20;i++){n+=g(i)}return n}function g(a){var b=a,c,d,e,h,i2,j,k,l;return b}f()': 190.0
		} {
			actual := call_plan_eval(source)!
			assert actual.is_number(), source
			assert actual.number == expected, '${enabled}: ${source}: ${actual.number}'
		}
	}
	set_register_call_metadata_for_testing(true)
}

// The plan belongs to the compiled body and its register metadata.
fn test_call_plan_is_shared_by_closures_and_rebuilt_for_new_metadata() {
	set_register_call_metadata_for_testing(true)
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function mk(n){return function(a){var b=1,c=2,d=3,e=4,g=5,h=6,i=7,j=8;return a+n+b+c+d+e+g+h+i+j}}var p=mk(1),q=mk(2);p(1)+q(2)',
		vm.realm(), 'call-plan-shared.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 78
	global := script.realm.global_object or { panic('Missing global') }
	mut functions := []&ECMAScriptFunction{}
	for name in ['p', 'q'] {
		value := global.internal_get(mut vm, PropertyName.from_str(name), Value.from_object(global))!
		callable := value.as_object().callable or { panic('Missing function') }
		if callable is ECMAScriptFunction { functions << callable } else { assert false }
	}
	first := functions[0].executable or { panic('Missing bytecode') }
	second := functions[1].executable or { panic('Missing bytecode') }
	assert voidptr(first) == voidptr(second)
	plan := first.call_plan or { panic('Missing call plan') }
	assert plan.parameter_slots.len == 1 && plan.parameter_slots[0] >= 0
	assert plan.environment_vars.len == 0
	assert voidptr(functions[0].call_plan(first)) == voidptr(plan)
	// Replacement register metadata (a reloaded body) gets its own plan.
	mut changed := functions[1]
	changed.register_bindings = changed.register_bindings.clone()
	rebuilt := changed.call_plan(second)
	assert voidptr(rebuilt) != voidptr(plan) && rebuilt.parameter_slots == plan.parameter_slots
}
