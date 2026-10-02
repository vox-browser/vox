module webassembly

fn test_recursive_type_registry_reuses_process_identity_after_group_relocation() {
	mut first_decoder := Decoder{ bytes: [u8(1), 0x4e, 2, 0x5f, 1, 0x63, 1, 0, 0x5e, 0x64, 0, 1] }
	first_types := parse_type_section(mut first_decoder)!
	first := canonicalize_binary_module_types(first_types)!
	mut second_decoder := Decoder{ bytes: [u8(2), 0x60, 0, 0, 0x4e, 2, 0x5f, 1, 0x63, 2, 0, 0x5e,
		0x64, 1, 1] }
	second_types := parse_type_section(mut second_decoder)!
	second := canonicalize_binary_module_types(second_types)!
	assert voidptr(first[0]) == voidptr(second[1])
	assert voidptr(first[1]) == voidptr(second[2])
	assert first[0].sub_type().fields[0].type_.type_index == first[1].registry_index()
	assert first[1].sub_type().fields[0].type_.type_index == first[0].registry_index()
	assert first[0].sub_type().rec_group == BinaryRecGroupSpan{ start: first[0].registry_index(), count: 2 }
	context := BinaryTypeContext{ types: second }
	closed := canonicalized_binary_type(BinaryValueType{ kind: .type_use_reference, type_index: 2, nullable: false }, context)
	assert closed.type_index == first[1].registry_index() && !closed.nullable
	assert voidptr(BinaryTypeContext{}.resolve(closed.type_index)?) == voidptr(first[1])
	assert context.resolve(99) == none
	assert canonicalized_binary_type(closed, BinaryTypeContext{}) == closed
}

fn test_registry_closes_earlier_group_references_and_retains_ancestry() {
	mut decoder := Decoder{
		bytes: [u8(3), 0x50, 0, 0x5f, 1, 0x7f, 0, 0x50, 1, 0, 0x5f, 2, 0x7f, 0, 0x63, 0, 0, 0x4f,
			1, 1, 0x5f, 2, 0x7f, 0, 0x63, 0, 0]
	}
	types := parse_type_section(mut decoder)!
	resolved := canonicalize_binary_module_types(types)!
	again := canonicalize_binary_module_types(types)!
	for i, type_ in resolved {
		assert voidptr(type_) == voidptr(again[i])
	}
	assert resolved[0].supertype() == none
	assert voidptr(resolved[1].supertype()?) == voidptr(resolved[0])
	assert voidptr(resolved[2].supertype()?) == voidptr(resolved[1])
	assert resolved[2].subtyping_depth() == 2
	assert resolved[2].ancestors().len == 3
	for i, ancestor in resolved[2].ancestors() {
		assert voidptr(ancestor) == voidptr(resolved[i])
	}
	assert resolved[1].sub_type().fields[1].type_.type_index == resolved[0].registry_index()
	assert resolved[2].is_final() && !resolved[0].is_final()
}

fn test_registry_group_key_preserves_mutability_nullability_kind_and_group_size() {
	mut decoder := Decoder{
		bytes: [u8(4), 0x5e, 0x70, 0, 0x5e, 0x64, 0x70, 0, 0x5e, 0x70, 1, 0x5f, 1, 0x70, 0]
	}
	types := canonicalize_binary_module_types(parse_type_section(mut decoder)!)!
	for i in 0 .. types.len {
		for j in i + 1 .. types.len {
			assert voidptr(types[i]) != voidptr(types[j])
		}
	}
	mut paired_decoder := Decoder{ bytes: [u8(1), 0x4e, 2, 0x5e, 0x70, 0, 0x5e, 0x70, 0] }
	paired := canonicalize_binary_module_types(parse_type_section(mut paired_decoder)!)!
	assert voidptr(paired[0]) != voidptr(types[0])
	assert voidptr(paired[0]) != voidptr(paired[1])
	closed := canonicalize_binary_type(BinaryDefinedType{ kind: .function_, parameters: [BinaryValueType{ kind: .i64 }] }, BinaryTypeContext{})
	assert voidptr(closed) == voidptr(canonicalize_binary_type(closed.sub_type(), BinaryTypeContext{}))
}

fn test_registry_rejects_malformed_spans_unknown_types_and_forward_supertypes() {
	for type_ in [
		BinaryDefinedType{ rec_group: BinaryRecGroupSpan{ start: 1, count: 1 } },
		BinaryDefinedType{ rec_group: BinaryRecGroupSpan{ count: 2 } },
	] {
		if _ := canonicalize_binary_module_types([type_]) {
			assert false
		} else {
			assert err.msg() == 'CompileError: malformed recursive type group spans'
		}
	}
	mut unknown := Decoder{ bytes: [u8(1), 0x5f, 1, 0x63, 1, 0] }
	if _ := canonicalize_binary_module_types(parse_type_section(mut unknown)!) {
		assert false
	} else {
		assert err.msg() == 'CompileError: unknown type 1 referenced from recursive type group'
	}
	mut forward := Decoder{ bytes: [u8(1), 0x4e, 2, 0x50, 1, 1, 0x5f, 0, 0x50, 0, 0x5f, 0] }
	if _ := canonicalize_binary_module_types(parse_type_section(mut forward)!) {
		assert false
	} else {
		assert err.msg().contains('supertypes must precede their subtypes')
	}
}

fn canonical_types_in_thread(types []BinaryDefinedType) []&BinaryCanonicalType {
	return canonicalize_binary_module_types(types) or { panic(err.msg()) }
}

fn test_registry_concurrent_interning_retains_one_actual_identity() {
	types := [BinaryDefinedType{ kind: .function_, parameters: [BinaryValueType{ kind: .v128 }], rec_group: BinaryRecGroupSpan{ count: 1 } }]
	mut workers := []thread []&BinaryCanonicalType{}
	for _ in 0 .. 8 { workers << spawn canonical_types_in_thread(types) }
	resolved := workers.wait()
	for result in resolved {
		assert voidptr(result[0]) == voidptr(resolved[0][0])
	}
}
