// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/{ErrorConstructor,ErrorPrototype,Error}.cpp and Intrinsics.cpp.
// AggregateError (which consumes an iterable) is a separate intrinsic slice.
fn initialize_error_intrinsics(mut vm VM, mut realm Realm) {
	for kind in [ErrorKind.error, .eval_error, .internal_error, .range_error, .reference_error,
		.syntax_error, .type_error, .uri_error] {
		parent := if kind == .error {
			realm.object_prototype_record()
		} else {
			realm.error_prototypes[.error] or { panic('Missing Error prototype') }
		}
		mut prototype := Object.create(&realm, parent)
		prototype.define_direct_property(PropertyName.from_str('name'), Value.from_string(vm.create_string_from_str(kind.name())), attribute_writable | attribute_configurable)
		prototype.define_direct_property(PropertyName.from_str('message'), Value.from_string(vm.empty_string()), attribute_writable | attribute_configurable)
		if kind == .error {
			install_intrinsic_method(mut vm, &realm, mut prototype, 'toString', 0, error_prototype_to_string)
			prototype.define_native_accessor(mut vm, &realm, PropertyName.from_str('stack'), error_prototype_stack_getter, error_prototype_stack_setter, attribute_writable | attribute_configurable, realm.function_prototype)
		}
		realm.error_prototypes[kind] = prototype
		function_parent := if kind == .error {
			realm.function_prototype_record()
		} else {
			realm.error_constructors[.error] or { panic('Missing Error constructor') }
		}
		function := NativeFunction.create_constructor_record(mut vm, &realm, function_parent,
			fn [kind] (mut vm VM) !Value {
				return error_constructor_call(mut vm, kind)
			}, fn [kind] (mut vm VM, target &Object) !&Object {
				return error_constructor_construct(mut vm, target, kind)
			}, PropertyName.from_str(kind.name()))
		mut constructor := function.object
		constructor.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), 0)
		constructor.set_function_length(1)
		constructor.set_function_name(mut vm, PropertyName.from_str(kind.name()), none)
		if kind == .error {
			install_intrinsic_method(mut vm, &realm, mut constructor, 'isError', 1, fn (mut vm VM) !Value {
				value := vm.argument(0)
				return Value.from_bool(value.is_object() && value.as_object().error_data != none)
			})
		}
		prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(constructor), attribute_writable | attribute_configurable)
		realm.error_constructors[kind] = constructor
	}
}

fn error_constructor_call(mut vm VM, kind ErrorKind) !Value {
	active := vm.active_function_object() or { panic('Missing active error constructor') }
	if active is NativeFunction {
		return Value.from_object(error_constructor_construct(mut vm, active.object, kind)!)
	}
	return error('Error constructor is not a native function')
}

fn error_constructor_construct(mut vm VM, target &Object, kind ErrorKind) !&Object {
	prototype := get_prototype_from_constructor(mut vm, target, fn [kind] (realm &Realm) &Object {
		return realm.error_prototypes[kind] or { panic('Missing native error prototype') }
	})!
	mut object := Object.create(vm.realm(), prototype)
	object.class_name = kind.name()
	object.error_data = &ErrorData{ kind: kind, realm: vm.realm(), traceback: populate_stack(vm) }
	message := vm.argument(0)
	if !message.is_undefined() {
		object.set_error_message(mut vm, message.to_primitive_string(mut vm)!.utf16)
	}
	options := vm.argument(1)
	key := PropertyName.from_str('cause')
	if options.is_object() && options.as_object().has_property(key) {
		cause := options.as_object().get(mut vm, key)!
		object.define_direct_property(key, cause, attribute_writable | attribute_configurable)
	}
	return object
}

fn error_prototype_to_string(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	name_value := object.get(mut vm, PropertyName.from_str('name'))!
	name := if name_value.is_undefined() {
		utf16_string('Error')
	} else {
		name_value.to_primitive_string(mut vm)!.utf16
	}
	message_value := object.get(mut vm, PropertyName.from_str('message'))!
	message := if message_value.is_undefined() {
		Utf16String.new()
	} else {
		message_value.to_primitive_string(mut vm)!.utf16
	}
	result := if name.is_empty() {
		message
	} else if message.is_empty() {
		name
	} else {
		utf16_concat([name, utf16_string(': '), message])
	}
	return Value.from_string(vm.create_string(result))
}

fn error_prototype_stack_getter(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	mut data := object.error_data or { return js_undefined() }
	if cached := data.cached_string { return Value.from_string(cached) }
	name_value := object.get(mut vm, PropertyName.from_str('name'))!
	name := if name_value.is_undefined() {
		utf16_string('Error')
	} else {
		name_value.to_primitive_string(mut vm)!.utf16
	}
	message_value := object.get(mut vm, PropertyName.from_str('message'))!
	message := if message_value.is_undefined() {
		Utf16String.new()
	} else {
		message_value.to_primitive_string(mut vm)!.utf16
	}
	header := if message.is_empty() {
		name
	} else {
		utf16_concat([name, utf16_string(': '), message])
	}
	result := vm.create_string(utf16_concat([header, utf16_string('\n' + data.stack_string(false))]))
	data.cached_string = result
	return Value.from_string(result)
}

fn error_prototype_stack_setter(mut vm VM) !Value {
	value := vm.this_value()
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	if vm.argument_count() == 0 {
		return vm.throw_error_type(.type_error, .bad_arg_count_one, 'set stack')
	}
	mut object := value.as_object()
	return Value.from_bool(object.create_data_property_or_throw(mut vm, PropertyName.from_str('stack'), vm.argument(0))!)
}
