module webassembly

fn test_heap_matching_preserves_all_abstract_bottom_and_top_families() {
	context := BinaryTypeContext{}
	for kind in [BinaryValueKind.function_reference, .no_function_reference, .extern_reference,
		.no_extern_reference, .any_reference, .eq_reference, .i31_reference, .struct_reference,
		.array_reference, .none_reference, .exception_reference, .no_exception_reference] {
		type_ := BinaryValueType{ kind: kind }
		assert matches_binary_heap_type(type_, type_, context)
		top := top_of_binary_heap_type(type_, context)
		bottom := match top {
			.function_reference { BinaryValueKind.no_function_reference }
			.extern_reference { BinaryValueKind.no_extern_reference }
			.exception_reference { BinaryValueKind.no_exception_reference }
			else { BinaryValueKind.none_reference }
		}
		assert matches_binary_heap_type(BinaryValueType{ kind: bottom }, type_, context)
		assert matches_binary_heap_type(type_, BinaryValueType{ kind: top }, context)
		for other_top in [BinaryValueKind.function_reference, .extern_reference, .exception_reference,
			.any_reference] {
			if other_top != top {
				assert !matches_binary_heap_type(type_, BinaryValueType{ kind: other_top }, context)
			}
		}
		assert !matches_binary_reference_type(type_, BinaryValueType{ kind: kind, nullable: false }, context)
		assert matches_binary_reference_type(BinaryValueType{ kind: kind, nullable: false }, type_, context)
	}
	assert !matches_binary_heap_type(BinaryValueType{ kind: .any_reference }, BinaryValueType{ kind: .eq_reference }, context)
	assert !matches_binary_heap_type(BinaryValueType{ kind: .struct_reference }, BinaryValueType{ kind: .array_reference }, context)
	assert !matches_binary_value_type(BinaryValueType{ kind: .i32 }, BinaryValueType{ kind: .i64 }, context)
	assert !matches_binary_value_type(BinaryValueType{ kind: .i32 }, BinaryValueType{ kind: .function_reference }, context)
	assert matches_binary_value_type(BinaryValueType{ kind: .i32 }, BinaryValueType{ kind: .i32, nullable: false }, context)
}

fn test_defined_heap_matching_uses_actual_ancestry_and_composite_expansion() {
	mut decoder := Decoder{
		bytes: [u8(4), 0x50, 0, 0x5f, 0, 0x4f, 1, 0, 0x5f, 0, 0x5e, 0x7f, 0, 0x60, 0, 0]
	}
	resolved := canonicalize_binary_module_types(parse_type_section(mut decoder)!)!
	context := BinaryTypeContext{ types: resolved }
	assert matches_binary_defined_type(resolved[1], resolved[0])
	assert !matches_binary_defined_type(resolved[0], resolved[1])
	assert !matches_binary_defined_type(resolved[2], resolved[0])
	for index in 0 .. 4 {
		type_ := BinaryValueType{ kind: .type_use_reference, type_index: u32(index) }
		expansion := if index < 2 {
			BinaryValueKind.struct_reference
		} else if index == 2 {
			BinaryValueKind.array_reference
		} else {
			BinaryValueKind.function_reference
		}
		assert matches_binary_heap_type(type_, BinaryValueType{ kind: expansion }, context)
		if index < 3 {
			assert matches_binary_heap_type(type_, BinaryValueType{ kind: .eq_reference }, context)
		}
		assert !matches_binary_heap_type(type_, BinaryValueType{ kind: .extern_reference }, context)
	}
	assert matches_binary_heap_type(BinaryValueType{ kind: .type_use_reference, type_index: 1 }, BinaryValueType{ kind: .type_use_reference, type_index: 0 }, context)
	assert !matches_binary_heap_type(BinaryValueType{ kind: .type_use_reference, type_index: 0 }, BinaryValueType{ kind: .type_use_reference, type_index: 1 }, context)
	assert matches_binary_tag_type(resolved[0], resolved[0])
	assert !matches_binary_tag_type(resolved[1], resolved[0])
}

