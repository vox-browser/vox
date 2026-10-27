module libjs

// Runtime/Uint8Array.cpp::FromHex. Keep the partial bytes and the throw
// completion together: setFromHex writes those bytes before propagating error.
pub fn from_hex(mut vm VM, text Utf16String, max_length ?uint) Uint8ArrayDecodeResult {
	limit := max_length or { uint(9007199254740991) }
	units := text.as_slice()
	mut bytes := []u8{}
	mut read := uint(0)
	if units.len % 2 != 0 {
		return Uint8ArrayDecodeResult{
			error: completion_from_error(vm.throw_error(.syntax_error,
				'Hex string must have an even length'))
		}
	}
	for read < uint(units.len) && uint(bytes.len) < limit {
		// The source parses exactly two UTF-16 code units as an unsigned byte
		// with TrimWhitespace::No. Reuse the translated ASCII hex-digit path.
		first := uri_hex_digit(units[int(read)]) or {
			return Uint8ArrayDecodeResult{
				read:  read
				bytes: bytes
				error: completion_from_error(vm.throw_error(.syntax_error,
					'Hex string must only contain hex characters'))
			}
		}
		second := uri_hex_digit(units[int(read) + 1]) or {
			return Uint8ArrayDecodeResult{
				read:  read
				bytes: bytes
				error: completion_from_error(vm.throw_error(.syntax_error,
					'Hex string must only contain hex characters'))
			}
		}
		read += 2
		bytes << (first << 4) | second
	}
	return Uint8ArrayDecodeResult{
		read:  read
		bytes: bytes
	}
}

// Uint8ArrayConstructorHelpers::from_hex. The result always uses the current
// realm's Uint8Array prototype; the native this value is not a constructor.
pub fn uint8_array_constructor_from_hex(mut vm VM, prototype_getter IntrinsicPrototypeGetter) !Value {
	realm := vm.realm()
	value := vm.argument(0)
	if !value.is_string() {
		return vm.throw_error_type(.type_error, .not_a_string, value.str())
	}
	result := from_hex(mut vm, value.as_string().utf16_string(), none)
	if error := result.error {
		return error.release_error()
	}
	buffer := ArrayBufferObject.create(mut vm, realm, uint(result.bytes.len),
		realm.array_buffer_prototype_record())!
	array := TypedArray.create(realm, .uint8, u32(result.bytes.len), buffer,
		prototype_getter(realm))
	assert array.viewed_buffer.byte_length() == uint(result.bytes.len)
	mut storage := array.viewed_buffer
	storage.overwrite(0, result.bytes)
	return Value.from_object(array.object)
}

pub fn uint8_array_prototype_set_from_hex(mut vm VM, prototypes PrimitiveObjectPrototypes, object_prototype &Object) !Value {
	value := vm.argument(0)
	mut into := validate_uint8_array(mut vm, prototypes)!
	if !value.is_string() {
		return vm.throw_error_type(.type_error, .not_a_string, value.str())
	}
	record := make_typed_array_with_buffer_witness_record(into, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	length := typed_array_length(record)
	result := from_hex(mut vm, value.as_string().utf16_string(), uint(length))
	assert uint(result.bytes.len) <= uint(length)
	set_uint8_array_bytes(mut vm, mut into, result.bytes)
	if error := result.error {
		return error.release_error()
	}
	mut object := Object.create(vm.realm(), object_prototype)
	read_defined := object.create_data_property(mut vm, PropertyName.from_str('read'),
		Value.from_f64(f64(result.read)))!
	assert read_defined
	written_defined := object.create_data_property(mut vm, PropertyName.from_str('written'),
		Value.from_f64(f64(result.bytes.len)))!
	assert written_defined
	return Value.from_object(object)
}

pub fn uint8_array_prototype_to_hex(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := validate_uint8_array(mut vm, prototypes)!
	bytes := get_uint8_array_bytes(mut vm, array)!
	hex_digits := '0123456789abcdef'
	mut out := []u16{cap: bytes.len * 2}
	for byte in bytes {
		out << u16(hex_digits[byte >> 4])
		out << u16(hex_digits[byte & 0xf])
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(out)))
}
