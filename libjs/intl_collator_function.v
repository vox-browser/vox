// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

// [[Collator]] and [[Realm]] are ordinary traced record edges, not captures
// held forever by V's native-function trampoline registry.
@[heap]
struct IntlCollatorCompareFunction { object &Object; collator &IntlCollator; realm_ &Realm }

fn intl_collator_compare_getter(mut vm VM) !Value {
	mut collator := intl_collator_this(mut vm)!
	if bound := collator.bound_compare { return Value.from_object(bound) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := Object.create(vm.realm(), vm.realm().function_prototype)
	object.class_name = 'Function'; object.native_callable = true
	object.callable = FunctionObject(&IntlCollatorCompareFunction{object: object, collator: collator, realm_: vm.realm()})
	object.set_function_length(2)
	object.set_function_name(mut vm, PropertyName.from_str(''), none)
	collator.bound_compare = object
	return Value.from_object(object)
}

fn (function &IntlCollatorCompareFunction) realm() ?&Realm { return function.realm_ }
fn (function &IntlCollatorCompareFunction) name_for_call_stack() Utf16String { return Utf16String.new() }

fn (mut function IntlCollatorCompareFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	caller := vm.running_execution_context()
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut callee := stack.allocate(0, []Value{}, u32(arguments.len)) or { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
	defer { stack.deallocate(mark) }
	for index, argument in arguments { callee.set_argument(u32(index), argument) }
	callee.passed_argument_count = u32(arguments.len)
	callee.function = FunctionObject(&function); callee.realm = function.realm_; callee.this_value = this_value
	callee.lexical_environment = caller.lexical_environment; callee.variable_environment = caller.variable_environment; callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_execution_context() }
	left := vm.argument(0).to_primitive_string(mut vm)!
	right := vm.argument(1).to_primitive_string(mut vm)!
	return Value.from_i32(i32(intl_collation_compare(mut vm, left.utf16, right.utf16, function.collator.settings)!))
}
