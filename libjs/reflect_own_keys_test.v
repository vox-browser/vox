module libjs

fn reflect_keys_call(mut vm VM, target Value, prototype &Object) !&ArrayObject {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototype] (mut vm VM) !Value {
		return reflect_own_keys(mut vm, prototype)
	}, 1, PropertyName.from_str('ownKeys'), none)
	result := call(mut vm, Value.from_object(function.object), js_null(), [target])!
	return result.as_object().array_object or { panic('real array result required') }
}

fn test_property_key_to_value_preserves_utf16_symbol_identity_and_numeric_string_cache() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Utf16String.from_slice([u16(0xd800), u16(0), u16(0xdc00)])
	string_value := PropertyName.from_utf16(text).to_value(mut vm)
	assert string_value.as_string().utf16 == text
	symbol := Symbol.create(utf16_string('key'), .unique)
	actual := PropertyName.from_symbol(symbol).to_value(mut vm)
	assert voidptr(actual.as_symbol()) == voidptr(symbol)
	for number in [u32(0), u32(42), u32(4294967294)] {
		first := PropertyName.from_number(number).to_value(mut vm)
		second := PropertyName.from_number(number).to_value(mut vm)
		assert first.is_string() && first.as_string().str() == number.str()
		assert voidptr(first.as_string()) == voidptr(second.as_string())
	}
}

fn test_reflect_own_keys_returns_fresh_arrays_in_key_order_without_reading_values_or_private_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(42), 7)
	mut object := Object.create(vm.realm(), parent)
	symbol := Symbol.create(utf16_string('visible'), .unique)
	object.define_direct_property(PropertyName.from_str('z'), Value.from_i32(1), 0)
	object.define_direct_property(PropertyName.from_number(42), Value.from_i32(1), 0)
	object.define_direct_property(PropertyName.from_symbol(symbol), Value.from_i32(1), 0)
	object.define_direct_property(PropertyName.from_number(2), Value.from_i32(1), 0)
	object.set_engine_private_property(Symbol.create_private(), Value.from_i32(1))
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('a'), fn (mut vm VM) !Value {
		panic('ownKeys never reads property values')
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	first := reflect_keys_call(mut vm, Value.from_object(object), prototype)!
	second := reflect_keys_call(mut vm, Value.from_object(object), prototype)!
	assert voidptr(first.object) != voidptr(second.object)
	assert voidptr(first.realm) == voidptr(vm.realm())
		&& voidptr(first.object.prototype?) == voidptr(prototype)
	assert first.length == 5 && first.length_writable
	for index, expected in ['2', '42', 'z', 'a'] {
		actual := first.object.get(mut vm, PropertyName.from_number(u32(index)))!
		assert actual.as_string().str() == expected
		descriptor := first.object.internal_get_own_property(PropertyName.from_number(u32(index)))?
		assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	}
	assert voidptr(first.object.get(mut vm, PropertyName.from_number(4))!.as_symbol()) == voidptr(symbol)
}

fn test_reflect_own_keys_uses_array_string_and_live_typed_array_exotic_keys() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	array := ArrayObject.create(mut vm, vm.realm(), 3, prototype)!
	mut array_object := array.object
	array_object.define_direct_property(PropertyName.from_number(2), Value.from_i32(42), 7)
	array_keys := reflect_keys_call(mut vm, Value.from_object(array_object), prototype)!
	assert array_keys.length == 2
	assert array_keys.object.get(mut vm, PropertyName.from_number(0))!.as_string().str() == '2'
	assert array_keys.object.get(mut vm, PropertyName.from_number(1))!.as_string().str() == 'length'
	text := StringObject.create(vm.realm(), vm.create_string(Utf16String.from_slice([
		u16(0xd800),
		u16(0xdc00),
	])), prototype)
	string_keys := reflect_keys_call(mut vm, Value.from_object(text.object), prototype)!
	assert string_keys.length == 3
	for index, expected in ['0', '1', 'length'] {
		assert string_keys.object.get(mut vm, PropertyName.from_number(u32(index)))!.as_string().str() == expected
	}
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2, prototype)!
	buffer.maximum_byte_length = uint(4)
	mut view := TypedArray.create(vm.realm(), .uint8, 2, buffer, prototype)
	view.array_length = ByteLength.auto_length()
	view.byte_length = ByteLength.auto_length()
	mut view_object := view.object
	view_object.define_direct_property(PropertyName.from_str('label'), Value.from_i32(42), 7)
	for size in [uint(2), uint(4), uint(1)] {
		assert buffer.try_resize(size, true)
		keys := reflect_keys_call(mut vm, Value.from_object(view_object), prototype)!
		assert keys.length == u32(size + 1)
		assert keys.object.get(mut vm, PropertyName.from_number(u32(size)))!.as_string().str() == 'label'
	}
	detach_array_buffer(mut vm, mut buffer, none)!
	keys := reflect_keys_call(mut vm, Value.from_object(view_object), prototype)!
	assert keys.length == 1
		&& keys.object.get(mut vm, PropertyName.from_number(0))!.as_string().str() == 'label'
}

fn test_reflect_own_keys_rejects_primitives_without_boxing() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	for value in [js_null(), js_undefined(), Value.from_i32(42),
		Value.from_bool(false), Value.from_string(vm.create_string_from_str('abc'))] {
		if _ := reflect_keys_call(mut vm, value, prototype) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == '${value.str()} is not an object'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
