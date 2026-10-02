module webassembly

import webidl

fn validation_type_module(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_compilation_validates_type_groups_and_retains_canonical_identity_on_serialization() {
	payload := [u8(3), 0x50, 0, 0x5f, 1, 0x6e, 0, 0x4f, 1, 0, 0x5f, 2, 0x6d, 0, 0x78, 1, 0x4e,
		2, 0x5f, 1, 0x63, 3, 0, 0x5e, 0x64, 2, 0]
	compiled := compile_module(validation_type_module(payload))!
	assert compiled.canonical_types.len == 4
	assert matches_binary_defined_type(compiled.canonical_types[1], compiled.canonical_types[0])
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	for i, type_ in compiled.canonical_types {
		assert voidptr(type_) == voidptr(restored.canonical_types[i])
	}
	assert restored.types == compiled.types
}

fn test_type_validation_rejects_final_multiple_forward_and_incompatible_supertypes() {
	for payload in [
		[u8(2), 0x5f, 0, 0x4f, 1, 0, 0x5f, 0], // Final supertype.
		[u8(3), 0x50, 0, 0x5f, 0, 0x50, 0, 0x5f, 0, 0x4f, 2, 0, 1, 0x5f, 0],
		[u8(1), 0x4e, 2, 0x50, 1, 1, 0x5f, 0, 0x50, 0, 0x5f, 0],
		[u8(2), 0x50, 0, 0x5f, 1, 0x7f, 0, 0x4f, 1, 0, 0x5f, 0], // Too few fields.
		[u8(2), 0x50, 0, 0x5f, 1, 0x6e, 1, 0x4f, 1, 0, 0x5f, 1, 0x6d, 1], // Mutable covariance.
		[u8(2), 0x50, 0, 0x60, 0, 0, 0x4f, 1, 0, 0x5f, 0], // Composite mismatch.
		[u8(2), 0x50, 0, 0x60, 1, 0x6e, 0, 0x4f, 1, 0, 0x60, 1, 0x6d, 0], // Parameter narrowing.
	] {
		assert !validate(webidl.BufferSource.array_buffer(validation_type_module(payload)))
	}
}

fn test_type_validation_rejects_unknown_uses_and_forward_references_across_groups() {
	for payload in [[u8(1), 0x60, 1, 0x63, 1, 0], [u8(1), 0x5f, 1, 0x64, 1, 0],
		[u8(1), 0x5e, 0x63, 1, 0], [u8(2), 0x5e, 0x63, 1, 0, 0x5f, 0]] {
		assert !validate(webidl.BufferSource.array_buffer(validation_type_module(payload)))
	}
	// Forward references within the same recursive group remain valid.
	assert validate(webidl.BufferSource.array_buffer(validation_type_module([u8(1), 0x4e, 2, 0x5e,
		0x63, 1, 0, 0x5f, 0])))
}
