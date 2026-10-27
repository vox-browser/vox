module libjs

fn test_array_buffer_maximum_option_reads_and_converts_once_and_clone_is_independent() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	for value in [js_undefined(), js_null(), Value.from_i32(8),
		Value.from_bool(true)] {
		assert get_array_buffer_max_byte_length_option(mut vm, value)!.value == none
	}
	mut options := Object.create(realm, none)
	assert get_array_buffer_max_byte_length_option(mut vm, Value.from_object(options))!.value == none
	options.define_direct_property(PropertyName.from_str('maxByteLength'), Value.from_f64(8.9), 7)
	assert get_array_buffer_max_byte_length_option(mut vm, Value.from_object(options))!.value? == 8
	mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4,
		uint(8))!
	source.overwrite(0, [u8(1), 2, 3, 4])
	mut clone := clone_array_buffer(mut vm, source, 1, 2)!
	assert clone.is_fixed_length() && clone.read_bytes(0, 2) == [u8(2), 3]
	assert !clone.shares_storage_with(source)
	clone.overwrite(0, [u8(9)])
	assert source.read_bytes(0, 4) == [u8(1), 2, 3, 4]
	assert voidptr(clone.object.internal_get_prototype_of()?) == voidptr(realm.array_buffer_prototype_record())
}

fn test_array_buffer_transfer_preserves_or_discards_maximum_and_keeps_failed_source_attached() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	for preserve in [PreserveResizability.preserve_resizability, .fixed_length] {
		mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4,
			uint(8))!
		source.overwrite(0, [u8(1), 2, 3, 4])
		target := array_buffer_copy_and_detach(mut vm, mut source, Value.from_i32(6), preserve)!
		assert source.is_detached() && !target.is_detached()
		assert target.read_bytes(0, 6) == [u8(1), 2, 3, 4, 0, 0]
		assert target.is_fixed_length() == (preserve == .fixed_length)
		if preserve == .preserve_resizability { assert target.max_byte_length() == 8
		 }
	}
	mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4,
		uint(8))!
	if _ := array_buffer_copy_and_detach(mut vm, mut source, Value.from_i32(9),
		.preserve_resizability)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	assert !source.is_detached() && source.byte_length() == 4
	source.detach_key = Value.from_i32(17)
	if _ := array_buffer_copy_and_detach(mut vm, mut source, js_undefined(), .fixed_length) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "Provided detach key 17 does not match the ArrayBuffer's detach key undefined"
	}
	assert !source.is_detached()
	source.detach_key = js_undefined()
	short := array_buffer_copy_and_detach(mut vm, mut source, Value.from_i32(2), .fixed_length)!
	assert short.byte_length() == 2 && source.is_detached()
}
