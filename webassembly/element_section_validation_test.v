module webassembly

fn element_validation_module(table []u8, segment []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, 4, 1, 0x60, 0, 0, 2, 5, 1, 0, 0, 0, 0]
	if table.len > 0 {
		bytes << [u8(4), u8(table.len + 1), 1]
		bytes << table
	}
	bytes << [u8(9), u8(segment.len + 1), 1]
	bytes << segment
	return bytes
}

fn test_elements_validate_legacy_function_vectors_and_active_memory64_table_offsets() {
	legacy := compile_module(element_validation_module([u8(0x70), 0, 0], [u8(0), 0x41, 0, 0x0b,
		1, 0]))!
	assert legacy.element_segments[0].items[0].stack_usage_hint? == 1
	assert legacy.element_segments[0].offset?.stack_usage_hint? == 1
	for tag in [u8(1), 3] {
		compiled := compile_module(element_validation_module([], [tag, 0, 1, 0]))!
		assert compiled.element_segments[0].items[0].stack_usage_hint? == 1
	}
	compiled := compile_module(element_validation_module([u8(0x6f), 4, 0], [u8(6), 0, 0x42, 0,
		0x0b, 0x6f, 1, 0xd0, 0x6f, 0x0b]))!
	assert compiled.element_segments[0].offset?.stack_usage_hint? == 1
	assert compiled.element_segments[0].items[0].stack_usage_hint? == 1
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.element_segments == compiled.element_segments
}

fn test_elements_reject_reference_mismatch_nonconstant_wrong_offset_surplus_and_undeclared_functions() {
	for segment in [
		[u8(6), 0, 0x41, 0, 0x0b, 0x6f, 0],
		[u8(0), 0x42, 0, 0x0b, 0],
		[u8(0), 0x41, 0, 0x01, 0x0b, 0],
		[u8(0), 0x41, 0, 0x41, 0, 0x0b, 0],
		[u8(1), 0, 1, 1],
		[u8(5), 0x70, 1, 0xd0, 0x70, 0x01, 0x0b],
		[u8(5), 0x70, 1, 0xd0, 0x70, 0xd0, 0x70, 0x0b],
		[u8(2), 1, 0x41, 0, 0x0b, 0, 0],
	] {
		if _ := compile_module(element_validation_module([u8(0x70), 0, 0], segment)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
}

fn test_source_element_validator_keeps_empty_expression_fast_path_and_value_type_validation_rule() {
	mut validator := &BinaryInstructionValidator{}
	mut segments := [BinaryElementSegment{
		mode:         .passive
		element_type: BinaryValueType{ kind: .i32 }
		items:        [BinaryExpression{}]
	}]
	validator.validate_element_section(mut segments)!
	// The pinned C++ validates ValueType here, with no extra reference-kind
	// assertion for passive numeric entries. Retain its actual behavior.
	compiled := compile_module(element_validation_module([], [u8(5), 0x7f, 1, 0x41, 0, 0x0b]))!
	assert compiled.element_segments[0].element_type.kind == .i32
}
