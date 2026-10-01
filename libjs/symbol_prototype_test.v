module libjs

fn symbol_test_invoke(mut vm VM, prototype &Object, key PropertyName, receiver Value, arguments []Value) !Value {
	method := prototype.get(mut vm, key)!
	return call(mut vm, method, receiver, arguments)
}

fn test_symbol_prototype_has_no_symbol_data_and_defines_methods_getter_and_symbol_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	prototype := SymbolPrototype.create(mut vm, realm, parent).object
	assert prototype.internal_get_prototype_of()? == parent
	assert prototype.symbol_object == none
	assert prototype.own_property_keys().map(it.str()) == ['toString', 'valueOf', 'description',
		'Symbol(Symbol.toPrimitive)', 'Symbol(Symbol.toStringTag)']
	for name in ['toString', 'valueOf'] {
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		function := descriptor.value?.as_object()
		assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert function.get(mut vm, PropertyName.from_str('length'))!.number == 0
		assert function.internal_get_prototype_of()? == realm.function_prototype_record()
	}
	description := prototype.internal_get_own_property(PropertyName.from_str('description'))?
	assert description.is_accessor_descriptor() && description.setter?.is_undefined()
	assert description.configurable? && !description.enumerable?
	getter := description.getter?.as_object()
	assert getter.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'get description'
	assert getter.get(mut vm, PropertyName.from_str('length'))!.number == 0
	primitive := prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()))?
	assert !primitive.writable? && primitive.configurable? && !primitive.enumerable?
	function := primitive.value?.as_object()
	assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == '[Symbol.toPrimitive]'
	assert function.get(mut vm, PropertyName.from_str('length'))!.number == 1
	tag := prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.value?.as_string().str() == 'Symbol'
	assert !tag.writable? && !tag.enumerable? && tag.configurable?
}

fn test_symbol_methods_preserve_identity_and_description_utf16_including_absent_empty_and_surrogates() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.symbol_prototype_record()
	for description in [?Utf16String(none), ?Utf16String(Utf16String.new()), ?Utf16String(utf16_string('key')),
		?Utf16String(Utf16String.from_slice([u16(0xd800), 0, 0xdc00]))] {
		symbol := Symbol.create(description, .unique)
		wrapper := SymbolObject.create(realm, symbol)
		assert wrapper.object.symbol_object? == wrapper
		assert wrapper.object.internal_get_prototype_of()? == prototype
		assert wrapper.object.own_property_keys().len == 0
		for receiver in [Value.from_symbol(symbol), Value.from_object(wrapper.object)] {
			value := symbol_test_invoke(mut vm, prototype, PropertyName.from_str('valueOf'), receiver, []Value{})!
			assert value.as_symbol() == symbol
			text := symbol_test_invoke(mut vm, prototype, PropertyName.from_str('toString'), receiver, []Value{})!
			assert text.as_string().utf16 == symbol.descriptive_string()
			value_of_description := prototype.internal_get(mut vm, PropertyName.from_str('description'), receiver)!
			if expected := description { assert value_of_description.as_string().utf16 == expected }
			else { assert value_of_description.is_undefined() }
		}
		assert Value.from_object(wrapper.object).to_property_key(mut vm)!.as_symbol() == symbol
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_symbol_to_primitive_ignores_hint_and_boxed_conversion_preserves_the_primitive() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	symbol := Symbol.create(utf16_string('key'), .unique)
	wrapper := Value.from_object(SymbolObject.create(realm, symbol).object)
	mut hint := Object.create(realm, none)
	coercion := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		assert false, 'the hint must be ignored'
		return js_undefined()
	}, 0, PropertyName.from_str('coerce'), none)
	hint.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	for value in [js_undefined(), js_null(), Value.from_i32(42), Value.from_object(hint)] {
		assert symbol_test_invoke(mut vm, realm.symbol_prototype_record(),
			PropertyName.from_symbol(vm.well_known_symbol_to_primitive()), wrapper, [value])!.as_symbol() == symbol
	}
	for preferred in [PreferredType.default_, .number, .string] {
		assert wrapper.to_primitive_with_hint(mut vm, preferred)!.as_symbol() == symbol
	}
	if _ := wrapper.to_number(mut vm) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .type_error }
}

fn test_symbol_methods_and_description_reject_unbranded_receivers_without_coercion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.symbol_prototype_record()
	mut fake := Object.create(realm, prototype)
	fake.class_name = 'Symbol'
	coercion := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 1, PropertyName.from_str('coerce'), none)
	fake.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	for receiver in [js_undefined(), js_null(), Value.from_i32(42), Value.from_bool(true),
		Value.from_object(prototype), Value.from_object(fake), Value.from_object(BooleanObject.create(realm, true).object)] {
		for key in [PropertyName.from_str('toString'), PropertyName.from_str('valueOf'),
			PropertyName.from_symbol(vm.well_known_symbol_to_primitive())] {
			if _ := symbol_test_invoke(mut vm, prototype, key, receiver, []Value{}) { assert false }
			else { assert thrown_value(err).as_object().error_kind()? == .type_error }
		}
		if _ := prototype.internal_get(mut vm, PropertyName.from_str('description'), receiver) { assert false }
		else { assert thrown_value(err).as_object().error_kind()? == .type_error }
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
