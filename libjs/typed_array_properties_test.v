module libjs

@[heap]
struct TypedArrayPropertyLog {
mut:
	events []string
}

fn test_typed_array_integer_indexed_properties_suppress_prototypes_and_keep_ordinary_key_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	for name in ['0', '3', '-0', 'NaN', '1.5', '4294967295', '01', 'label'] {
		parent.define_direct_property(PropertyName.from_str(name), Value.from_i32(99), 7)
	}
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 3, parent)!
	buffer.maximum_byte_length = uint(8)
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	mut object := array.object
	assert object.get(mut vm, PropertyName.from_number(0))!.number == 0
	assert object.has_property(PropertyName.from_number(0))
	assert !object.internal_delete(PropertyName.from_number(0))
	for name in ['3', '-0', 'NaN', '1.5', '4294967295'] {
		key := PropertyName.from_str(name)
		assert object.get(mut vm, key)!.is_undefined(), name
		assert !object.has_property(key) && !object.has_own_property(key), name
		assert object.internal_delete(key)
		assert !object.create_data_property(mut vm, key, Value.from_i32(42))!
	}
	assert object.get(mut vm, PropertyName.from_str('01'))!.number == 99
	assert object.get(mut vm, PropertyName.from_str('label'))!.number == 99
	first := PropertyName.from_symbol(Symbol.create(utf16_string('first'), .unique))
	second := PropertyName.from_symbol(Symbol.create(utf16_string('second'), .unique))
	private_key := PropertyName.from_symbol(Symbol.create_private())
	for key in [first, PropertyName.from_str('label'), PropertyName.from_str('01'), second,
		private_key] {
		assert object.create_data_property(mut vm, key, Value.from_i32(17))!
	}
	assert object.own_property_keys().map(it.str()) == ['0', '1', '2', 'label', '01', 'Symbol(first)',
		'Symbol(second)']
	assert buffer.try_resize(2, true)
	assert object.own_property_keys().map(it.str()) == ['label', '01', 'Symbol(first)',
		'Symbol(second)']
	assert object.get(mut vm, PropertyName.from_number(0))!.is_undefined()
	assert !object.has_property(PropertyName.from_number(0))
	assert object.internal_delete(PropertyName.from_number(0))
	assert buffer.try_resize(3, true)
	assert object.own_property_keys().map(it.str()) == ['0', '1', '2', 'label', '01', 'Symbol(first)',
		'Symbol(second)']
	assert object.internal_delete(PropertyName.from_str('label'))
	assert object.create_data_property(mut vm, PropertyName.from_str('label'), Value.from_i32(42))!
	assert object.own_property_keys().map(it.str()) == ['0', '1', '2', '01', 'label', 'Symbol(first)',
		'Symbol(second)']
	detach_array_buffer(mut vm, mut buffer, none)!
	assert object.own_property_keys().map(it.str()) == ['01', 'label', 'Symbol(first)',
		'Symbol(second)']
}

fn test_typed_array_definitions_validate_descriptors_before_converting_values() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 2, buffer, parent)
	mut object := array.object
	mut log := &TypedArrayPropertyLog{}
	mut value := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'convert'
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('valueOf'), none)
	value.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(convert.object), 7)
	for descriptor in [
		PropertyDescriptor{
			value:        Value.from_object(value)
			configurable: false
		},
		PropertyDescriptor{
			value:      Value.from_object(value)
			enumerable: false
		},
		PropertyDescriptor{
			value:    Value.from_object(value)
			writable: false
		},
		PropertyDescriptor{
			getter: js_undefined()
		},
		PropertyDescriptor{
			setter: js_undefined()
		},
	] {
		assert !object.internal_define_own_property(mut vm, PropertyName.from_number(0), descriptor)!
	}
	assert !object.internal_define_own_property(mut vm, PropertyName.from_number(2), PropertyDescriptor{
		value: Value.from_object(value)
	})!
	assert log.events.len == 0
	assert object.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{})!
	assert object.create_data_property(mut vm, PropertyName.from_number(0),
		Value.from_object(value))!
	assert log.events == ['convert'] && buffer.read_bytes(0, 2) == [u8(42), 0]
	assert object.internal_prevent_extensions()
	assert object.create_data_property(mut vm, PropertyName.from_number(1), Value.from_i32(17))!
	assert !object.create_data_property(mut vm, PropertyName.from_str('ordinary'),
		Value.from_i32(17))!
	// The virtual descriptor advertises configurable=true, but deleting the
	// element and changing its attributes are prohibited by the exotic methods.
	assert !object.internal_delete(PropertyName.from_number(1))
	if _ := object.set_integrity_level(mut vm, .sealed) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_typed_array_set_uses_receiver_identity_and_does_not_coerce_other_receiver_invalid_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), 1, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 1, buffer, parent)
	mut object := array.object
	mut receiver := Object.create(vm.realm(), object)
	mut log := &TypedArrayPropertyLog{}
	mut value := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'convert'
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('valueOf'), none)
	value.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(convert.object), 7)
	for name in ['1', '-0'] {
		assert object.internal_set(mut vm, PropertyName.from_str(name), Value.from_object(value),
			Value.from_object(receiver))!
		assert !receiver.has_own_property(PropertyName.from_str(name))
	}
	assert log.events.len == 0
	assert object.internal_set(mut vm, PropertyName.from_number(0), Value.from_object(value),
		Value.from_object(receiver))!
	assert voidptr(receiver.get(mut vm, PropertyName.from_number(0))!.as_object()) == voidptr(value)
	assert buffer.read_bytes(0, 1) == [u8(0)] && log.events.len == 0
	assert object.internal_set(mut vm, PropertyName.from_number(0), Value.from_i32(7), js_null())! == false
	assert object.internal_set(mut vm, PropertyName.from_number(1), Value.from_i32(7), js_null())!
	for name in ['1', '-0'] {
		assert object.internal_set(mut vm, PropertyName.from_str(name), Value.from_object(value),
			Value.from_object(object))!
	}
	assert log.events == ['convert', 'convert']
	assert object.internal_set(mut vm, PropertyName.from_number(0), Value.from_object(value),
		Value.from_object(object))!
	assert buffer.read_bytes(0, 1) == [u8(42)]
	assert receiver.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{
		writable: false
	})!
	assert !object.internal_set(mut vm, PropertyName.from_number(0), Value.from_i32(9),
		Value.from_object(receiver))!
	assert buffer.read_bytes(0, 1) == [u8(42)]
}

