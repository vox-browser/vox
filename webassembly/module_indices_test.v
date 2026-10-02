module webassembly

import webidl

fn indices_module_binary(sections []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0]
	bytes << sections
	return bytes
}

fn append_indices_section(mut bytes []u8, kind u8, payload []u8) {
	bytes << [kind, u8(payload.len)]
	bytes << payload
}

fn test_validation_context_retains_imports_definitions_and_declared_ref_func_set() {
	mut sections := []u8{}
	append_indices_section(mut sections, 1, [u8(3), 0x60, 0, 0, 0x5f, 0, 0x5e, 0x7f, 0])
	append_indices_section(mut sections, 2, [u8(5), 0, 1, `f`, 0, 0, 0, 1, `t`, 1, 0x63, 1, 0,
		0, 0, 1, `m`, 2, 0, 0, 0, 1, `g`, 3, 0x6f, 0, 0, 1, `x`, 4, 0, 0])
	append_indices_section(mut sections, 3, [u8(1), 0])
	append_indices_section(mut sections, 4, [u8(1), 0x70, 0, 0])
	append_indices_section(mut sections, 5, [u8(1), 0, 0])
	append_indices_section(mut sections, 13, [u8(1), 0, 0])
	append_indices_section(mut sections, 6, [u8(1), 0x70, 0, 0xd2, 1, 0x0b])
	append_indices_section(mut sections, 7, [u8(5), 1, `f`, 0, 1, 1, `t`, 1, 0, 1, `m`, 2, 1, 1,
		`g`, 3, 1, 1, `x`, 4, 1])
	append_indices_section(mut sections, 8, [u8(1)])
	append_indices_section(mut sections, 9, [u8(1), 1, 0, 2, 0, 1])
	append_indices_section(mut sections, 10, [u8(1), 2, 0, 0x0b])
	append_indices_section(mut sections, 11, [u8(1), 1, 0])
	compiled := compile_module(indices_module_binary(sections))!
	context := validate_binary_module_indices(compiled)!
	assert context.types.len == 3 && context.canonical_types.len == 3
	assert context.functions.len == 2 && context.imported_function_count == 1
	assert context.function_type_indices.len == 2
	first_index := context.function_type_indices[0]
	second_index := context.function_type_indices[1]
	assert first_index? == 0 && second_index? == 0
	assert context.tables.len == 2 && context.memories.len == 2 && context.globals.len == 2
	assert context.elements.len == 1 && context.datas == [false] && context.tags.len == 2
	assert context.references.len == 2 && context.references[0] && context.references[1]
}

fn test_source_context_keeps_nonfunction_type_index_imports_in_composite_lists() {
	compiled := compile_module(indices_module_binary([u8(1), 9, 3, 0x60, 0, 0, 0x5f, 0, 0x5e, 0x7f,
		0, 2, 9, 2, 0, 0, 0, 1, 0, 0, 0, 2]))!
	context := validate_binary_module_indices(compiled)!
	assert context.structs.len == 1 && context.arrays.len == 1
	assert context.functions.len == 0 && context.imported_function_count == 0
}

fn test_module_indices_reject_unknown_indices_and_invalid_start_signatures() {
	for sections in [
		[u8(2), 5, 1, 0, 0, 0, 0], // Imported TypeIndex without types.
		[u8(3), 2, 1, 0, 10, 4, 1, 2, 0, 0x0b], // Defined TypeIndex without types.
		[u8(1), 3, 1, 0x5f, 0, 3, 2, 1, 0, 10, 4, 1, 2, 0, 0x0b], // Defined non-function.
		[u8(7), 4, 1, 0, 0, 0],
		[u8(7), 4, 1, 0, 1, 0],
		[u8(7), 4, 1, 0, 2, 0],
		[u8(7), 4, 1, 0, 3, 0],
		[u8(7), 4, 1, 0, 4, 0],
		[u8(8), 1, 0],
		[u8(1), 5, 1, 0x60, 1, 0x7f, 0, 2, 5, 1, 0, 0, 0, 0, 8, 1, 0],
		[u8(1), 5, 1, 0x60, 0, 1, 0x7f, 2, 5, 1, 0, 0, 0, 0, 8, 1, 0],
		[u8(1), 4, 1, 0x60, 0, 0, 2, 5, 1, 0, 0, 0, 0, 8, 1, 1],
	] {
		assert !validate(webidl.BufferSource.array_buffer(indices_module_binary(sections)))
	}
}

fn test_module_scope_validates_typed_references_tag_signatures_and_duplicate_export_names() {
	for sections in [
		[u8(4), 5, 1, 0x63, 0, 0, 0],
		[u8(6), 7, 1, 0x63, 0, 0, 0xd0, 0x70, 0x0b],
		[u8(13), 3, 1, 0, 0],
		[u8(1), 3, 1, 0x5f, 0, 13, 3, 1, 0, 0],
		[u8(1), 5, 1, 0x60, 0, 1, 0x7f, 13, 3, 1, 0, 0],
		[u8(1), 3, 1, 0x5f, 0, 2, 6, 1, 0, 0, 4, 0, 0],
		[u8(4), 8, 1, 0x70, 0, 0x80, 0x80, 0x80, 0x80, 0x10], // Table32 limit.
		[u8(4), 4, 1, 0x70, 1, 1], // Missing maximum.
	] {
		assert !validate(webidl.BufferSource.array_buffer(indices_module_binary(sections)))
	}
	for payload in [[u8(2), 1, `x`, 0, 0, 1, `x`, 0, 1], [u8(2), 1, `x`, 0, 0, 1, `x`, 4, 0]] {
		mut sections := []u8{}
		append_indices_section(mut sections, 7, payload)
		if _ := compile_module(indices_module_binary(sections)) {
			assert false
		} else {
			assert err.msg() == "CompileError: Duplicate exported name 'x'"
		}
	}
}
