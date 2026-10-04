// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp::branch_to_label<NeedsStackAdjustment>.
module webassembly

// The boolean retains Source's template selection. The opcode caller owns
// verifier-valid label indices and the subsequent instruction-pointer advance.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) branch_to_label(mut configuration BinaryMachineConfiguration, needs_stack_adjustment bool, index u32, current_ip u32, actually_branching bool) u32 {
	configuration.label_stack_.trim(if actually_branching {
		configuration.label_stack_.len - int(index)
	} else {
		configuration.label_stack_.len
	})
	label := configuration.label_stack_[configuration.label_stack_.len - 1]
	if needs_stack_adjustment && actually_branching {
		configuration.value_stack_.remove(label.stack_height(), configuration.value_stack_.size() - label.stack_height() - label.arity())
	}
	return if actually_branching { label.continuation() - 1 } else { current_ip }
}
