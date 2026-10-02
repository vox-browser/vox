module libjs

fn test_string_exotic_properties_preserve_individual_utf16_units_and_fixed_length() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	prototype.define_direct_property(PropertyName.from_number(0), Value.from_i32(99), 7)
	prototype.define_direct_property(PropertyName.from_number(8), Value.from_i32(42), 7)
	units := [u16(`A`), 0xd83d, 0xde00, 0, 0xd800]
	value := vm.create_string(Utf16String.from_slice(units))
	text := StringObject.create(vm.realm(), value, prototype)
	mut object := text.object
	assert voidptr(text.value) == voidptr(value)
	assert voidptr(object.prototype?) == voidptr(prototype)
	assert object.class_name == 'StringObject'
	assert Value.from_object(object).str() == '[object StringObject]'
	assert object.properties.len == 1
	length := object.internal_get_own_property(PropertyName.from_str('length'))?
	assert length.value?.number == 5
	assert !length.writable? && !length.enumerable? && !length.configurable?
	for index, unit in units {
		key := PropertyName.from_number(u32(index))
		descriptor := object.internal_get_own_property(key)?
		assert descriptor.value?.as_string().utf16.data == [unit]
		assert !descriptor.writable? && descriptor.enumerable? && !descriptor.configurable?
		assert object.get(mut vm, key)!.as_string().utf16.data == [unit]
		assert object.has_own_property(key) && object.has_property(key)
		assert !object.internal_delete(key)
		assert !object.internal_set(mut vm, key, Value.from_i32(17), Value.from_object(object))!
	}
	for name in ['-0', '01', '1.0', '-1', '5', '4294967295', 'NaN', 'Infinity'] {
		assert !object.has_own_property(PropertyName.from_str(name))
	}
	assert object.get(mut vm, PropertyName.from_number(8))!.number == 42
	assert object.properties.len == 1
	// Upstream diagnostics use ordinary storage, bypassing virtual characters.
	assert object.get_without_side_effects(PropertyName.from_number(0)).number == 99
}

fn test_string_virtual_descriptor_compatibility_does_not_materialize_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	text := StringObject.create(vm.realm(), vm.create_string_from_str('x'), prototype)
	mut object := text.object
	key := PropertyName.from_number(0)
	same := Value.from_string(&PrimitiveString{ utf16: utf16_string('x') })
	for descriptor in [PropertyDescriptor{}, PropertyDescriptor{ value: same },
		PropertyDescriptor{ writable: false, enumerable: true, configurable: false }] {
		assert object.internal_define_own_property(mut vm, key, descriptor)!
	}
	for descriptor in [PropertyDescriptor{ value: Value.from_i32(120) },
		PropertyDescriptor{ writable: true }, PropertyDescriptor{ enumerable: false },
		PropertyDescriptor{ configurable: true }, PropertyDescriptor{ getter: js_undefined() }] {
		assert !object.internal_define_own_property(mut vm, key, descriptor)!
	}
	assert !object.create_data_property(mut vm, key, same)!
	assert object.internal_prevent_extensions()
	assert object.internal_define_own_property(mut vm, key, PropertyDescriptor{ value: same })!
	assert !object.create_data_property(mut vm, PropertyName.from_number(1), same)!
	assert object.properties.len == 1
	assert object.set_integrity_level(mut vm, .frozen)!
	assert object.test_integrity_level(.sealed) && object.test_integrity_level(.frozen)
	assert !object.internal_delete(PropertyName.from_str('length'))
	assert object.internal_delete(PropertyName.from_number(1))
}

fn test_string_own_keys_merge_virtual_indices_with_ordinary_creation_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	text := StringObject.create(vm.realm(), vm.create_string_from_str('ab'), prototype)
	mut object := text.object
	first_symbol := Symbol.create(utf16_string('first'), .unique)
	private_symbol := Symbol.create(utf16_string('hidden'), .private)
	for key in [PropertyName.from_str('later'), PropertyName.from_number(9),
		PropertyName.from_symbol(first_symbol), PropertyName.from_str('01'),
		PropertyName.from_number(2), PropertyName.from_symbol(private_symbol),
		PropertyName.from_str('4294967295')] {
		assert object.create_data_property(mut vm, key, js_null())!
	}
	assert object.own_property_keys().map(it.str()) == ['0', '1', '2', '9', 'length',
		'later', '01', '4294967295', 'Symbol(first)']
	assert object.internal_delete(PropertyName.from_str('later'))
	assert object.create_data_property(mut vm, PropertyName.from_str('later'), js_null())!
	assert object.own_property_keys().map(it.str()) == ['0', '1', '2', '9', 'length',
		'01', '4294967295', 'later', 'Symbol(first)']
	// Ordinary storage is checked first by GetOwnProperty, as in upstream.
	object.define_direct_property(PropertyName.from_number(0), Value.from_i32(42), 7)
	assert object.internal_get_own_property(PropertyName.from_number(0))?.value?.number == 42
	assert object.own_property_keys().filter(it.equals(PropertyName.from_number(0))).len == 1
	assert !object.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{
		value: Value.from_i32(42)
	})!
	assert object.internal_delete(PropertyName.from_number(0))
	assert object.get(mut vm, PropertyName.from_number(0))!.as_string().str() == 'a'
	empty := StringObject.create(vm.realm(), vm.empty_string(), prototype)
	assert empty.object.own_property_keys().map(it.str()) == ['length']
	assert !empty.object.has_own_property(PropertyName.from_number(0))
}

fn test_string_exotics_supply_array_like_arguments_without_a_string_prototype() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	text := StringObject.create(vm.realm(), vm.create_string_from_str('ok'), prototype)
	values := create_list_from_array_like(mut vm, Value.from_object(text.object), unsafe { nil })!
	assert values.len == 2
	assert values[0].as_string().str() == 'o' && values[1].as_string().str() == 'k'
}
