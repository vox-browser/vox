// Copyright (c) 2021-2025, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp::binary_numeric_operation and unary_operation.
// The caller's concrete operator adapts PopType/PushType to machine Values.
module webassembly

pub type BinaryMachineBinaryNumericOperator = fn (BinaryMachineValue, BinaryMachineValue) !BinaryMachineValue
pub type BinaryMachineUnaryNumericOperator = fn (BinaryMachineValue) !BinaryMachineValue

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) binary_numeric_operation(mut configuration BinaryMachineConfiguration, addresses &BinarySourcesAndDestination, mix BinarySourceAddressMix, operator BinaryMachineBinaryNumericOperator) bool {
	sources := unsafe { &addresses.operands.sources[0] }
	// Source consumes RHS first, then borrows the remaining actual LHS slot.
	rhs := configuration.take_source(mix, 0, sources)
	mut lhs_slot := configuration.source_value(mix, 1, sources)
	lhs := unsafe { *lhs_slot }
	result := operator(lhs, rhs) or { return interpreter.trap_if_not(false, err.msg()) }
	unsafe { *lhs_slot = result }
	return false
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) unary_operation(configuration &BinaryMachineConfiguration, addresses &BinarySourcesAndDestination, mix BinarySourceAddressMix, input_arg u8, operator BinaryMachineUnaryNumericOperator) bool {
	sources := unsafe { &addresses.operands.sources[0] }
	mut entry := configuration.source_value(mix, input_arg, sources)
	value := unsafe { *entry }
	result := operator(value) or { return interpreter.trap_if_not(false, err.msg()) }
	unsafe { *entry = result }
	return false
}
