// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: type-section, subtype and composite validation.
module webassembly

const binary_max_subtyping_depth = u32(63)
const binary_max_function_parameters = 1000
const binary_max_function_results = 1000
const binary_max_struct_fields = 10000

// Vox materializes ancestor arrays while canonicalizing, before composite
// validation. Bound the hierarchy first so invalid types cannot grow them.
fn validate_binary_subtyping_depths(types []BinaryDefinedType) ! {
	mut depths := []u32{len: types.len}
	for index, type_ in types {
		if type_.supertypes.len > 1 {
			return error('CompileError: invalid supertype count, only a single supertype is allowed')
		}
		for super_index in type_.supertypes {
			if u64(super_index) >= u64(index) {
				return error('CompileError: invalid supertype index, must precede the subtype')
			}
			depth := depths[super_index] + 1
			if depth > binary_max_subtyping_depth {
				return error('CompileError: subtyping depth is too large')
			}
			depths[index] = depth
		}
	}
}

fn validate_binary_value_type(type_ BinaryValueType, types []BinaryDefinedType) ! {
	if type_.kind == .type_use_reference && u64(type_.type_index) >= u64(types.len) {
		return error('CompileError: invalid TypeIndex')
	}
}

fn validate_binary_type_section(types []BinaryDefinedType, canonical []&BinaryCanonicalType) ! {
	for index, type_ in types {
		if type_.supertypes.len > 1 {
			return error('CompileError: invalid supertype count, only a single supertype is allowed')
		}
		for super_index in type_.supertypes {
			if u64(super_index) >= u64(index) {
				return error('CompileError: invalid supertype index, must precede the subtype')
			}
			if u64(super_index) >= u64(types.len) {
				return error('CompileError: invalid TypeIndex')
			}
			if types[super_index].is_final {
				return error('CompileError: invalid supertype, must not be final')
			}
			if !matches_binary_composite_type(canonical[index].sub_type_, canonical[super_index].sub_type_, BinaryTypeContext{}) {
				return error('CompileError: invalid subtype, composite type must match its declared supertype')
			}
		}
		match type_.kind {
			.function_ {
				if type_.parameters.len > binary_max_function_parameters {
					return error('CompileError: too many parameters')
				}
				if type_.results.len > binary_max_function_results {
					return error('CompileError: too many results')
				}
				for value in type_.parameters { validate_binary_value_type(value, types)! }
				for value in type_.results { validate_binary_value_type(value, types)! }
			}
			.struct_ {
				if type_.fields.len > binary_max_struct_fields {
					return error('CompileError: too many struct fields')
				}
				for field in type_.fields { validate_binary_value_type(field.type_, types)! }
			}
			.array { validate_binary_value_type(type_.fields[0].type_, types)! }
		}
	}
}
