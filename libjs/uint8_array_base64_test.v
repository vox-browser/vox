module libjs

fn uint8_base64_test_call(mut vm VM, name string, receiver Value, arguments []Value, parent &Object) !Value {
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
			'fromBase64' { uint8_array_constructor_from_base64(mut vm, getter)! }
			'setFromBase64' { uint8_array_prototype_set_from_base64(mut vm, primitives, parent)! }
			else { uint8_array_prototype_to_base64(mut vm, primitives)! }
		}
	}, if name == 'toBase64' { 0.0 } else { 1.0 }, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_uint8_array_base64_native_bodies_retain_upstream_vectors_and_ignore_static_receiver() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	vectors := {
		'':                 ''
		'Zg==':             'f'
		'Zm8=':             'fo'
		'Zm9v':             'foo'
		'Zm9vYg==':         'foob'
		'Zm9vYmE=':         'fooba'
		'Zm9vYmFy':         'foobar'
		'8J+kkw==':         '🤓'
		'8J+kk2Zvb/CflpY=': '🤓foo🖖'
	}
	for alphabet in ['base64', 'base64url'] {
		mut options := Object.create(vm.realm(), none)
		options.define_direct_property(PropertyName.from_str('alphabet'),
			Value.from_string(vm.create_string_from_str(alphabet)), 7)
		for encoded, expected in vectors {
			input := if alphabet == 'base64' {
				encoded
			} else {
				encoded.replace('+', '-').replace('/', '_')
			}
			decoded := uint8_base64_test_call(mut vm, 'fromBase64', Value.from_i32(42), [
				Value.from_string(vm.create_string_from_str(input)),
				Value.from_object(options),
			], parent)!
			array := decoded.as_object().typed_array?
			assert get_uint8_array_bytes(mut vm, array)! == expected.bytes()
			assert array.viewed_buffer.is_fixed_length()
				&& array.viewed_buffer.byte_length() == uint(expected.len)
			assert voidptr(array.object.prototype?) == voidptr(parent)
			assert uint8_base64_test_call(mut vm, 'toBase64', decoded, [
				Value.from_object(options),
			], parent)!.as_string().str() == input
			options.define_direct_property(PropertyName.from_str('omitPadding'),
				Value.from_bool(true), 7)
			assert uint8_base64_test_call(mut vm, 'toBase64', decoded, [
				Value.from_object(options),
			], parent)!.as_string().str() == input.trim_right('=')
			options.delete_property_or_throw(mut vm, PropertyName.from_str('omitPadding'))!
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_base64_errors_retain_partial_bytes_and_upstream_syntax_messages() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for input in ['Zm9va', 'Zm9vaa=', 'A==', 'Zm9v=', 'Zm9vaa=a', '-', 'Zh==', 'Zm9='] {
		mut options := Object.create(vm.realm(), none)
		options.define_direct_property(PropertyName.from_str('lastChunkHandling'),
			Value.from_string(vm.create_string_from_str('strict')), 7)
		buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 9, 9, 9, 9, 9, 9, 9],
			false, parent)
		array := TypedArray.create(vm.realm(), .uint8, 8, buffer, parent)
		message := if input in ['Zh==', 'Zm9='] {
			'Extra bits found at end of chunk'
		} else if input in ['Zm9va', 'Zm9vaa=', 'A=='] {
			'Invalid trailing data'
		} else {
			'Invalid base64 character'
		}
		for name in ['fromBase64', 'setFromBase64'] {
			if _ := uint8_base64_test_call(mut vm, name, Value.from_object(array.object), [
				Value.from_string(vm.create_string_from_str(input)),
				Value.from_object(options),
			], parent)
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .syntax_error
				assert thrown_value(err).as_object().error_message()?.str() == message
			}
		}
		assert buffer.read_bytes(0, 8) == if input.starts_with('Zm9v') {
			[u8(102), 111, 111, 9, 9, 9, 9, 9]
		} else {
			[u8(9), 9, 9, 9, 9, 9, 9, 9]
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_base64_set_result_tracks_capacity_offsets_partial_chunks_and_shared_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		for length in 0 .. 5 {
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(), []u8{len: 7, init: 9},
				shared_buffer, parent)
			mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1),
				Value.from_i32(length))!
			result := uint8_base64_test_call(mut vm, 'setFromBase64',
				Value.from_object(array.object), [
				Value.from_string(vm.create_string_from_str('Zm9vYg==')),
			], parent)!.as_object()
			written := [0, 0, 0, 3, 4][length]
			read := [0, 0, 0, 4, 8][length]
			assert result.get(mut vm, PropertyName.from_str('read'))!.number == f64(read)
			assert result.get(mut vm, PropertyName.from_str('written'))!.number == f64(written)
			assert voidptr(result.prototype?) == voidptr(parent)
			assert result.own_property_keys() == [PropertyName.from_str('read'),
				PropertyName.from_str('written')]
			assert buffer.read_bytes(1, uint(written)) == 'foob'.bytes()[..written]
			assert buffer.read_bytes(0, 1) == [u8(9)] && buffer.read_bytes(6, 1) == [u8(9)]
		}
	}
}

@[heap]
struct Uint8Base64OptionLog {
mut:
	entries []string
}

