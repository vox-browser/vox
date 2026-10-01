module libjs

fn test_bigint_wrapper_retains_the_exact_primitive_cell_and_ordinary_prototype() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(42), 7)
	for text in ['0', '-1', '9007199254740993', '18446744073709551616'] {
		bigint := string_to_bigint(utf16_string(text))?
		wrapper := BigIntObject.create(vm.realm(), bigint, parent)
		assert voidptr(wrapper.bigint) == voidptr(bigint)
		assert voidptr(wrapper.object.bigint_object?) == voidptr(wrapper)
		assert wrapper.bigint.big_integer.str() == text
		assert wrapper.object.class_name == 'BigInt' && wrapper.object.properties.len == 0
		assert voidptr(wrapper.object.prototype?) == voidptr(parent)
		assert wrapper.object.get(mut vm, PropertyName.from_str('inherited'))!.number == 42
		assert wrapper.object.number_object == none && wrapper.object.symbol_object == none
	}
}

fn test_bigint_wrappers_share_the_primitive_and_keep_independent_ordinary_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	bigint := string_to_bigint(utf16_string('42'))?
	a := BigIntObject.create(vm.realm(), bigint, parent)
	b := BigIntObject.create(vm.realm(), bigint, parent)
	assert voidptr(a.object) != voidptr(b.object)
	assert voidptr(a.bigint) == voidptr(b.bigint)
	mut object := a.object
	assert object.create_data_property(mut vm, PropertyName.from_str('extra'), Value.from_i32(17))!
	assert b.object.get(mut vm, PropertyName.from_str('extra'))!.is_undefined()
	assert a.bigint.big_integer.str() == '42'
}
