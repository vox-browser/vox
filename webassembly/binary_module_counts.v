// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
module webassembly

// AbstractMachine/Validator.cpp::validate(Module).
// Imported functions do not participate in the defined-function/body count.
fn validate_module_function_count(function_types []u32, bodies []BinaryFunctionBody) ! {
	if function_types.len != bodies.len { return error('CompileError: invalid FunctionSection') }
}
