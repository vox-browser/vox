// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

// A traced bound function owns its formatter and creator realm without putting
// either in the permanent V closure-trampoline registry.
@[heap]
struct IntlNumberFormatFunction { object &Object; formatter &IntlNumberFormat; realm_ &Realm }

fn intl_number_format_getter(mut vm VM) !Value {
	mut formatter := intl_number_format_this(mut vm)!
	if bound := formatter.bound_format { return Value.from_object(bound) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := Object.create(vm.realm(), vm.realm().function_prototype)
	object.class_name = 'Function'; object.native_callable = true
	object.callable = FunctionObject(&IntlNumberFormatFunction{object: object, formatter: formatter, realm_: vm.realm()})
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str(''), none)
	formatter.bound_format = object
	return Value.from_object(object)
}

fn (function &IntlNumberFormatFunction) realm() ?&Realm { return function.realm_ }
fn (function &IntlNumberFormatFunction) name_for_call_stack() Utf16String { return Utf16String.new() }

fn (mut function IntlNumberFormatFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
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
	value := intl_mathematical_value(mut vm, if arguments.len > 0 { arguments[0] } else { js_undefined() })!
	return intl_number_parts_string(mut vm, intl_format_number_parts(mut vm, function.formatter, value)!)
}
