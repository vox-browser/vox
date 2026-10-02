// Copyright (c) 2026, Ali Mohammad Pur <ali@ladybird.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/TypeSystem.cpp: defined/heap/reference/value/field/composite matching.
module webassembly

pub fn matches_binary_defined_type(first &BinaryCanonicalType, second &BinaryCanonicalType) bool {
	if voidptr(first) == voidptr(second) { return true }
	if second.subtyping_depth_ >= first.subtyping_depth_ { return false }
	return voidptr(first.ancestors_[second.subtyping_depth_]) == voidptr(second)
}

pub fn top_of_binary_heap_type(type_ BinaryValueType, context BinaryTypeContext) BinaryValueKind {
	return match type_.kind {
		.any_reference, .eq_reference, .i31_reference, .struct_reference, .array_reference,
		.none_reference {
			BinaryValueKind.any_reference
		}
		.function_reference, .no_function_reference { BinaryValueKind.function_reference }
		.extern_reference, .no_extern_reference { BinaryValueKind.extern_reference }
		.exception_reference, .no_exception_reference { BinaryValueKind.exception_reference }
		.type_use_reference {
			defined := context.resolve(type_.type_index) or { panic('unresolved heap type') }
			if defined.sub_type_.kind == .function_ {
				BinaryValueKind.function_reference
			} else {
				BinaryValueKind.any_reference
			}
		}
		else { panic('heap type must be a reference') }
	}
}

pub fn matches_binary_heap_type(first BinaryValueType, second BinaryValueType, context BinaryTypeContext) bool {
	if !first.is_reference() || !second.is_reference() { panic('heap types must be references') }
	if first.kind == second.kind {
		if first.kind != .type_use_reference { return true }
		defined_first := context.resolve(first.type_index) or { panic('unresolved first heap type') }
		defined_second := context.resolve(second.type_index) or { panic('unresolved second heap type') }
		return matches_binary_defined_type(defined_first, defined_second)
	}
	match first.kind {
		.eq_reference { return second.kind == .any_reference }
		.i31_reference, .struct_reference, .array_reference {
			return second.kind in [.eq_reference, .any_reference]
		}
		.type_use_reference {
			defined := context.resolve(first.type_index) or { panic('unresolved heap type') }
			return match second.kind {
				.function_reference { defined.sub_type_.kind == .function_ }
				.struct_reference { defined.sub_type_.kind == .struct_ }
				.array_reference { defined.sub_type_.kind == .array }
				.eq_reference, .any_reference { defined.sub_type_.kind in [.struct_, .array] }
				else { false }
			}
		}
		.none_reference { return top_of_binary_heap_type(second, context) == .any_reference }
		.no_function_reference {
			return top_of_binary_heap_type(second, context) == .function_reference
		}
		.no_exception_reference {
			return top_of_binary_heap_type(second, context) == .exception_reference
		}
		.no_extern_reference {
			return top_of_binary_heap_type(second, context) == .extern_reference
		}
		else { return false }
	}
}

pub fn matches_binary_reference_type(first BinaryValueType, second BinaryValueType, context BinaryTypeContext) bool {
	if first.nullable && !second.nullable { return false }
	return matches_binary_heap_type(first, second, context)
}

pub fn matches_binary_value_type(first BinaryValueType, second BinaryValueType, context BinaryTypeContext) bool {
	if first.is_reference() && second.is_reference() {
		return matches_binary_reference_type(first, second, context)
	}
	return !first.is_reference() && !second.is_reference() && first.kind == second.kind
}

pub fn matches_binary_result_types(first []BinaryValueType, second []BinaryValueType, context BinaryTypeContext) bool {
	if first.len != second.len { return false }
	for i, value in first {
		if !matches_binary_value_type(value, second[i], context) { return false }
	}
	return true
}

fn matches_binary_storage_type(first BinaryValueType, second BinaryValueType, context BinaryTypeContext) bool {
	if first.kind in [.i8, .i16] || second.kind in [.i8, .i16] { return first.kind == second.kind }
	return matches_binary_value_type(first, second, context)
}

pub fn matches_binary_field_type(first BinaryFieldType, second BinaryFieldType, context BinaryTypeContext) bool {
	if first.mutable_ != second.mutable_ { return false }
	if !matches_binary_storage_type(first.type_, second.type_, context) { return false }
	if first.mutable_ && !matches_binary_storage_type(second.type_, first.type_, context) {
		return false
	}
	return true
}

pub fn matches_binary_composite_type(first BinaryDefinedType, second BinaryDefinedType, context BinaryTypeContext) bool {
	if first.kind != second.kind { return false }
	match second.kind {
		.function_ {
			return matches_binary_result_types(second.parameters, first.parameters, context)
				&& matches_binary_result_types(first.results, second.results, context)
		}
		.struct_ {
			if first.fields.len < second.fields.len { return false }
			for i, field in second.fields {
				if !matches_binary_field_type(first.fields[i], field, context) { return false }
			}
			return true
		}
		.array { return matches_binary_field_type(first.fields[0], second.fields[0], context) }
	}
}

pub fn matches_binary_limits(first WasmLimits, second WasmLimits) bool {
	if first.minimum < second.minimum { return false }
	if maximum := second.maximum {
		first_maximum := first.maximum or { return false }
		return first_maximum <= maximum
	}
	return true
}

pub fn matches_binary_memory_type(first WasmLimits, second WasmLimits) bool {
	if first.address_type != second.address_type { return false }
	return matches_binary_limits(first, second)
}

pub fn matches_binary_table_type(first BinaryTableType, second BinaryTableType, first_context BinaryTypeContext, second_context BinaryTypeContext) bool {
	if first.limits.address_type != second.limits.address_type { return false }
	if !matches_binary_limits(first.limits, second.limits) { return false }
	first_element := canonicalized_binary_type(first.element_type, first_context)
	second_element := canonicalized_binary_type(second.element_type, second_context)
	return matches_binary_reference_type(first_element, second_element, BinaryTypeContext{})
		&& matches_binary_reference_type(second_element, first_element, BinaryTypeContext{})
}

pub fn matches_binary_global_type(first BinaryGlobalType, second BinaryGlobalType, first_context BinaryTypeContext, second_context BinaryTypeContext) bool {
	if first.mutable_ != second.mutable_ { return false }
	first_value := canonicalized_binary_type(first.type_, first_context)
	second_value := canonicalized_binary_type(second.type_, second_context)
	if !matches_binary_value_type(first_value, second_value, BinaryTypeContext{}) { return false }
	if first.mutable_ && !matches_binary_value_type(second_value, first_value, BinaryTypeContext{}) {
		return false
	}
	return true
}

pub fn matches_binary_tag_type(first &BinaryCanonicalType, second &BinaryCanonicalType) bool {
	return matches_binary_defined_type(first, second) && matches_binary_defined_type(second, first)
}