fn test_uint8_array_base64_options_are_read_before_fresh_bounds_and_do_not_coerce_option_values() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['grow', 'shrink', 'restore', 'detach', 'throw'] {
		mut log := &Uint8Base64OptionLog{}
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 9, 9, 9], false,
			parent)
		buffer.maximum_byte_length = uint(8)
		mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1), if mode == 'restore' {
			Value.from_i32(3)
		} else {
			js_undefined()
		})!
		if mode == 'restore' { assert buffer.try_resize(0, true)
		 }
		mut options := Object.create(vm.realm(), none)
		for name in ['alphabet', 'lastChunkHandling'] {
			options.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str(name), fn [name, mode, mut log, mut buffer] (mut vm VM) !Value {
				log.entries << name
				if name == 'alphabet' {
					if mode == 'throw' { return throw_completion(Value.from_i32(77)) }
					if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! }
					if mode == 'shrink' { assert buffer.try_resize(0, true)
					 }
					if mode in ['grow', 'restore'] { assert buffer.try_resize(if mode == 'grow' {
							uint(8)
						} else {
							uint(4)
						}, true)
					 }
				}
				return js_undefined()
			}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		}
		if mode in ['grow', 'restore'] {
			result := uint8_base64_test_call(mut vm, 'setFromBase64',
				Value.from_object(array.object), [
				Value.from_string(vm.create_string_from_str('Zm9v')),
				Value.from_object(options),
			], parent)!.as_object()
			assert result.get(mut vm, PropertyName.from_str('written'))!.number == 3
			assert buffer.read_bytes(1, 3) == 'foo'.bytes()
		} else {
			if _ := uint8_base64_test_call(mut vm, 'setFromBase64',
				Value.from_object(array.object), [
				Value.from_string(vm.create_string_from_str('Zm9v')),
				Value.from_object(options),
			], parent)
			{
				assert false
			} else {
				if mode == 'throw' {
					assert thrown_value(err).number == 77
				} else {
					assert thrown_value(err).as_object().error_message()?.str().contains("buffer's bounds")
				}
			}
		}
		assert log.entries == if mode == 'throw' {
			['alphabet']
		} else {
			['alphabet', 'lastChunkHandling']
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_uint8_array_to_base64_reads_alphabet_then_padding_before_bytes_and_boolean_conversion_is_not_observable() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut log := &Uint8Base64OptionLog{}
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(9), 255, 255], false, parent)
	buffer.maximum_byte_length = uint(6)
	mut array := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
	initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, Value.from_i32(1),
		js_undefined())!
	mut truthy := Object.create(vm.realm(), none)
	truthy.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		panic('ToBoolean must not invoke coercion hooks')
	}, unsafe { nil }, 4, vm.realm().function_prototype)
	mut options := Object.create(vm.realm(), none)
	options.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('alphabet'), fn [mut log] (mut vm VM) !Value {
		log.entries << 'alphabet'
		return Value.from_string(vm.create_string_from_str('base64url'))
	}, unsafe { nil }, 4, vm.realm().function_prototype)
	options.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('omitPadding'), fn [mut log, mut buffer, truthy] (mut vm VM) !Value {
		log.entries << 'omitPadding'
		assert buffer.try_resize(2, true)
		return Value.from_object(truthy)
	}, unsafe { nil }, 4, vm.realm().function_prototype)
	value := uint8_base64_test_call(mut vm, 'toBase64', Value.from_object(array.object), [
		Value.from_object(options),
	], parent)!
	assert value.as_string().str() == '_w'
	assert log.entries == ['alphabet', 'omitPadding']
}

fn test_uint8_array_base64_type_options_and_brand_errors_keep_source_order_and_recover() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 3, parent)!
	array := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	receiver := Value.from_object(array.object)
	detach_array_buffer(mut vm, mut buffer, none)!
	for name in ['fromBase64', 'setFromBase64', 'toBase64'] {
		mut arguments := []Value{}
		if name != 'toBase64' { arguments << Value.from_string(vm.create_string_from_str('')) }
		arguments << Value.from_i32(42)
		if _ := uint8_base64_test_call(mut vm, name, receiver, arguments, parent) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Options is not an object'
		}
	}
	for option in ['alphabet', 'lastChunkHandling'] {
		mut options := Object.create(vm.realm(), none)
		options.define_direct_property(PropertyName.from_str(option), Value.from_i32(42), 7)
		if _ := uint8_base64_test_call(mut vm, 'setFromBase64', receiver, [
			Value.from_string(vm.create_string_from_str('')),
			Value.from_object(options),
		], parent)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == '42 is not a valid value for option ${option}'
		}
	}
	if _ := uint8_base64_test_call(mut vm, 'setFromBase64', receiver, [
		Value.from_i32(42),
	], parent)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '42 is not a string'
	}
	wrong := TypedArray.create(vm.realm(), .uint8_clamped, 0, ArrayBufferObject.create(mut vm,
		vm.realm(), 0, parent)!, parent)
	if _ := uint8_base64_test_call(mut vm, 'setFromBase64', Value.from_object(wrong.object), [
		Value.from_i32(42),
	], parent)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type Uint8Array'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
