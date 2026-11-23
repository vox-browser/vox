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
	construct_behaviour NativeConstructPointer = unsafe { nil }
mut:
	iterator_step NativeIteratorStep = unsafe { nil }
	intrinsic_regexp_flag ?RegExpFlags
	intrinsic_regexp_exec bool
}

pub type NativeConstructPointer = fn (mut vm VM, new_target &Object) !&Object

pub type FunctionName = PrivateName | PropertyName

const function_name_key = PropertyName.from_str('name')
const function_length_key = PropertyName.from_str('length')

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
	assert object.extensible && !object.has_own_property(function_length_key)
	object.define_direct_property(function_length_key, Value.from_f64(length),
		attribute_configurable)
}

pub fn (mut object Object) set_function_name(mut vm VM, name FunctionName, prefix ?string) Utf16String {
	text := make_function_name(name, prefix)
	object.set_function_name_text(mut vm, text)
	return text
}

fn (mut object Object) set_function_name_text(mut vm VM, text Utf16String) {
	assert object.extensible && !object.has_own_property(function_name_key)
	if object.native_callable { object.native_initial_name = text }
	object.define_direct_property(function_name_key,
		Value.from_string(vm.create_string(text)), attribute_configurable)
}

// CapturingNativeFunction stores the closure directly. The raw variant uses
// VM::register_native_function and the table's type check on every invocation.
pub fn NativeFunction.create(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, length f64, name FunctionName, prefix ?string) &NativeFunction {
	return create_native_function(mut vm, realm, prototype, behaviour, length, name, prefix,
		unsafe { nil }, false, true)
}

pub fn NativeFunction.create_raw(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, length f64, name FunctionName, prefix ?string) &NativeFunction {
	return create_native_function(mut vm, realm, prototype, behaviour, length, name, prefix,
		unsafe { nil }, true, true)
}

// A translated NativeFunction subclass supplies its call and construct bodies.
// The callee owns frame allocation, as on the existing native call path.
pub fn NativeFunction.create_constructor(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, construct_behaviour NativeConstructPointer, length f64, name FunctionName) &NativeFunction {
	assert construct_behaviour != unsafe { nil }
	return create_native_function(mut vm, realm, prototype, behaviour, length, name, none,
		construct_behaviour, false, true)
}

// NativeFunction(name, prototype) used by builtin subclasses retains the initial
// name but installs no public properties. Subclass initialize() and Intrinsics
// initialize_constructor() determine their observable insertion order.
pub fn NativeFunction.create_constructor_record(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, construct_behaviour NativeConstructPointer, name FunctionName) &NativeFunction {
	assert construct_behaviour != unsafe { nil }
	return create_native_function(mut vm, realm, prototype, behaviour, 0, name, none,
		construct_behaviour, false, false)
}

fn create_native_function(mut vm VM, realm &Realm, prototype ?&Object, behaviour NativeFunctionPointer, length f64, name FunctionName, prefix ?string, construct_behaviour NativeConstructPointer, raw bool, initialize_metadata bool) &NativeFunction {
	assert behaviour != unsafe { nil }
	mut object := Object.create(realm, prototype)
	object.class_name = 'Function'
	object.native_callable = true
	text := make_function_name(name, prefix)
	if initialize_metadata {
		object.set_function_length(length)
		object.set_function_name_text(mut vm, text)
	} else {
		object.native_initial_name = text
	}
	function := &NativeFunction{
		object:             object
		realm_:             realm
		name:               text
		behaviour: if raw { unsafe { nil } } else { behaviour }
		raw_function_index: if raw { vm.register_native_function(behaviour, .raw_native_function) } else { none }
		construct_behaviour: construct_behaviour
	}
	object.callable = FunctionObject(function)
	if construct_behaviour != unsafe { nil } { object.constructor = ConstructorFunction(function) }
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
	return function.construct_behaviour != unsafe { nil }
}

pub fn (mut function NativeFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	return function.call_in_frame(mut vm, this_value, arguments, unsafe { nil })
}

// Internal callers may discard the result of a branded builtin. Keep its
// original function identity, realm, native frame and error/stack checks.
fn (mut function NativeFunction) call_in_frame(mut vm VM, this_value Value, arguments []Value, internal_behaviour NativeFunctionPointer) !Value {
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	defer { stack.deallocate(mark) }
	function.push_call_frame(mut vm, mut stack, this_value, arguments)!
	defer { vm.pop_current_context() }
	behaviour := if internal_behaviour != unsafe { nil } { internal_behaviour } else if index := function.raw_function_index {
		vm.native_function(index, .raw_native_function)
	} else {
		function.behaviour
	}
	$if test {
		if builtin_profile_enabled { return invoke_profiled_builtin(&function, mut vm, behaviour) }
	}
	return behaviour(mut vm)
}

fn (mut function NativeFunction) push_call_frame(mut vm VM, mut stack InterpreterStack, this_value Value, arguments []Value) ! {
	caller := vm.current_context()
	mut callee := stack.allocate_reusable(0, []Value{}, u32(arguments.len)) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	callee.copy_call_arguments(arguments)
	callee.passed_argument_count = u32(arguments.len)
	callee.function = FunctionObject(&function)
	callee.realm = function.realm_
	callee.this_value = this_value
	callee.call_environment = caller.call_environment
	callee.lexical_environment = caller.lexical_environment
	callee.variable_environment = caller.variable_environment
	callee.private_environment = caller.private_environment
	vm.push_execution_context_checked(mut callee)!
}

// 7.3.14 Call, AbstractOperations.cpp. Only callable objects have [[Call]].
pub fn call(mut vm VM, function Value, this_value Value, arguments []Value) !Value {
	if !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	mut callable := function.as_function()
	return callable.internal_call(mut vm, this_value, arguments)
}