fn test_typed_array_set_rechecks_bounds_after_observable_value_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['shrink', 'detach', 'grow', 'throw'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 2, parent)!
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		array.array_length = ByteLength.auto_length()
		array.byte_length = ByteLength.auto_length()
		mut object := array.object
		mut log := &TypedArrayPropertyLog{}
		mut value := Object.create(vm.realm(), none)
		convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut buffer, mut log, mode] (mut vm VM) !Value {
			log.events << 'convert'
			if mode == 'shrink' { assert buffer.try_resize(1, true)
			 }
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
			if mode == 'grow' { assert buffer.try_resize(4, true)
			 }
			if mode == 'throw' { return throw_completion(Value.from_i32(17)) }
			return Value.from_i32(42)
		}, 0, PropertyName.from_str('valueOf'), none)
		value.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(convert.object), 7)
		index := if mode == 'grow' { u32(3) } else { u32(1) }
		if result := object.internal_set(mut vm, PropertyName.from_number(index),
			Value.from_object(value), Value.from_object(object))
		{
			assert mode != 'throw' && result
			if mode == 'grow' { assert buffer.read_bytes(0, 4) == [u8(0), 0, 0, 42]
			 }
			if mode == 'shrink' { assert buffer.read_bytes(0, 1) == [u8(0)]
			 }
			if mode == 'detach' { assert buffer.is_detached()
			 }
		} else {
			assert mode == 'throw' && thrown_value(err).number == 17
		}
		assert log.events == ['convert']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_buffer_is_view_dispatches_real_typed_array_slots() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 1, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 1, buffer, parent)
	method := vm.realm().array_buffer_constructor_record().get(mut vm,
		PropertyName.from_str('isView'))!
	assert call(mut vm, method, js_undefined(), [Value.from_object(array.object)])!.as_bool()
	detach_array_buffer(mut vm, mut buffer, none)!
	assert call(mut vm, method, js_undefined(), [Value.from_object(array.object)])!.as_bool()
	mut fake := Object.create(vm.realm(), parent)
	fake.class_name = 'Uint8Array'
	for value in [Value.from_object(fake), Value.from_object(buffer.object),
		js_undefined()] {
		assert !call(mut vm, method, js_undefined(), [value])!.as_bool()
	}
}

fn test_typed_array_definition_rechecks_detachment_after_conversion_but_rejects_initial_invalid_index() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 1, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 1, buffer, parent)
	mut object := array.object
	mut log := &TypedArrayPropertyLog{}
	mut value := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut buffer, mut log] (mut vm VM) !Value {
		log.events << 'convert'
		detach_array_buffer(mut vm, mut buffer, none)!
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('valueOf'), none)
	value.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(convert.object), 7)
	assert !object.internal_define_own_property(mut vm, PropertyName.from_number(1), PropertyDescriptor{
		value: Value.from_object(value)
	})!
	assert log.events.len == 0 && !buffer.is_detached()
	assert object.internal_define_own_property(mut vm, PropertyName.from_number(0), PropertyDescriptor{
		value: Value.from_object(value)
	})!
	assert log.events == ['convert'] && buffer.is_detached()
	assert !object.has_own_property(PropertyName.from_number(0))
}
