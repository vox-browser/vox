module webassembly

import webidl

fn binary_type_module(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1]
	mut length := u32(payload.len)
	for {
		part := u8(length & 0x7f)
		length >>= 7
		bytes << if length == 0 { part } else { part | 0x80 }
		if length == 0 { break }
	}
	bytes << payload
	return bytes
}

fn test_type_section_retains_numeric_vector_and_reference_function_signature() {
	payload := [u8(1), 0x60, 7, 0x7f, 0x7e, 0x7d, 0x7c, 0x7b, 0x70, 0x64, 0x6f, 2, 0x6f, 0x63,
		0]
	compiled := Module.construct(webidl.BufferSource.array_buffer(binary_type_module(payload)))!
	assert compiled.types.len == 1
	type_ := compiled.types[0]
	assert type_.kind == .function_
	assert type_.parameters.map(it.kind) == [BinaryValueKind.i32, .i64, .f32, .f64, .v128,
		.function_reference, .extern_reference]
	assert type_.parameters[5].nullable
	assert !type_.parameters[6].nullable
	assert type_.results[0].kind == .extern_reference
	assert type_.results[1] == BinaryValueType{ kind: .type_use_reference, type_index: 0 }
	assert type_.is_final && type_.supertypes.len == 0
	assert type_.rec_group == BinaryRecGroupSpan{ start: 0, count: 1 }
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.types == compiled.types
}

fn test_type_section_flattens_recursive_groups_and_retains_packed_fields_and_supertypes() {
	payload := [u8(3), 
	// Implicit singleton group: non-final struct with a mutable i8 field.
	0x50, 0, 0x5f, 1, 0x78, 1, 
	// Explicit group: final struct extending type 0, and an array of refs.
	0x4e, 2, 0x4f, 1, 0, 0x5f, 2, 0x78, 1, 0x77, 0, 0x5e, 0x63, 1, 1, 
	// Final singleton function.
	0x60, 0, 0]
	compiled := compile_module(binary_type_module(payload))!
	assert compiled.types.len == 4
	assert compiled.types[0].kind == .struct_
	assert !compiled.types[0].is_final
	assert compiled.types[0].fields[0] == BinaryFieldType{ type_: BinaryValueType{ kind: .i8 }, mutable_: true }
	assert compiled.types[1].supertypes == [u32(0)]
	assert compiled.types[1].is_final
	assert compiled.types[1].fields[1].type_.kind == .i16
	assert !compiled.types[1].fields[1].mutable_
	assert compiled.types[1].rec_group == BinaryRecGroupSpan{ start: 1, count: 2 }
	assert compiled.types[2].rec_group == compiled.types[1].rec_group
	assert compiled.types[2].kind == .array
	assert compiled.types[2].fields[0].type_.type_index == 1
	assert compiled.types[3].rec_group == BinaryRecGroupSpan{ start: 3, count: 1 }
	// Empty recursive groups consume no type indices, as in source parsing.
	empty := compile_module(binary_type_module([u8(2), 0x4e, 0, 0x60, 0, 0]))!
	assert empty.types.len == 1
	assert empty.types[0].rec_group == BinaryRecGroupSpan{ start: 0, count: 1 }
}

fn test_reference_tags_and_signed_heap_type_index_boundaries_match_source_parser() {
	expected := [BinaryValueKind.exception_reference, .array_reference, .struct_reference,
		.i31_reference, .eq_reference, .any_reference, .extern_reference, .function_reference,
		.none_reference, .no_extern_reference, .no_function_reference, .no_exception_reference]
	for i, kind in expected {
		for prefix in [u8(0), 0x63, 0x64] {
			mut bytes := []u8{}
			if prefix != 0 { bytes << prefix }
			bytes << u8(0x69 + i)
			mut decoder := Decoder{ bytes: bytes }
			type_ := parse_binary_value_type(mut decoder)!
			assert type_.kind == kind
			assert type_.nullable == (prefix != 0x64)
			assert decoder.offset == bytes.len
		}
	}
	for bytes in [[u8(0)], [u8(0x80), 0], [u8(0xff), 0xff, 0xff, 0xff, 0x0f]] {
		mut decoder := Decoder{ bytes: bytes }
		heap := parse_heap_type(mut decoder)!
		assert heap.kind == .type_use_reference
		assert heap.type_index == if bytes.len == 5 { max_u32 } else { u32(0) }
	}
	for bytes in [[u8(0x7f)], [u8(0x7e)], [u8(0xff), 0xff, 0xff, 0xff, 0x10],
		[u8(0x80), 0x80, 0x80, 0x80, 0x80, 0], [u8(0x80)]] {
		mut decoder := Decoder{ bytes: bytes }
		if _ := parse_heap_type(mut decoder) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
}

fn test_module_compilation_rejects_malformed_type_section_instead_of_skipping_it() {
	for payload in [
		[u8(1), 0x61], // Unknown composite tag.
		[u8(1), 0x60, 1, 0x78, 0], // Packed storage is not a value type.
		[u8(1), 0x60, 1, 0x65, 0], // Unknown reference tag.
		[u8(1), 0x60, 1, 0x63], // Missing heap type.
		[u8(1), 0x5f, 1, 0x7f, 2], // Invalid field mutability.
		[u8(1), 0x5e, 0x77], // Missing array field mutability.
		[u8(1), 0x50, 1], // Missing supertype index.
		[u8(1), 0x4e, 1], // Truncated recursive group.
		[u8(0), 0x60], // Trailing bytes after vector.
	] {
		assert !validate(webidl.BufferSource.array_buffer(binary_type_module(payload)))
		if _ := compile_module(binary_type_module(payload)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
}
