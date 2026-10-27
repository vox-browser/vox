// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.h: Label and Frame.
module webassembly

pub struct BinaryMachineLabel {
	arity_                 uint
	stack_height_          uint
	continuation_          u32
	try_table_instruction_ &BinaryInstruction = unsafe { nil }
}

pub fn BinaryMachineLabel.create(arity uint, continuation u32, stack_height uint, try_table_instruction &BinaryInstruction) BinaryMachineLabel {
	return BinaryMachineLabel{
		arity_:                 arity
		stack_height_:          stack_height
		continuation_:          continuation
		try_table_instruction_: unsafe { try_table_instruction }
	}
}

pub fn (label &BinaryMachineLabel) continuation() u32 { return label.continuation_ }

pub fn (label &BinaryMachineLabel) arity() uint { return label.arity_ }

pub fn (label &BinaryMachineLabel) stack_height() uint { return label.stack_height_ }

pub fn (label &BinaryMachineLabel) try_table_instruction() &BinaryInstruction {
	return label.try_table_instruction_
}

// Frame retains a pointer to the source Vector header. V cannot return a
// pointer to an array header, so this owner keeps the actual mutable vector.
@[heap]
pub struct BinaryMachineCompiledFunctionTable {
pub mut:
	entries []BinaryMachineCompiledFunctionEntry
}

pub struct BinaryMachineFrame {
	module_      &BinaryMachineModuleInstance
	locals_ptr_  &BinaryMachineValue = unsafe { nil }
	expression_  &BinaryExpression
	arity_       uint
	owns_locals_ bool
mut:
	label_index_       uint
	compiled_fn_table_ &BinaryMachineCompiledFunctionTable = unsafe { nil }
}

pub fn BinaryMachineFrame.create(module_ &BinaryMachineModuleInstance, locals_ptr &BinaryMachineValue, expression &BinaryExpression, arity uint, owns_locals bool) BinaryMachineFrame {
	return BinaryMachineFrame{
		module_:      module_
		locals_ptr_:  unsafe { locals_ptr }
		expression_:  unsafe { expression }
		arity_:       arity
		owns_locals_: owns_locals
	}
}

// The source move constructor copies these borrowed references and scalars;
// it does not clear the source frame or move/free the locals allocation.
pub fn BinaryMachineFrame.move_construct(other &BinaryMachineFrame) BinaryMachineFrame {
	return BinaryMachineFrame{
		module_:            other.module_
		locals_ptr_:        other.locals_ptr_
		expression_:        other.expression_
		arity_:             other.arity_
		owns_locals_:       other.owns_locals_
		label_index_:       other.label_index_
		compiled_fn_table_: other.compiled_fn_table_
	}
}

pub fn (frame &BinaryMachineFrame) module() &BinaryMachineModuleInstance { return frame.module_ }

pub fn (frame &BinaryMachineFrame) locals_data() &BinaryMachineValue { return frame.locals_ptr_ }

pub fn (frame &BinaryMachineFrame) owns_locals() bool { return frame.owns_locals_ }

pub fn (frame &BinaryMachineFrame) expression() &BinaryExpression { return frame.expression_ }

pub fn (frame &BinaryMachineFrame) arity() uint { return frame.arity_ }

pub fn (frame &BinaryMachineFrame) label_index() uint { return frame.label_index_ }

pub fn (mut frame BinaryMachineFrame) set_label_index(index uint) { frame.label_index_ = index }

pub fn (frame &BinaryMachineFrame) compiled_fn_table() &BinaryMachineCompiledFunctionTable {
	return frame.compiled_fn_table_
}

pub fn (mut frame BinaryMachineFrame) set_compiled_fn_table(table &BinaryMachineCompiledFunctionTable) {
	frame.compiled_fn_table_ = table
}
