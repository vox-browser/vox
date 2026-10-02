// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(Module) and validate(DataSection).
// Imported functions do not participate in the defined-function/body count.
fn validate_module_counts(function_types []u32, bodies []BinaryFunctionBody, data_count ?u32, data []BinaryDataSegment) ! {
	if function_types.len != bodies.len { return error('CompileError: invalid FunctionSection') }
	if count := data_count {
		if u64(data.len) != count {
			return error('CompileError: invalid data count does not match segment count')
		}
	}
}
