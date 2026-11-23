module libjs

import platform

// Where call_body() stores each register parameter and which function-scope
// var names still need environment bindings. Closure instances share one
// compiled body and its immutable register metadata, so the plan is built once
// per body instead of scanning the register bindings for every parameter and
// hashing every var name on each call. A recompiled or reloaded body (new
// register metadata) rebuilds it.
@[heap]
struct FunctionCallPlan {
	bindings         voidptr
	count            int
	parameter_slots  []i64
	environment_vars []Utf16String
}

@[inline]
fn (function &ECMAScriptFunction) call_plan(executable &Executable) &FunctionCallPlan {
	if plan := executable.call_plan {
		if plan.bindings == function.register_bindings.data
			&& plan.count == function.register_bindings.len
			&& plan.parameter_slots.len == function.data.parameters.len {
			return plan
		}
	}
	return function.build_call_plan(executable)
}

fn (function &ECMAScriptFunction) build_call_plan(executable &Executable) &FunctionCallPlan {
	persistent := platform.enter_persistent()
	mut slots := []i64{len: function.data.parameters.len, init: -1}
	// parameter_register(): the first binding for each parameter index.
	for binding in function.register_bindings {
		index := binding.parameter_index
		if index >= 0 && index < slots.len && slots[index] < 0 { slots[index] = i64(binding.slot) }
	}
	mut variables := []Utf16String{}
	for binding in executable.global_bindings {
		if !function.variable_in_register(binding.name) { variables << binding.name }
	}
	plan := &FunctionCallPlan{
		bindings:         function.register_bindings.data
		count:            function.register_bindings.len
		parameter_slots:  slots
		environment_vars: variables
	}
	platform.leave_persistent(persistent)
	mut owner := unsafe { &Executable(executable) }
	owner.call_plan = plan
	return plan
}

// FunctionDeclarationInstantiation step 27's var bindings for a simple
// parameter list, initialized to undefined unless a parameter already bound it.
fn initialize_function_var(mut vm VM, mut environment FunctionEnvironment, name Utf16String) ! {
	if use_direct_call_bindings() {
		environment.initialize_call_var(mut vm, name)!
		return
	}
	if !environment.has_binding_named(name) {
		environment.create_mutable_binding(mut vm, name, false)!
		environment.initialize_binding(mut vm, name, js_undefined(), .normal)!
	}
}
