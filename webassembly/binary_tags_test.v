module webassembly

import webidl

fn tag_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 13, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_binary_tags_retain_definitions_imports_exports_and_source_reflection_boundary() {
	// Import a tag and function; declare another tag; export both tag and
	// function. Binary tags are retained even though pinned Module.cpp omits
	// them from its JS imports()/exports() descriptors.
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, 18, 2, 3, `e`, `n`,
		`v`, 1, `t`, 4, 0, 0, 3, `e`, `n`, `v`, 1, `f`, 0, 0, 13, 3, 1, 0, 0, 7, 9, 2, 1, `t`,
		4, 0, 1, `f`, 0, 0]
	compiled := compile_module(bytes)!
	assert compiled.tag_types == [BinaryTagType{ type_index: 0 }]
	assert compiled.tag_import_entries == [BinaryTagImport{ module: 'env', name: 't', type_: BinaryTagType{ type_index: 0 } }]
	assert compiled.tag_export_entries == [BinaryTagExport{ name: 't', index: 0 }]
	assert compiled.imports().map(it.name) == ['f']
	assert compiled.exports().map(it.name) == ['f']
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.tag_types == compiled.tag_types
	assert restored.tag_import_entries == compiled.tag_import_entries
	assert restored.tag_export_entries == compiled.tag_export_entries
	assert compile_module(tag_section_binary([u8(0)]))!.tag_types.len == 0
}

fn test_binary_tag_parser_rejects_invalid_flags_and_truncated_types() {
	for payload in [[]u8{}, [u8(1)], [u8(1), 1, 0], [u8(1), 0], [u8(1), 0, 0x80],
		[u8(1), 0, 0xff, 0xff, 0xff, 0xff, 0x10], [u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(tag_section_binary(payload)))
	}
	for descriptor in [[u8(1), 0], [u8(0)], [u8(0), 0x80]] {
		mut payload := [u8(1), 3, `e`, `n`, `v`, 1, `t`, 4]
		payload << descriptor
		mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 2, u8(payload.len)]
		bytes << payload
		assert !validate(webidl.BufferSource.array_buffer(bytes))
	}
}
