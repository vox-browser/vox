// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/Types.h InstructionStorage; BytecodeInterpreter.cpp:6888–6909.
module webassembly

@[heap]
struct BinaryInstructionStorageChunk {
mut:
	slots []BinaryInstruction
}

pub struct BinaryInstructionStorage {
mut:
	chunks_                   []&BinaryInstructionStorageChunk
	size_                     uint
	capacity_                 uint
	next_index_in_last_chunk_ uint
}

pub fn (storage &BinaryInstructionStorage) size() uint { return storage.size_ }

pub fn (storage &BinaryInstructionStorage) capacity() uint { return storage.capacity_ }

pub fn (storage &BinaryInstructionStorage) is_empty() bool { return storage.size_ == 0 }

fn (mut storage BinaryInstructionStorage) add_chunk() {
	chunk_capacity := if storage.capacity_ < 8 {
		uint(8)
	} else if storage.capacity_ > 512 {
		uint(512)
	} else {
		storage.capacity_
	}
	storage.chunks_ << &BinaryInstructionStorageChunk{
		// Source SentinelOptional<Instruction> stores absence in the opcode.
		slots: []BinaryInstruction{len: int(chunk_capacity), init: BinaryInstruction{ opcode: max_u32 }}
	}
	storage.capacity_ += chunk_capacity
	storage.next_index_in_last_chunk_ = 0
}

pub fn (mut storage BinaryInstructionStorage) append(instruction BinaryInstruction) &BinaryInstruction {
	if storage.chunks_.len == 0
		|| storage.next_index_in_last_chunk_ == uint(storage.chunks_.last().slots.len) {
		storage.add_chunk()
	}
	mut chunk := storage.chunks_.last()
	index := int(storage.next_index_in_last_chunk_)
	storage.next_index_in_last_chunk_++
	chunk.slots[index] = instruction
	storage.size_++
	// Source returns slot.value(), which verifies the sentinel is absent.
	assert chunk.slots[index].opcode != max_u32
	return unsafe { &chunk.slots[index] }
}

// Source's defaulted move moves only the Vector header. Its scalar members
// are copied, so the moved-from object keeps those scalars with empty chunks.
pub fn BinaryInstructionStorage.move_construct(mut source BinaryInstructionStorage) BinaryInstructionStorage {
	result := BinaryInstructionStorage{
		chunks_:                   source.chunks_
		size_:                     source.size_
		capacity_:                 source.capacity_
		next_index_in_last_chunk_: source.next_index_in_last_chunk_
	}
	source.chunks_ = []&BinaryInstructionStorageChunk{}
	return result
}

pub fn (mut storage BinaryInstructionStorage) move_assign(mut source BinaryInstructionStorage) {
	storage = BinaryInstructionStorage.move_construct(mut source)
}
