module libjs

fn uint8_hex_test_call(mut vm VM, name string, receiver Value, arguments []Value, parent &Object) !Value {
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	primitives := PrimitiveObjectPrototypes{
		number: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
		bigint: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
		string: fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		}
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, getter, primitives, parent] (mut vm VM) !Value {
		return match name {
			'fromHex' { uint8_array_constructor_from_hex(mut vm, getter)! }
			'setFromHex' { uint8_array_prototype_set_from_hex(mut vm, primitives, parent)! }
			else { uint8_array_prototype_to_hex(mut vm, primitives)! }
		}
	}, if name == 'toHex' { 0.0 } else { 1.0 }, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_from_hex_preserves_upstream_vectors_and_all_byte_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vectors := {
		'':                         []u8{}
		'61':                       [u8(97)]
		'616263646566303132333435': 'abcdef012345'.bytes()
		'f09fa493':                 '🤓'.bytes()
		'f09fa493666f6ff09f9696':   '🤓foo🖖'.bytes()
		'aAbBcCdDeEfF':             [u8(170), 187, 204, 221, 238, 255]
	}
	for text, expected in vectors {
		result := from_hex(mut vm, utf16_string(text), none)
		assert result.error == none && result.bytes == expected
		assert result.read == uint(text.len)
	}
	mut text := ''
	mut expected := []u8{}
	for value in 0 .. 256 {
		text += '${value:02X}'
		expected << u8(value)
	}
	result := from_hex(mut vm, utf16_string(text), none)
	assert result.bytes == expected && result.read == 512 && result.error == none
}

fn test_from_hex_checks_global_even_length_before_capacity_and_preserves_partial_records() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for limit in [uint(0), 1, 2, 99] {
		odd := from_hex(mut vm, utf16_string('61z'), limit)
		error := odd.error?
		assert odd.read == 0 && odd.bytes.len == 0
		assert error.value.as_object().error_kind()? == .syntax_error
		assert error.value.as_object().error_message()?.str() == 'Hex string must have an even length'
	}
	for text in ['61zz', '61+1', '61-1', '61 1', '611 ', '61\n0', '610x', '61\x000', '61é0'] {
		result := from_hex(mut vm, utf16_string(text), none)
		error := result.error?
		assert result.read == 2 && result.bytes == [u8(97)]
		assert error.value.as_object().error_message()?.str() == 'Hex string must only contain hex characters'
	}
	for unit in [u16(0xd800), 0xdc00, 0xff11, 0x0100] {
		result := from_hex(mut vm, Utf16String.from_slice([u16(`6`), u16(`1`), unit, u16(`0`)]), none)
		assert result.read == 2 && result.bytes == [u8(97)] && result.error != none
	}
	for index, limit in [uint(0), 1, 2] {
		result := from_hex(mut vm, utf16_string('6162zz'), limit)
		assert result.error == none
		assert result.read == uint(index * 2) && result.bytes == [u8(97), 98][..index]
	}
}

