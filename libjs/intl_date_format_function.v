// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/Intl/DateTimeFormatFunction.{h,cpp}. A regular traced record retains
// [[DateTimeFormat]]; an escaping V closure would instead root each formatter
// through the process-wide trampoline registry after the JS object dies.
@[heap]
struct IntlDateTimeFormatFunction {
	object &Object
	formatter &IntlDateTimeFormat
	realm_ &Realm
}

fn create_intl_date_format_function(mut vm VM, formatter &IntlDateTimeFormat) &Object {
	mut object := Object.create(vm.realm(), vm.realm().function_prototype)
	object.class_name = 'Function'
	object.native_callable = true
	function := &IntlDateTimeFormatFunction{object: object, formatter: formatter, realm_: vm.realm()}
	object.callable = FunctionObject(function)
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str(''), none)
	return object
}

fn (function &IntlDateTimeFormatFunction) realm() ?&Realm { return function.realm_ }
fn (function &IntlDateTimeFormatFunction) name_for_call_stack() Utf16String { return Utf16String.new() }

fn (mut function IntlDateTimeFormatFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	caller := vm.running_execution_context()
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut callee := stack.allocate(0, []Value{}, u32(arguments.len)) or { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
	defer { stack.deallocate(mark) }
	for index, argument in arguments { callee.set_argument(u32(index), argument) }
	callee.passed_argument_count = u32(arguments.len)
	callee.function = FunctionObject(&function)
	callee.realm = function.realm_
	callee.this_value = this_value
	callee.lexical_environment = caller.lexical_environment
	callee.variable_environment = caller.variable_environment
	callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_execution_context() }
	input := if arguments.len > 0 { arguments[0] } else { js_undefined() }
	parts := intl_format_date_parts(mut vm, function.formatter, input)!
	mut text := ''
	for part in parts { text += part.value }
	return Value.from_string(vm.create_string_from_str(text))
}
