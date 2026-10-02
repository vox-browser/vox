// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(TableSection). Defined globals are
// excluded from this fork even though their types are in the module context.
fn (validator &BinaryInstructionValidator) validate_table_section(mut definitions []BinaryTableDefinition) ! {
	mut section_validator := &BinaryInstructionValidator{ context: validator.context }
	section_validator.context.globals = validator.context.globals_without_internal_globals.clone()
	for mut definition in definitions {
		validate_binary_table_type(definition.type_, section_validator.context.types)!
		result := section_validator.validate_expression(mut definition.initializer, [definition.type_.element_type])!
		if !result.is_constant { return error('CompileError: invalid table initializer') }
		if result.result_types.len != 1 {
			return error('CompileError: invalid table initializer type')
		}
	}
}
