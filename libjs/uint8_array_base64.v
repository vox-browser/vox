module libjs

// Runtime/Uint8Array.cpp; the AK decoder boundary uses the translated pinned
// simdutf scalar codec, retaining partial output, read counts and error kinds.
fn parse_base64_alphabet(mut vm VM, options &Object) !Base64Alphabet {
	value := options.get(mut vm, PropertyName.from_str('alphabet'))!
	if value.is_undefined() { return .base64 }
	if value.is_string() {
		if value.as_string().utf16_string() == utf16_string('base64') { return .base64 }
		if value.as_string().utf16_string() == utf16_string('base64url') { return .base64url }
	}
	return vm.throw_error_type(.type_error, .option_is_not_valid_value, value.str(), 'alphabet')
}

fn parse_base64_last_chunk_handling(mut vm VM, options &Object) !Base64LastChunkHandling {
	value := options.get(mut vm, PropertyName.from_str('lastChunkHandling'))!
	if value.is_undefined() { return .loose }
	if value.is_string() {
		for index, name in ['loose', 'strict', 'stop-before-partial'] {
			if value.as_string().utf16_string() == utf16_string(name) {
				return [Base64LastChunkHandling.loose, .strict, .stop_before_partial][index]
			}
		}
	}
	return vm.throw_error_type(.type_error, .option_is_not_valid_value, value.str(),
		'lastChunkHandling')
}

pub fn from_base64(mut vm VM, text Utf16String, alphabet Base64Alphabet, handling Base64LastChunkHandling, max_length ?uint) Uint8ArrayDecodeResult {
	units := text.as_slice()
	capacity := max_length or { base64_decode_capacity(units) }
	result := decode_base64_codec(units, capacity, alphabet, handling)
	if result.error in [.success, .output_buffer_too_small] {
		return Uint8ArrayDecodeResult{
			read:  result.read
			bytes: result.bytes
		}
	}
	message := match result.error {
		.extra_bits { 'Extra bits found at end of chunk' }
		.input_remainder { 'Invalid trailing data' }
		.invalid_character { 'Invalid base64 character' }
		else { panic('invalid base64 decoder status') }
	}

	return Uint8ArrayDecodeResult{
		read:  result.read
		bytes: result.bytes
		error: completion_from_error(vm.throw_error(.syntax_error, message))
	}
}

pub fn uint8_array_constructor_from_base64(mut vm VM, prototype_getter IntrinsicPrototypeGetter) !Value {
	realm := vm.realm()
	string_value := vm.argument(0)
	options_value := vm.argument(1)
	if !string_value.is_string() {
		return vm.throw_error_type(.type_error, .not_a_string, string_value.str())
	}
	mut alphabet := Base64Alphabet.base64
	mut handling := Base64LastChunkHandling.loose
	if !options_value.is_undefined() {
		options := get_options_object(mut vm, options_value)!
		alphabet = parse_base64_alphabet(mut vm, options)!
		handling = parse_base64_last_chunk_handling(mut vm, options)!
	}
	result := from_base64(mut vm, string_value.as_string().utf16_string(), alphabet, handling, none)
	if error := result.error { return error.release_error() }
	buffer := ArrayBufferObject.create_from_bytes(realm, result.bytes, false,
		realm.array_buffer_prototype_record())
	array := TypedArray.create(realm, .uint8, u32(result.bytes.len), buffer,
		prototype_getter(realm))
	assert array.viewed_buffer.byte_length() == uint(result.bytes.len)
	return Value.from_object(array.object)
}

pub fn uint8_array_prototype_set_from_base64(mut vm VM, primitives PrimitiveObjectPrototypes, object_prototype &Object) !Value {
	realm := vm.realm()
	string_value := vm.argument(0)
	options_value := vm.argument(1)
	mut into := validate_uint8_array(mut vm, primitives)!
	if !string_value.is_string() {
		return vm.throw_error_type(.type_error, .not_a_string, string_value.str())
	}
	options := get_options_object(mut vm, options_value)!
	alphabet := parse_base64_alphabet(mut vm, options)!
	handling := parse_base64_last_chunk_handling(mut vm, options)!
	// Options getters can detach, resize or restore the view before this witness.
	record := make_typed_array_with_buffer_witness_record(into, .seq_cst)
	if is_typed_array_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'TypedArray')
	}
	length := typed_array_length(record)
	result := from_base64(mut vm, string_value.as_string().utf16_string(), alphabet, handling,
		uint(length))
	assert uint(result.bytes.len) <= uint(length)
	set_uint8_array_bytes(mut vm, mut into, result.bytes)
	if error := result.error { return error.release_error() }
	mut object := Object.create(realm, object_prototype)
	read_defined := object.create_data_property(mut vm, PropertyName.from_str('read'),
		Value.from_f64(f64(result.read)))!
	assert read_defined
	written_defined := object.create_data_property(mut vm, PropertyName.from_str('written'),
		Value.from_f64(f64(result.bytes.len)))!
	assert written_defined
	return Value.from_object(object)
}

// Ladybird 986504619b4f: reject an oversized result before copying the input.
fn uint8_array_base64_output_length(mut vm VM, length uint, omit_padding bool) !uint {
	full_groups := checked_js_string_length_product(mut vm, length / 3, 4,
		.string_size_must_not_overflow)!
	remaining := length % 3
	final_group := if remaining == 0 { uint(0) } else if omit_padding { remaining + 1 } else { uint(4) }
	return checked_js_string_length_sum(mut vm, full_groups, final_group,
		.string_size_must_not_overflow)
}

pub fn uint8_array_prototype_to_base64(mut vm VM, primitives PrimitiveObjectPrototypes) !Value {
	options_value := vm.argument(0)
	array := validate_uint8_array(mut vm, primitives)!
	mut alphabet := Base64Alphabet.base64
	mut omit_padding := false
	if !options_value.is_undefined() {
		options := get_options_object(mut vm, options_value)!
		alphabet = parse_base64_alphabet(mut vm, options)!
		omit_padding = options.get(mut vm, PropertyName.from_str('omitPadding'))!.to_boolean()
	}
	length := uint8_array_byte_length(mut vm, array)!
	uint8_array_base64_output_length(mut vm, length, omit_padding)!
	bytes := array.viewed_buffer.read_bytes(uint(array.byte_offset), length)
	return Value.from_string(vm.create_string(encode_base64_codec(bytes, alphabet, omit_padding)))
}
