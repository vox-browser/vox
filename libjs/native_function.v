module libjs

import math

// Runtime/NativeFunction.{h,cpp}, FunctionObject.cpp, and the native-function
// branch of AbstractOperations.cpp::call_impl. The V FunctionObject interface
// passes arguments directly, so this [[Call]] allocates its own callee frame.
// Hosts supply the realm and prototype explicitly while Intrinsics is pending.
@[heap]
pub struct NativeFunction {
pub:
	object             &Object
	realm_             &Realm
	name               Utf16String
	behaviour          NativeFunctionPointer = unsafe { nil }
	raw_function_index ?u32
}

pub type FunctionName = PrivateName | PropertyName

fn make_function_name(name FunctionName, prefix ?string) Utf16String {
	mut text := Utf16String.new()
	match name {
		PrivateName {
			text = name.description
		}
		PropertyName {
			if name.is_symbol() {
				if description := name.as_symbol().description {
					text = utf16_concat([utf16_string('['), description, utf16_string(']')])
				}
			} else {
				text = if name.is_string() {
					name.as_string()
				} else {
					utf16_string(name.number.str())
				}
			}
		}
	}

	if value := prefix { text = utf16_concat([utf16_string(value + ' '), text]) }
	return text
}

// FunctionObject.cpp::SetFunctionLength and SetFunctionName. These are
// non-writable, non-enumerable, configurable data properties.
pub fn (mut object Object) set_function_length(length f64) {
	assert length >= 0 && (math.trunc(length) == length || math.is_inf(length, 1))
	assert object.extensible && !object.has_own_property(PropertyName.from_str('length'))
	object.define_direct_property(PropertyName.from_str('length'), Value.from_f64(length),
		attribute_configurable)
}

pub fn (mut object Object) set_function_name(mut vm VM, name FunctionName, prefix ?string) Utf16String {
	assert object.extensible && !object.has_own_property(PropertyName.from_str('name'))
	text := make_function_name(name, prefix)
	if object.native_callable { object.native_initial_name = text }
	object.define_direct_property(PropertyName.from_str('name'),
		Value.from_string(vm.create_string(text)), attribute_configurable)
	return text
}

// CapturingNativeFunction stores the closure directly. The raw variant uses
// VM::register_native_function and the table's type check on every invocation.
pub fn NativeFunction.create(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, length f64, name FunctionName, prefix ?string) &NativeFunction {
	assert behaviour != unsafe { nil }
	mut object := Object.create(realm, prototype)
	object.class_name = 'Function'
	object.native_callable = true
	object.set_function_length(length)
	text := object.set_function_name(mut vm, name, prefix)
	function := &NativeFunction{
		object:    object
		realm_:    realm
		name:      text
		behaviour: behaviour
	}
	object.callable = FunctionObject(function)
	return function
}

pub fn NativeFunction.create_raw(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, length f64, name FunctionName, prefix ?string) &NativeFunction {
	assert behaviour != unsafe { nil }
	mut object := Object.create(realm, prototype)
	object.class_name = 'Function'
	object.native_callable = true
	object.set_function_length(length)
	text := object.set_function_name(mut vm, name, prefix)
	function := &NativeFunction{
		object:             object
		realm_:             realm
		name:               text
		raw_function_index: vm.register_native_function(behaviour, .raw_native_function)
	}
	object.callable = FunctionObject(function)
	return function
}

pub fn (function &NativeFunction) name_for_call_stack() Utf16String {
	return function.name
}

pub fn (function &NativeFunction) initial_name() ?Utf16String {
	return function.object.native_initial_name
}

pub fn (function &NativeFunction) realm() ?&Realm {
	return function.realm_
}

pub fn (function &NativeFunction) is_strict_mode() bool {
	return true
}

pub fn (function &NativeFunction) has_constructor() bool {
	return false
}

pub fn (mut function NativeFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	caller := vm.running_execution_context()
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut callee := stack.allocate(0, []Value{}, u32(arguments.len)) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	for i, argument in arguments {
		callee.set_argument(u32(i), argument)
	}
	callee.passed_argument_count = u32(arguments.len)
	callee.function = FunctionObject(&function)
	callee.realm = function.realm_
	callee.this_value = this_value
	callee.lexical_environment = caller.lexical_environment
	callee.variable_environment = caller.variable_environment
	callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
	defer { vm.pop_execution_context() }
	behaviour := if index := function.raw_function_index {
		vm.native_function(index, .raw_native_function)
	} else {
		function.behaviour
	}
	return behaviour(mut vm)
}

// 7.3.14 Call, AbstractOperations.cpp. Only callable objects have [[Call]].
pub fn call(mut vm VM, function Value, this_value Value, arguments []Value) !Value {
	if !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	mut callable := function.as_function()
	return callable.internal_call(mut vm, this_value, arguments)
}
