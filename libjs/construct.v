module libjs

// Runtime/Value.cpp::IsConstructor. Only callable objects can expose [[Construct]].
pub fn (value Value) is_constructor() bool {
	return value.is_function() && value.as_object().constructor != none
}

// AbstractOperations.cpp::construct_impl. Native and bound records allocate or
// forward their own frame in this port, as on the translated [[Call]] path.
// The entry checks follow Interpreter/SlowPaths.cpp's Construct call validation.
pub fn construct(mut vm VM, function Value, arguments []Value, new_target ?&Object) !&Object {
	if !function.is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, function.str())
	}
	object := function.as_object()
	target := new_target or { object }
	if voidptr(target) != voidptr(object) && !Value.from_object(target).is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, Value.from_object(target).str())
	}
	mut constructor := object.constructor or { panic('constructor slot missing') }
	return constructor.internal_construct(mut vm, arguments, target)
}

// Runtime/NativeFunction.cpp::internal_construct, ordinary native subclass path.
// NativeJavaScriptBackedFunction's function-environment path remains separate.
pub fn (mut function NativeFunction) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	assert function.has_constructor()
	caller := vm.current_context()
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut callee := stack.allocate_reusable(0, []Value{}, u32(arguments.len)) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	callee.copy_call_arguments(arguments)
	callee.passed_argument_count = u32(arguments.len)
	callee.function = FunctionObject(&function)
	callee.realm = function.realm_
	callee.lexical_environment = caller.lexical_environment
	callee.variable_environment = caller.variable_environment
	// [[ThisValue]] stays uninitialized, and ScriptOrModule stays empty.
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_current_context() }
	return function.construct_behaviour(mut vm, new_target)
}
