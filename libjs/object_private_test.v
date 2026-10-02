module libjs

fn private_test_name(id u64, description string) PrivateName {
	return PrivateName{ unique_id: id, description: utf16_string(description) }
}

fn test_private_fields_use_name_identity_and_ignore_ordinary_properties_and_extensibility() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	name := private_test_name(1, '#value')
	other := private_test_name(2, '#value')
	object.create_data_property(mut vm, PropertyName.from_str('#value'), Value.from_i32(99))!
	assert object.internal_prevent_extensions()
	object.private_field_add(mut vm, name, Value.from_i32(17))!
	object.private_field_add(mut vm, other, js_undefined())!
	assert object.private_get(mut vm, name)!.number == 17
	assert object.private_get(mut vm, other)!.is_undefined()
	object.private_set(mut vm, name, Value.from_i32(42))!
	assert object.private_get(mut vm, name)!.number == 42
	assert object.get(mut vm, PropertyName.from_str('#value'))!.number == 99
	assert object.own_property_keys().len == 1
	if _ := object.private_field_add(mut vm, name, Value.from_i32(0)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
		assert thrown_value(err).as_object().error_message()?.str() == "Private field '#value' has already been declared"
	}
	child := Object.create(vm.realm(), object)
	assert child.private_element_find(name) == none
	if _ := child.private_get(mut vm, name) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "Private field '#value' does not exist on object"
	}
	if _ := object.private_set(mut vm, private_test_name(3, '#missing'), js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_private_methods_are_readable_but_cannot_be_replaced() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	name := private_test_name(1, '#method')
	method := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return vm.this_value()
	}, 0, name, none)
	object.private_method_or_accessor_add(mut vm, PrivateElement{
		key:   name
		kind:  .method
		value: Value.from_object(method.object)
	})!
	assert object.private_get(mut vm, name)! == Value.from_object(method.object)
	if _ := object.private_set(mut vm, name, js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "Cannot set private method '#method'"
	}
	if _ := object.private_field_add(mut vm, name, js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

@[heap]
struct PrivateAccessorTrace {
mut:
	receivers []Value
	values    []Value
}

fn test_private_accessors_keep_receiver_arguments_missing_handlers_and_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	mut trace := &PrivateAccessorTrace{}
	name := private_test_name(1, '#accessor')
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut trace] (mut vm VM) !Value {
		trace.receivers << vm.this_value()
		return Value.from_i32(42)
	}, 0, name, 'get')
	setter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut trace] (mut vm VM) !Value {
		trace.receivers << vm.this_value()
		trace.values << vm.argument(0)
		return js_undefined()
	}, 1, name, 'set')
	object.private_method_or_accessor_add(mut vm, PrivateElement{
		key:   name
		kind:  .accessor
		value: Value.from_accessor(Accessor.create(getter.object, setter.object, none))
	})!
	assert object.private_get(mut vm, name)!.number == 42
	object.private_set(mut vm, name, Value.from_i32(17))!
	assert trace.receivers == [Value.from_object(object), Value.from_object(object)]
	assert trace.values == [Value.from_i32(17)]
	missing := private_test_name(2, '#missing')
	object.private_method_or_accessor_add(mut vm, PrivateElement{
		key:   missing
		kind:  .accessor
		value: Value.from_accessor(Accessor.create(none, none, none))
	})!
	if _ := object.private_get(mut vm, missing) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "Cannot get private field '#missing' as accessor without getter"
	}
	if _ := object.private_set(mut vm, missing, js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "Cannot set private field '#missing' as accessor without setter"
	}
	abrupt_name := private_test_name(3, '#abrupt')
	abrupt := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(123))
	}, 0, abrupt_name, none)
	object.private_method_or_accessor_add(mut vm, PrivateElement{
		key:   abrupt_name
		kind:  .accessor
		value: Value.from_accessor(Accessor.create(abrupt.object, abrupt.object, none))
	})!
	if _ := object.private_get(mut vm, abrupt_name) {
		assert false
	} else {
		assert thrown_value(err).number == 123
	}
	if _ := object.private_set(mut vm, abrupt_name, js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).number == 123
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_private_element_host_hook_precedes_duplicate_check_and_rejections_do_not_append() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	name := private_test_name(1, '#field')
	object.private_field_add(mut vm, name, Value.from_i32(42))!
	vm.host_ensure_can_add_private_element = fn (mut object Object) ! {
		return throw_completion(Value.from_i32(17))
	}
	if _ := object.private_field_add(mut vm, name, js_undefined()) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	if _ := object.private_method_or_accessor_add(mut vm, PrivateElement{
		key:   private_test_name(2, '#method')
		kind:  .method
		value: js_undefined()
	}) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert object.private_elements.len == 1
	assert object.private_get(mut vm, name)!.number == 42
}

fn test_private_references_resolve_nearest_environment_and_dispatch_private_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut outer := PrivateEnvironment.create(mut vm, none)
	outer.add_private_name(utf16_string('#value'))
	mut inner := PrivateEnvironment.create(mut vm, outer)
	inner.add_private_name(utf16_string('#value'))
	mut context := vm.running_execution_context()
	context.private_environment = inner
	mut object := Object.create(vm.realm(), none)
	outer_name := outer.resolve_private_identifier(utf16_string('#value'))
	inner_name := inner.resolve_private_identifier(utf16_string('#value'))
	assert outer_name != inner_name
	object.private_field_add(mut vm, outer_name, Value.from_i32(17))!
	object.private_field_add(mut vm, inner_name, Value.from_i32(42))!
	reference := make_private_reference(vm, Value.from_object(object), utf16_string('#value'))
	assert reference.is_private_reference() && reference.is_property_reference() && reference.is_strict()
	assert !reference.is_super_reference()
	assert reference.get_this_value() == Value.from_object(object)
	assert reference.get_value(mut vm)!.number == 42
	reference.put_value(mut vm, Value.from_i32(99))!
	assert object.private_get(mut vm, inner_name)!.number == 99
	assert object.private_get(mut vm, outer_name)!.number == 17
	assert object.own_property_keys().len == 0
}
