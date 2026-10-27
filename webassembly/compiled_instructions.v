// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/Types.h: Dispatch, SourcesAndDestination, CraneliftTrap,
// CompiledInstructions. These are source compilation records, not an executor.
module webassembly

pub enum BinaryRegisterOrStack as u8 {
	r0
	r1
	r2
	r3
	r4
	r5
	r6
	r7
	stack            = 8
	call_record
	last_call_record = 255
}

// Source CountRegisters and Stack have the same value.
pub const binary_count_registers = BinaryRegisterOrStack.stack

pub union BinaryDispatchPayload {
pub mut:
	instruction_opcode u32
	handler_ptr        uint
}

pub struct BinaryDispatch {
pub mut:
	payload     BinaryDispatchPayload
	instruction &BinaryInstruction = unsafe { nil }
}

pub struct BinarySourcesAndDestinationFields {
pub mut:
	sources     [3]BinaryRegisterOrStack
	destination BinaryRegisterOrStack
}

pub union BinarySourcesAndDestination {
pub mut:
	operands                BinarySourcesAndDestinationFields
	sources_and_destination u32
}

pub struct BinaryCraneliftTrap {
pub mut:
	offset  u32
	code    u8
	padding [3]u8
}

pub struct BinaryCompiledInstructions {
pub mut:
	dispatches                []BinaryDispatch
	src_dst_mappings          []BinarySourcesAndDestination
	extra_instruction_storage BinaryInstructionStorage
	cranelift_local_types     []u8
	cranelift_entry           uint
	cranelift_code_handle     voidptr = unsafe { nil }
	cranelift_code_size       uint
	cranelift_traps           &BinaryCraneliftTrap = unsafe { nil }
	cranelift_trap_count      uint
	max_call_arg_count        uint
	max_call_rec_size         uint
	cranelift_result_arity    u32
	cranelift_local_count     u32
	cranelift_param_count     u32
	cranelift_inlined_locals  u32
	max_label_depth           u32
	direct                    bool
	cranelift_eligible        bool
	has_tier_up_checkpoints   bool
	cranelift_compiled        bool
}
