// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine/Validator.cpp: type-section, subtype and composite validation.
module webassembly

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
				for value in type_.parameters { validate_binary_value_type(value, types)! }
				for value in type_.results { validate_binary_value_type(value, types)! }
			}
			.struct_ {
				for field in type_.fields { validate_binary_value_type(field.type_, types)! }
			}
			.array { validate_binary_value_type(type_.fields[0].type_, types)! }
		}
	}
}
