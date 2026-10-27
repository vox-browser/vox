// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Configuration.cpp::prepare_call/prepare_wasm_call; no interpreter substitute.
module webassembly

// V's Result channel requires IError. Keep the actual source Trap payload;
// code is the language-required error-interface slot, not a Wasm trap code.
pub fn (trap BinaryMachineTrap) msg() string { return trap.format() }

pub fn (trap BinaryMachineTrap) code() int { return 0 }

// V 0.5.2 cannot nest Option inside Result. This header owns the source
// Optional<HostFunction&>, while Result keeps the actual Trap error alternative.
pub struct BinaryMachinePreparedFunction {
pub:
	host_function ?&BinaryMachineHostFunction
}

pub fn (mut configuration BinaryMachineConfiguration) prepare_call(address u64, mut arguments BinaryMachineArguments, is_tailcall bool) !BinaryMachinePreparedFunction {
	function := configuration.store_.get_function(address) or {
		return BinaryMachineTrap.from_string('Attempt to call nonexistent function by address')
	}
	if function is BinaryMachineWasmFunction {
		configuration.prepare_wasm_call(unsafe { &function }, mut arguments, is_tailcall)!
		return BinaryMachinePreparedFunction{}
	}
	if function is BinaryMachineHostFunction {
		return BinaryMachinePreparedFunction{ host_function: unsafe { &function } }
	}
	panic('Source unreachable FunctionInstance alternative')
}

pub fn (mut configuration BinaryMachineConfiguration) prepare_wasm_call(function &BinaryMachineWasmFunction, mut arguments BinaryMachineArguments, is_tailcall bool) ! {
	// Source deliberately does not wait for asynchronous native compilation.
	if is_tailcall { configuration.unwind_impl() }
	code := function.code()
	inlined := code.body.compiled_instructions.cranelift_inlined_locals
	arguments.ensure_capacity(arguments.size() + code.total_local_count() + uint(inlined))
	for local in code.locals {
		for _ in uint(0) .. uint(local.count) {
			arguments.unchecked_append(BinaryMachineValue.from_type(local.type_))
		}
	}
	for _ in u32(0) .. inlined {
		arguments.unchecked_append(BinaryMachineValue.from_type(BinaryValueType{ kind: .i32 }))
	}
	configuration.set_frame(if is_tailcall { BinaryIsTailcall.yes } else { BinaryIsTailcall.no }, function.module(), mut arguments, &code.body, uint(function.type_().results.len))
}
