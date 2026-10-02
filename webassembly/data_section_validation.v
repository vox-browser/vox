// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(DataSection).
fn (mut validator BinaryInstructionValidator) validate_data_section(mut segments []BinaryDataSegment) ! {
	if count := validator.context.data_count {
		if u64(segments.len) != u64(count) {
			return error('CompileError: invalid data count does not match segment count')
		}
	}
	for mut segment in segments {
		if segment.mode == .passive { continue }
		index := segment.memory_index or { panic('missing parsed active memory index') }
		memory := validator.memory_for_index(index)!
		at := binary_address_value_type(memory)
		mut expression := segment.offset or { panic('missing parsed active data offset') }
		result := validator.validate_expression(mut expression, [at])!
		segment.offset = expression
		if !result.is_constant { return error('CompileError: invalid active data initializer') }
		if result.result_types.len != 1 || !result.result_types[0].is_of_kind(at.kind) {
			return error('CompileError: invalid active data initializer type')
		}
	}
}
