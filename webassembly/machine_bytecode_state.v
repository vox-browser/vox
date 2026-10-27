// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.h state and BytecodeInterpreter.cpp native-stack guard.
// This record has no interpret() substitute: opcode execution remains pending.
module webassembly

import libjs

pub struct BinaryMachineEmptyTrap {}

pub type BinaryMachineBytecodeTrapState = BinaryMachineEmptyTrap | BinaryMachineTrap

pub struct BinaryMachineBytecodeInterpreter {
	stack_info_ &libjs.StackInfo
mut:
	trap_ BinaryMachineBytecodeTrapState = BinaryMachineEmptyTrap{}
}

pub fn BinaryMachineBytecodeInterpreter.create(stack_info &libjs.StackInfo) BinaryMachineBytecodeInterpreter {
	return BinaryMachineBytecodeInterpreter{ stack_info_: unsafe { stack_info } }
}

pub fn (interpreter &BinaryMachineBytecodeInterpreter) did_trap() bool {
	return interpreter.trap_ !is BinaryMachineEmptyTrap
}

pub fn (interpreter &BinaryMachineBytecodeInterpreter) trap() BinaryMachineTrap {
	if interpreter.trap_ is BinaryMachineTrap { return interpreter.trap_ }
	panic('Source VERIFY: BytecodeInterpreter trap alternative is absent')
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) clear_trap() {
	if interpreter.trap_ !is BinaryMachineEmptyTrap { interpreter.trap_ = BinaryMachineEmptyTrap{} }
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) visit_external_resources(host BinaryMachineHostVisitOps) {
	if mut interpreter.trap_ is BinaryMachineTrap {
		if mut interpreter.trap_.data is BinaryExternallyManagedTrap {
			host.visit_trap(mut interpreter.trap_.data)
		}
	}
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) set_trap_message(reason string) bool {
	interpreter.trap_ = BinaryMachineTrap.from_string(reason)
	return true
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) set_trap(trap BinaryMachineTrap) bool {
	interpreter.trap_ = trap
	return true
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) trap_if_not(value bool, reason string) bool {
	if !value {
		interpreter.trap_ = BinaryMachineTrap.from_string(reason)
		return true
	}
	return false
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) trap_if_insufficient_native_stack_space(minimum uint) bool {
	return interpreter.trap_if_not(interpreter.stack_info_.size_free() >= minimum, 'STACK-EXHAUSTION')
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) trap_if_insufficient_native_stack_space_default() bool {
	return interpreter.trap_if_insufficient_native_stack_space(2 * 1024 * 1024)
}
