module libjs

fn test_ordinary_objects_define_get_set_and_delete_data_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut prototype := Object.create(realm, none)
	mut object := Object.create(realm, prototype)
	key := PropertyName.from_str('answer')
	assert object.create_data_property(key, Value.from_i32(42))
	assert object.has_own_property(key)
	assert object.get(key).as_i32() == 42
	inherited := PropertyName.from_str('inherited')
	assert prototype.create_data_property(inherited, Value.from_bool(true))
	assert object.has_property(inherited)
	assert !object.has_own_property(inherited)
	assert object.get(inherited).as_bool()
	assert object.get(PropertyName.from_str('missing')).is_undefined()
	// Set walks the prototype chain and creates an own property on the receiver.
	object.set(mut vm, inherited, Value.from_i32(7), .yes)!
	assert object.has_own_property(inherited)
	assert prototype.get(inherited).as_bool()
	assert object.internal_delete(inherited)
	assert !object.has_own_property(inherited)
	assert object.own_property_keys().len == 1
	descriptor := object.internal_get_own_property(key)?
	assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	assert descriptor.is_data_descriptor()
	assert descriptor.value?.as_i32() == 42
}

fn test_non_writable_and_non_configurable_properties_reject_changes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut object := Object.create(realm, none)
	key := PropertyName.from_str('frozen')
	object.define_direct_property(key, Value.from_i32(1), 0)
	assert !object.internal_set(key, Value.from_i32(2), Value.from_object(object))
	object.set(mut vm, key, Value.from_i32(2), .no)!
	assert object.get(key).as_i32() == 1
	object.set(mut vm, key, Value.from_i32(2), .yes) or {
		error_object := thrown_value(err).as_object()
		assert error_object.error_kind()? == .type_error
		assert error_object.error_message()? == ErrorType.object_set_returned_false.message()
	}
	assert !object.internal_delete(key)
	object.delete_property_or_throw(mut vm, key) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	// Redefining with the same value is allowed; changing it is not.
	assert object.internal_define_own_property(key, PropertyDescriptor{ value: Value.from_i32(1) })
	assert !object.internal_define_own_property(key, PropertyDescriptor{ value: Value.from_i32(3) })
	assert !object.internal_define_own_property(key, PropertyDescriptor{ configurable: true })
	assert !object.internal_define_own_property(key, PropertyDescriptor{ enumerable: true })
	object.extensible = false
	assert !object.create_data_property(PropertyName.from_str('later'), js_undefined())
	object.create_data_property_or_throw(mut vm, PropertyName.from_str('later'), js_undefined()) or {
		assert thrown_value(err).as_object().error_message()? == ErrorType.object_define_own_property_returned_false.message()
	}
	object.define_property_or_throw(mut vm, PropertyName.from_str('later'), PropertyDescriptor{}) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_property_names_compare_by_kind_string_symbol_and_index() {
	symbol := Symbol.create(utf16_string('tag'), .unique)
	other_symbol := Symbol.create(utf16_string('tag'), .unique)
	assert PropertyName.from_str('a').equals(PropertyName.from_utf16(utf16_string('a')))
	assert !PropertyName.from_str('a').equals(PropertyName.from_str('b'))
	assert PropertyName.from_symbol(symbol).equals(PropertyName.from_symbol(symbol))
	assert !PropertyName.from_symbol(symbol).equals(PropertyName.from_symbol(other_symbol))
	assert !PropertyName.from_symbol(symbol).equals(PropertyName.from_str('tag'))
	assert PropertyName.from_number(3).equals(PropertyName.from_number(3))
	assert PropertyName.from_number(3).str() == '3'
	assert PropertyName.from_symbol(symbol).str() == 'Symbol(tag)'
	assert PropertyName.from_symbol(symbol).is_symbol()
	assert PropertyName.from_str('x').is_string()
	assert PropertyName.from_number(1).is_number()
	mut vm := VM.create()
	realm := Realm.create()
	mut object := Object.create(realm, none)
	assert object.create_data_property(PropertyName.from_symbol(symbol), Value.from_i32(1))
	assert object.get(PropertyName.from_symbol(symbol)).as_i32() == 1
	assert object.get(PropertyName.from_symbol(other_symbol)).is_undefined()
	assert vm.cached_strings.number.str() == 'number'
}

fn test_frozen_string_properties_compare_utf16_values_instead_of_cells() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	key := PropertyName.from_str('fixed')
	one := Value.from_string(&PrimitiveString{ utf16: utf16_string('unchanged') })
	two := Value.from_string(&PrimitiveString{ utf16: utf16_string('unchanged') })
	object.define_direct_property(key, one, 0)
	assert object.internal_define_own_property(key, PropertyDescriptor{ value: two })
	assert !object.internal_define_own_property(key, PropertyDescriptor{
		value: Value.from_string(vm.create_string_from_str('changed'))
	})
}
