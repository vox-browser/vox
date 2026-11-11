// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

const binary_max_function_locals = u64(50000)

// AbstractMachine/Validator.cpp::validate(CodeSection), through expression
// validation and the function-result check. Native compiled call-record sizing
// and callee inlining remain with the untranslated instruction compiler.
fn (validator &BinaryInstructionValidator) validate_code_section(mut functions []BinaryFunctionBody) ! {
	mut index := validator.context.imported_function_count
	for mut function in functions {
		function_index := index
		index++
		assert u64(function_index) <= u64(max_u32)
		if function_index >= validator.context.functions.len {
			return error('CompileError: invalid FunctionIndex')
		}
		type_ := validator.context.functions[function_index]
		// Count all runs and parameters before expanding locals. Recompute in
		// u64 so directly constructed function bodies cannot wrap the cached sum.
		mut local_count := u64(type_.parameters.len)
		for local in function.locals { local_count += u64(local.count) }
		if local_count > binary_max_function_locals {
			return error('CompileError: too many locals')
		}
		mut function_validator := &BinaryInstructionValidator{ context: validator.context }
		function_validator.context.locals = type_.parameters.clone()
		function_validator.context.current_function_parameter_count = type_.parameters.len
		for local in function.locals {
			validate_binary_value_type(local.type_, function_validator.context.types)!
			for _ in 0 .. local.count { function_validator.context.locals << local.type_ }
		}
		for _ in type_.parameters { function_validator.local_initialized << true }
		for local in function.locals {
			for _ in 0 .. local.count {
				function_validator.local_initialized << local.type_.is_defaultable_storage()
			}
		}
		function_validator.push_frame(BinaryValidationFrame{ type_: type_, kind: .function_, initial_size: 0 })
		result := function_validator.validate_expression(mut function.body, type_.results)!
		if result.result_types.len != type_.results.len {
			return error('CompileError: invalid function result')
		}
	}
}
