// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp::unwind_to_throw_handler.
module webassembly

// The caller owns throwing/re-dispatch and frame removal. This Source helper
// mutates only the current frame's labels and the actual operand stack.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) unwind_to_throw_handler(mut configuration BinaryMachineConfiguration, exception_address u64) ?u32 {
	exception := configuration.store().get_exception(exception_address) or {
		panic('Source exception address must name a stored exception')
	}
	frame_label_index := configuration.frame().label_index()
	mut label_index := uint(configuration.label_stack_.len)
	for label_index > frame_label_index + 1 {
		label_index--
		label := configuration.label_stack_[int(label_index)]
		try_table_instruction := label.try_table_instruction()
		if try_table_instruction == unsafe { nil } {
			continue
		}
		args := try_table_instruction.arguments as BinaryTryTableArguments
		for catch_ in args.catches {
			if tag_index := catch_.tag_index {
				if configuration.frame().module().tags()[int(tag_index)] != exception.tag() {
					continue
				}
			}
			configuration.value_stack_.shrink(label.stack_height(), true)
			if catch_.tag_index != none {
				configuration.value_stack_.ensure_capacity(configuration.value_stack_.size() + uint(exception.params().len))
				for field in exception.params() {
					configuration.value_stack_.unchecked_append(field)
				}
			}
			if catch_.capture_reference {
				configuration.value_stack_.append(BinaryMachineValue.from_reference(BinaryExceptionReference{ address: exception_address }))
			}
			configuration.label_stack_.trim(int(label_index))
			configuration.label_stack_.trim(configuration.label_stack_.len - int(catch_.label_index))
			target := configuration.label_stack_[configuration.label_stack_.len - 1]
			configuration.value_stack_.remove(target.stack_height(), configuration.value_stack_.size() - target.stack_height() - target.arity())
			return target.continuation()
		}
	}
	configuration.label_stack_.trim(int(frame_label_index))
	return none
}
