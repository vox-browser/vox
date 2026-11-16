// SPDX-License-Identifier: BSD-2-Clause
module libjs

// A concrete constructor keeps its element kind and creator realm as traced
// record fields. The per-realm constructor graph needs no escaping V captures.
@[heap]
struct TypedArrayIntrinsicConstructor {
	object &Object
	realm_ &Realm
	kind BufferElementType
}

fn create_typed_array_intrinsic_constructor(mut vm VM, realm &Realm, kind BufferElementType, parent &Object) &Object {
	mut object := Object.create(realm, parent)
	object.class_name = 'Function'; object.native_callable = true
	function := &TypedArrayIntrinsicConstructor{object: object, realm_: realm, kind: kind}
	object.callable = FunctionObject(function)
	object.constructor = ConstructorFunction(function)
	object.set_function_length(3)
	object.set_function_name(mut vm, PropertyName.from_str(kind.typed_array_name()), none)
	return object
}

fn (function &TypedArrayIntrinsicConstructor) realm() ?&Realm { return function.realm_ }
fn (function &TypedArrayIntrinsicConstructor) name_for_call_stack() Utf16String { return utf16_string(function.kind.typed_array_name()) }

fn (mut function TypedArrayIntrinsicConstructor) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	caller := vm.current_context()
	mut stack := vm.interpreter_stack(); mark := stack.top()
	mut callee := stack.allocate(0, []Value{}, u32(arguments.len)) or { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
	defer { stack.deallocate(mark) }
	for index, argument in arguments { callee.set_argument(u32(index), argument) }
	callee.passed_argument_count = u32(arguments.len); callee.function = FunctionObject(&function); callee.realm = function.realm_; callee.this_value = this_value
	callee.lexical_environment = caller.lexical_environment; callee.variable_environment = caller.variable_environment; callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_current_context() }
	return call_typed_array_constructor(mut vm, function.kind)
}

fn (mut function TypedArrayIntrinsicConstructor) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	caller := vm.current_context()
	mut stack := vm.interpreter_stack(); mark := stack.top()
	mut callee := stack.allocate(0, []Value{}, u32(arguments.len)) or { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
	defer { stack.deallocate(mark) }
	for index, argument in arguments { callee.set_argument(u32(index), argument) }
	callee.passed_argument_count = u32(arguments.len); callee.function = FunctionObject(&function); callee.realm = function.realm_
	callee.lexical_environment = caller.lexical_environment; callee.variable_environment = caller.variable_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_current_context() }
	return construct_typed_array(mut vm, function.kind, new_target, typed_array_intrinsic_prototype_getter(function.kind))!.object
}