fn test_uint8_array_from_hex_ignores_this_and_returns_fresh_fixed_current_realm_storage() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for receiver in [js_null(), js_undefined(), Value.from_i32(42),
		Value.from_object(parent)] {
		first := uint8_hex_test_call(mut vm, 'fromHex', receiver, [
			Value.from_string(vm.create_string_from_str('2a00FF')),
		], parent)!
		second := uint8_hex_test_call(mut vm, 'fromHex', receiver, [
			Value.from_string(vm.create_string_from_str('2a00FF')),
		], parent)!
		array := first.as_object().typed_array?
		other := second.as_object().typed_array?
		assert array.kind == .uint8 && array.array_length.length() == 3
		assert array.viewed_buffer.is_fixed_length() && array.byte_offset == 0
		assert array.viewed_buffer.byte_length() == 3
		assert array.viewed_buffer.read_bytes(0, 3) == [u8(42), 0, 255]
		assert voidptr(array.object.prototype?) == voidptr(parent)
		assert voidptr(array.viewed_buffer.object.prototype?) == voidptr(vm.realm().array_buffer_prototype_record())
		assert !array.viewed_buffer.shares_storage_with(other.viewed_buffer)
	}
	for value in [js_undefined(), Value.from_i32(42),
		Value.from_object(StringObject.create(vm.realm(), vm.create_string_from_str('42'), parent).object)] {
		if _ := uint8_hex_test_call(mut vm, 'fromHex', js_undefined(), [value], parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_hex_rejects_other_kinds_and_inherited_or_fake_slots_before_string_validation() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 8, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 8, buffer, parent)
	mut fake := Object.create(vm.realm(), array.object)
	fake.class_name = 'Uint8Array'
	mut receivers := [js_null(), js_undefined(), Value.from_i32(42),
		Value.from_bool(false), Value.from_string(vm.create_string_from_str('42')),
		Value.from_object(fake)]
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint16, .uint32, .uint8_clamped] {
		receivers << Value.from_object(TypedArray.create(vm.realm(), kind, 1, buffer, parent).object)
	}
	for receiver in receivers {
		for name in ['setFromHex', 'toHex'] {
			if _ := uint8_hex_test_call(mut vm, name, receiver, [
				Value.from_i32(42)], parent)
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()?.str() == if receiver.is_nullish() {
					'ToObject on null or undefined'
				} else {
					'Not an object of type Uint8Array'
				}
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_set_from_hex_writes_prefix_before_syntax_error_and_counts_only_consumed_input() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 9, 9, 9, 9], false, parent)
	mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1),
		Value.from_i32(3))!
	receiver := Value.from_object(array.object)
	result := uint8_hex_test_call(mut vm, 'setFromHex', receiver, [
		Value.from_string(vm.create_string_from_str('2a')),
	], parent)!.as_object()
	assert result.get(mut vm, PropertyName.from_str('read'))!.number == 2
	assert result.get(mut vm, PropertyName.from_str('written'))!.number == 1
	assert result.own_property_keys() == [PropertyName.from_str('read'),
		PropertyName.from_str('written')]
	assert voidptr(result.prototype?) == voidptr(parent)
	for name in ['read', 'written'] {
		descriptor := result.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	}
	assert buffer.read_bytes(0, 5) == [u8(9), 42, 9, 9, 9]
	if _ := uint8_hex_test_call(mut vm, 'setFromHex', receiver, [
		Value.from_string(vm.create_string_from_str('1122zz')),
	], parent)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .syntax_error
	}
	assert buffer.read_bytes(0, 5) == [u8(9), 17, 34, 9, 9]
	if _ := uint8_hex_test_call(mut vm, 'setFromHex', receiver, [
		Value.from_string(vm.create_string_from_str('3344z')),
	], parent)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .syntax_error
	}
	assert buffer.read_bytes(0, 5) == [u8(9), 17, 34, 9, 9]
	limited := uint8_hex_test_call(mut vm, 'setFromHex', receiver, [
		Value.from_string(vm.create_string_from_str('010203zz')),
	], parent)!.as_object()
	assert limited.get(mut vm, PropertyName.from_str('read'))!.number == 6
	assert limited.get(mut vm, PropertyName.from_str('written'))!.number == 3
	assert buffer.read_bytes(0, 5) == [u8(9), 1, 2, 3, 9]
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_hex_live_fixed_tracking_shared_bounds_and_argument_error_order() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 42, 17, 43],
			shared_buffer, parent)
		buffer.maximum_byte_length = uint(8)
		mut fixed := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		mut tracking := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut fixed, buffer, Value.from_i32(1),
			Value.from_i32(3))!
		initialize_typed_array_from_array_buffer(mut vm, mut tracking, buffer, Value.from_i32(1),
			js_undefined())!
		assert uint8_hex_test_call(mut vm, 'toHex', Value.from_object(fixed.object), []Value{},
			parent)!.as_string().str() == '2a112b'
		assert buffer.try_resize(6, true)
		assert uint8_hex_test_call(mut vm, 'toHex', Value.from_object(tracking.object), []Value{},
			parent)!.as_string().str() == '2a112b0000'
		if shared_buffer { continue
		 }
		assert buffer.try_resize(1, true)
		assert uint8_hex_test_call(mut vm, 'toHex', Value.from_object(tracking.object), []Value{},
			parent)!.as_string().str() == ''
		zero := uint8_hex_test_call(mut vm, 'setFromHex', Value.from_object(tracking.object), [
			Value.from_string(vm.create_string_from_str('zz')),
		], parent)!.as_object()
		assert zero.get(mut vm, PropertyName.from_str('read'))!.number == 0
		assert zero.get(mut vm, PropertyName.from_str('written'))!.number == 0
		for name in ['toHex', 'setFromHex'] {
			if _ := uint8_hex_test_call(mut vm, name, Value.from_object(fixed.object), [
				Value.from_string(vm.create_string_from_str('')),
			], parent)
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
				assert thrown_value(err).as_object().error_message()?.str().contains("buffer's bounds")
			}
		}
		detach_array_buffer(mut vm, mut buffer, none)!
		if _ := uint8_hex_test_call(mut vm, 'setFromHex', Value.from_object(fixed.object), [
			Value.from_i32(42),
		], parent)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == '42 is not a string'
		}
		if _ := uint8_hex_test_call(mut vm, 'toHex', Value.from_object(tracking.object), []Value{},
			parent)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str().contains("buffer's bounds")
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_hex_byte_access_copies_reads_and_respects_view_offset_and_empty_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 10, 11, 12], false, parent)
	mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1),
		Value.from_i32(2))!
	mut bytes := get_uint8_array_bytes(mut vm, array)!
	bytes[0] = 255
	assert buffer.read_bytes(0, 4) == [u8(9), 10, 11, 12]
	set_uint8_array_bytes(mut vm, mut array, [u8(0), 255])
	assert buffer.read_bytes(0, 4) == [u8(9), 0, 255, 12]
	assert uint8_hex_test_call(mut vm, 'toHex', Value.from_object(array.object), []Value{}, parent)!.as_string().str() == '00ff'
	empty_buffer := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	empty := TypedArray.create(vm.realm(), .uint8, 0, empty_buffer, parent)
	assert uint8_hex_test_call(mut vm, 'toHex', Value.from_object(empty.object), []Value{}, parent)!.as_string().str() == ''
}
