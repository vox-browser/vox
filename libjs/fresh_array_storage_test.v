module libjs

fn test_fresh_array_data_properties_match_generic_factory_and_own_inputs() {
	for enabled in [false, true] {
		set_fresh_array_storage_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut input := [Value.from_i32(42), js_undefined(), Value.from_string(vm.create_string_from_str('😀'))]
		array := ArrayObject.create_from(mut vm, vm.realm(), input, vm.realm().array_prototype_record())!
		input[0] = Value.from_i32(99)
		assert array.length == 3 && array.length_writable
		assert array.object.get(mut vm, PropertyName.from_number(0))!.number == 42
		for index in 0 .. 3 {
			descriptor := array.object.internal_get_own_property(PropertyName.from_number(u32(index))) or { panic('missing index') }
			assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
		}
		keys := array.object.own_property_keys()
		assert keys.len == 4 && keys[0].number == 0 && keys[2].number == 2 && keys[3].str() == 'length'
		mut object := array.object
		assert object.internal_delete(PropertyName.from_number(1))
		assert array.length == 3
	}
	set_fresh_array_storage_for_testing(true)
}

fn test_fresh_array_factory_defines_own_indices_over_inherited_readonly_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), vm.realm().array_prototype_record())
	prototype.define_direct_property(PropertyName.from_number(0), Value.from_i32(99), 0)
	array := ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(42)], prototype)!
	assert array.object.get(mut vm, PropertyName.from_number(0))!.number == 42
	mut object := array.object
	assert object.internal_define_own_property(mut vm, vm.length_key(), PropertyDescriptor{value:Value.from_i32(0)})!
	assert array.length == 0 && !object.has_own_property(PropertyName.from_number(0))
}
