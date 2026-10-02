// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(GlobalSection). The fork initially
// sees only imported globals; each successful definition becomes visible to
// the following initializer, preserving the pinned source's ordered rule.
fn (validator &BinaryInstructionValidator) validate_global_section(mut definitions []BinaryGlobalDefinition) ! {
	mut section_validator := &BinaryInstructionValidator{ context: validator.context }
	section_validator.context.globals = validator.context.globals_without_internal_globals.clone()
	for mut definition in definitions {
		validate_binary_value_type(definition.type_.type_, section_validator.context.types)!
		result := section_validator.validate_expression(mut definition.initializer, [definition.type_.type_])!
		if !result.is_constant { return error('CompileError: invalid global variable initializer') }
		if result.result_types.len != 1 {
			return error('CompileError: invalid global variable initializer type')
		}
		section_validator.context.globals << definition.type_
	}
}
