module libjs

fn indexed_storage_fixture() (&VM, &Object) {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	assert object.enable_indexed_properties()
	return vm, object
}

fn test_indexed_ordinary_storage_observes_add_delete_reinsert_and_value_changes() {
	mut vm, mut object := indexed_storage_fixture()
	key := PropertyName.from_str('answer')
	assert object.get(mut vm, key)!.is_undefined()
	object.define_direct_property(key, Value.from_i32(42), 7)
	assert object.get(mut vm, key)!.number == 42
	for index in 0 .. 100 {
		other := PropertyName.from_str('field${index}')
		object.define_direct_property(other, Value.from_i32(i32(index)), 7)
		assert object.get(mut vm, key)!.number == 42
		assert object.internal_delete(other)
	}
	object.define_direct_property(key, Value.from_i32(43), 7)
	assert object.get(mut vm, key)!.number == 43
	assert object.internal_delete(key)
	assert object.get(mut vm, key)!.is_undefined()
	object.define_direct_property(key, Value.from_i32(44), 0)
	assert object.get(mut vm, key)!.number == 44
	assert !object.internal_delete(key)
}

fn test_indexed_storage_keeps_key_identity_and_recovers_from_whole_vector_replacement() {
	mut vm, mut object := indexed_storage_fixture()
	first := Symbol.create(utf16_string('x'), .unique)
	second := Symbol.create(utf16_string('x'), .unique)
	keys := [PropertyName.from_symbol(first), PropertyName.from_symbol(second),
		PropertyName.from_number(1), PropertyName.from_str('01'),
		PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd800)])),
		PropertyName.from_utf16(utf16_string_from_code_units([u16(0xd801)]))]
	for index, key in keys { object.define_direct_property(key, Value.from_i32(i32(index)), 7) }
	for index, key in keys {
		assert object.get(mut vm, key)!.number == index
	}
	object.properties = object.properties.clone()
	object.properties.reverse_in_place()
	for index, key in keys {
		assert object.get(mut vm, key)!.number == index
	}
	// Ordinary public storage keeps its prior same-buffer mutation behavior.
	mut ordinary := Object.create(vm.realm(), none)
	ordinary.define_direct_property(keys[2], Value.from_i32(7), 7)
	ordinary.properties[0].key = keys[3]
	assert ordinary.get(mut vm, keys[2])!.is_undefined()
	assert ordinary.get(mut vm, keys[3])!.number == 7
}
