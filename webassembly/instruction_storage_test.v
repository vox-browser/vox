// SPDX-License-Identifier: BSD-2-Clause
module webassembly

fn test_source_instruction_storage_chunk_growth_caps_at_512_and_retains_every_borrowed_slot() {
	mut storage := BinaryInstructionStorage{}
	assert storage.size() == 0 && storage.capacity() == 0 && storage.is_empty()
	mut references := []&BinaryInstruction{}
	for index in 0 .. 1537 {
		instruction := BinaryInstruction{ opcode: binary_op_i32_const, arguments: BinaryI32Constant{ value: i32(index) } }
		actual := storage.append(instruction)
		references << actual
		assert storage.size() == uint(index + 1) && !storage.is_empty()
		if index == 0 {
			assert storage.capacity() == 8
		}
		if index == 8 {
			assert storage.capacity() == 16
		}
		if index == 16 {
			assert storage.capacity() == 32
		}
		if index == 512 {
			assert storage.capacity() == 1024
		}
		if index == 1024 {
			assert storage.capacity() == 1536
		}
		if index == 1536 {
			assert storage.capacity() == 2048
		}
	}
	assert storage.chunks_.map(it.slots.len) == [8, 8, 16, 32, 64, 128, 256, 512, 512, 512]
	for index, actual in references {
		assert actual.opcode == binary_op_i32_const
		arguments := actual.arguments
		assert arguments is BinaryI32Constant
		if arguments is BinaryI32Constant {
			assert arguments.value == i32(index)
		}
	}
	mut first := references[0]
	first.arguments = BinaryI32Constant{ value: -77 }
	assert storage.chunks_[0].slots[0].arguments == BinaryInstructionArguments(BinaryI32Constant{ value: -77 })
	// Unoccupied optional slots use the exact source UINT32_MAX opcode sentinel.
	assert storage.chunks_.last().slots[1].opcode == max_u32
}

fn test_source_instruction_storage_move_keeps_actual_slots_and_copies_scalar_state() {
	mut original := BinaryInstructionStorage{}
	first := original.append(BinaryInstruction{ opcode: binary_op_nop })
	mut moved := BinaryInstructionStorage.move_construct(mut original)
	assert moved.size() == 1 && moved.capacity() == 8
	assert voidptr(&moved.chunks_[0].slots[0]) == voidptr(first)
	assert original.chunks_.len == 0 && original.size() == 1 && original.capacity() == 8
	assert original.next_index_in_last_chunk_ == 1
	second := moved.append(BinaryInstruction{ opcode: binary_op_drop })
	mut assigned := BinaryInstructionStorage{}
	_ = assigned.append(BinaryInstruction{ opcode: binary_op_unreachable })
	assigned.move_assign(mut moved)
	assert assigned.size() == 2 && assigned.capacity() == 8
	assert voidptr(&assigned.chunks_[0].slots[0]) == voidptr(first)
	assert voidptr(&assigned.chunks_[0].slots[1]) == voidptr(second)
	assert moved.chunks_.len == 0 && moved.size() == 2 && moved.capacity() == 8
}