fn test_composite_matching_retains_function_variance_struct_prefix_and_mutable_invariance() {
	context := BinaryTypeContext{}
	any := BinaryValueType{ kind: .any_reference }
	eq := BinaryValueType{ kind: .eq_reference }
	first := BinaryDefinedType{ kind: .function_, parameters: [any], results: [eq] }
	second := BinaryDefinedType{ kind: .function_, parameters: [eq], results: [any] }
	assert matches_binary_composite_type(first, second, context)
	assert !matches_binary_composite_type(second, first, context)
	assert !matches_binary_result_types([any], [any, any], context)
	covariant := BinaryFieldType{ type_: eq }
	general := BinaryFieldType{ type_: any }
	assert matches_binary_field_type(covariant, general, context)
	assert !matches_binary_field_type(BinaryFieldType{ ...covariant, mutable_: true }, BinaryFieldType{ ...general, mutable_: true }, context)
	assert !matches_binary_field_type(covariant, BinaryFieldType{ ...covariant, mutable_: true }, context)
	assert matches_binary_field_type(BinaryFieldType{ type_: BinaryValueType{ kind: .i8 } }, BinaryFieldType{ type_: BinaryValueType{ kind: .i8 } }, context)
	assert !matches_binary_field_type(BinaryFieldType{ type_: BinaryValueType{ kind: .i8 } }, BinaryFieldType{ type_: BinaryValueType{ kind: .i32 } }, context)
	struct_first := BinaryDefinedType{ kind: .struct_, fields: [covariant, general] }
	struct_second := BinaryDefinedType{ kind: .struct_, fields: [general] }
	assert matches_binary_composite_type(struct_first, struct_second, context)
	assert !matches_binary_composite_type(struct_second, struct_first, context)
	assert matches_binary_composite_type(BinaryDefinedType{ kind: .array, fields: [covariant] }, BinaryDefinedType{ kind: .array, fields: [general] }, context)
	assert !matches_binary_composite_type(struct_first, BinaryDefinedType{ kind: .array, fields: [general] }, context)
}

fn test_cross_module_table_and_global_matching_closes_actual_canonical_types() {
	mut first_decoder := Decoder{ bytes: [u8(1), 0x5f, 0] }
	first_types := canonicalize_binary_module_types(parse_type_section(mut first_decoder)!)!
	mut second_decoder := Decoder{ bytes: [u8(2), 0x60, 0, 0, 0x5f, 0] }
	second_types := canonicalize_binary_module_types(parse_type_section(mut second_decoder)!)!
	first_context := BinaryTypeContext{ types: first_types }
	second_context := BinaryTypeContext{ types: second_types }
	first := BinaryValueType{ kind: .type_use_reference, type_index: 0 }
	second := BinaryValueType{ kind: .type_use_reference, type_index: 1 }
	limits := WasmLimits{ minimum: 2, maximum: 5 }
	assert matches_binary_table_type(BinaryTableType{ element_type: first, limits: limits }, BinaryTableType{ element_type: second, limits: limits }, first_context, second_context)
	assert !matches_binary_table_type(BinaryTableType{ element_type: first, limits: limits }, BinaryTableType{ element_type: BinaryValueType{ ...second, nullable: false }, limits: limits }, first_context, second_context)
	assert matches_binary_global_type(BinaryGlobalType{ type_: first, mutable_: true }, BinaryGlobalType{ type_: second, mutable_: true }, first_context, second_context)
	assert matches_binary_global_type(BinaryGlobalType{ type_: first }, BinaryGlobalType{ type_: BinaryValueType{ kind: .any_reference } }, first_context, second_context)
	assert !matches_binary_global_type(BinaryGlobalType{ type_: first, mutable_: true }, BinaryGlobalType{ type_: BinaryValueType{ kind: .any_reference }, mutable_: true }, first_context, second_context)
	assert !matches_binary_global_type(BinaryGlobalType{ type_: first }, BinaryGlobalType{ type_: second, mutable_: true }, first_context, second_context)
	assert matches_binary_limits(limits, WasmLimits{ minimum: 1, maximum: 8 })
	assert matches_binary_limits(limits, WasmLimits{ minimum: 1 })
	assert !matches_binary_limits(WasmLimits{ minimum: 2 }, limits)
	assert !matches_binary_limits(WasmLimits{ minimum: 1, maximum: 5 }, limits)
	assert !matches_binary_memory_type(limits, WasmLimits{ ...limits, address_type: .i64 })
	assert !matches_binary_table_type(BinaryTableType{ element_type: first, limits: limits }, BinaryTableType{ element_type: second, limits: WasmLimits{ ...limits, address_type: .i64 } }, first_context, second_context)
}
