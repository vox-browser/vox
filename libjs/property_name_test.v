module libjs

fn test_property_names_canonicalize_only_valid_array_indices() {
	for text, index in {
		'0':          u32(0)
		'3':          u32(3)
		'4294967294': u32(4294967294)
	} {
		key := PropertyName.from_str(text)
		assert key.is_number()
		assert key.equals(PropertyName.from_number(index))
		assert key.str() == text
	}
	for text in ['', '00', '03', '-0', '-1', '+1', '1.0', '1e0', '1 ', ' 1', '4294967295',
		'4294967296', '184467440737095516160', '٣'] {
		assert PropertyName.from_str(text).is_string(), text
	}
	assert PropertyName.from_number(0xffffffff).equals(PropertyName.from_str('4294967295'))
	assert PropertyName.from_utf16(Utf16String{ data: [u16(0xd800)] }).is_string()
}

fn test_numeric_and_string_property_names_share_one_live_property() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	assert object.create_data_property(mut vm, PropertyName.from_number(3), Value.from_i32(41)) or {
		panic(err)
	}
	assert object.get(mut vm, PropertyName.from_str('3'))!.number == 41
	object.set(mut vm, PropertyName.from_str('3'), Value.from_i32(42), .yes)!
	assert object.get(mut vm, PropertyName.from_number(3))!.number == 42
	assert object.own_property_keys().len == 1
	assert object.internal_delete(PropertyName.from_str('3'))
	assert !object.has_own_property(PropertyName.from_number(3))
	assert Value.from_f64(-0.0).to_property_key(mut vm)!.equals(PropertyName.from_number(0))
}

fn test_ordinary_own_property_keys_sort_indices_and_preserve_string_symbol_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	first_symbol := Symbol.create(utf16_string('first'), .unique)
	second_symbol := Symbol.create(utf16_string('second'), .unique)
	for key in [PropertyName.from_str('b'), PropertyName.from_symbol(first_symbol),
		PropertyName.from_str('10'), PropertyName.from_str('a'),
		PropertyName.from_number(2), PropertyName.from_symbol(second_symbol),
		PropertyName.from_str('01'), PropertyName.from_number(0xffffffff)] {
		assert object.create_data_property(mut vm, key, js_undefined()) or { panic(err) }
	}
	assert object.own_property_keys().map(it.str()) == ['2', '10', 'b', 'a', '01', '4294967295',
		'Symbol(first)', 'Symbol(second)']
	assert object.internal_delete(PropertyName.from_str('b'))
	assert object.create_data_property(mut vm, PropertyName.from_str('b'), js_undefined()) or {
		panic(err)
	}
	assert object.own_property_keys().map(it.str()) == ['2', '10', 'a', '01', '4294967295', 'b',
		'Symbol(first)', 'Symbol(second)']
	assert object.create_data_property(mut vm, PropertyName.from_symbol(Symbol.create_private()),
		js_undefined()) or { panic(err) }
	assert object.own_property_keys().len == 8
}

fn test_environment_reference_names_remain_strings_when_they_resemble_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut environment := DeclarativeEnvironment.create(none)
	name := utf16_string('42')
	environment.create_mutable_binding(mut vm, name, false)!
	environment.initialize_binding(mut vm, name, Value.from_i32(42), .normal)!
	reference := Reference.for_environment(Environment(environment), name, false, none)
	assert reference.name.is_string()
	assert reference.get_value(mut vm)!.number == 42
	reference.put_value(mut vm, Value.from_i32(43))!
	assert reference.get_value(mut vm)!.number == 43
}
