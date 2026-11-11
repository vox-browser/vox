module libjs

import math

// Runtime/FunctionPrototype.{h,cpp}. Creation receives %Object.prototype%
// explicitly; constructor linkage belongs to Intrinsics initialization.
@[heap]
pub struct FunctionPrototype {
pub:
	object &Object
}

pub fn FunctionPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &FunctionPrototype {
	mut object := Object.create(realm, object_prototype)
	object.class_name = 'Function'
	prototype := &FunctionPrototype{
		object: object
	}
	object.callable = FunctionObject(prototype)
	for name, behaviour in {
		'apply':    NativeFunctionPointer(function_prototype_apply)
		'bind':     NativeFunctionPointer(function_prototype_bind)
		'call':     NativeFunctionPointer(function_prototype_call)
		'toString': NativeFunctionPointer(function_prototype_to_string)
	} {
		length := match name {
			'apply' { 2.0 }
			'toString' { 0.0 }
			else { 1.0 }
		}

		function := NativeFunction.create_raw(mut vm, realm, object, behaviour, length,
			PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	key := PropertyName.from_symbol(vm.well_known_symbol_has_instance())
	has_instance := NativeFunction.create_raw(mut vm, realm, object,
		function_prototype_has_instance, 1, key, none)
	object.define_direct_property(key, Value.from_object(has_instance.object), 0)
	object.set_function_length(0)
	object.set_function_name(mut vm, PropertyName.from_str(''), none)
	return prototype
}

pub fn (prototype &FunctionPrototype) realm() ?&Realm {
	return none
}

pub fn (prototype &FunctionPrototype) name_for_call_stack() Utf16String {
	return utf16_string('(Function.prototype)')
}

pub fn (mut prototype FunctionPrototype) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	// Upstream call_impl reserves a callee frame, but this object's [[Call]]
	// returns undefined without installing a new running execution context.
	if vm.did_reach_stack_space_limit() {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	stack.allocate(0, []Value{}, u32(arguments.len)) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	return js_undefined()
}

fn function_prototype_apply(mut vm VM) !Value {
	function := vm.this_value()
	if !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	this_argument := vm.argument(0)
	argument_array := vm.argument(1)
	if argument_array.is_nullish() { return call(mut vm, function, this_argument, []Value{}) }
	call_arguments := create_argument_list_from_array_like(mut vm, argument_array)!
	return call(mut vm, function, this_argument, call_arguments)
}

fn function_prototype_call(mut vm VM) !Value {
	function := vm.this_value()
	if !function.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, function.str())
	}
	this_argument := vm.argument(0)
	mut call_arguments := []Value{}
	for index in 1 .. int(vm.argument_count()) {
		call_arguments << vm.argument(u32(index))
	}
	return call(mut vm, function, this_argument, call_arguments)
}

fn function_prototype_bind(mut vm VM) !Value {
	target := vm.this_value()
	if !target.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, target.str())
	}
	mut call_arguments := []Value{}
	for index in 1 .. int(vm.argument_count()) {
		call_arguments << vm.argument(u32(index))
	}
	function := BoundFunction.create(vm.realm(), target.as_object(), vm.argument(0), call_arguments)
	mut object := function.object
	mut length := 0.0
	if target.as_object().has_own_property(PropertyName.from_str('length')) {
		target_length := target.as_object().get(mut vm, PropertyName.from_str('length'))!
		if target_length.is_number() {
			if math.is_inf(target_length.number, 1) {
				length = target_length.number
			} else if !math.is_inf(target_length.number, -1) {
				length = math.max(target_length.to_integer_or_infinity(mut vm)! - call_arguments.len, 0)
			}
		}
	}
	object.set_function_length(length)
	target_name := target.as_object().get(mut vm, PropertyName.from_str('name'))!
	name := if target_name.is_string() { target_name.as_string().utf16 } else { Utf16String.new() }
	object.set_function_name(mut vm, PropertyName.from_utf16(name), 'bound')
	return Value.from_object(object)
}

fn function_prototype_to_string(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_function() {
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Function')
	}
	object := value.as_object()
	if source := object.function_source_text {
		return Value.from_string(vm.create_string(source))
	}
	if object.native_callable {
		name := object.native_initial_name or { value.as_function().name_for_call_stack() }
		return Value.from_string(vm.create_string(utf16_concat([
			utf16_string('function '),
			name,
			utf16_string('() { [native code] }'),
		])))
	}
	return Value.from_string(vm.create_string_from_str('function () { [native code] }'))
}

fn function_prototype_has_instance(mut vm VM) !Value {
	return ordinary_has_instance(mut vm, vm.argument(0), vm.this_value())
}
