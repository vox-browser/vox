module webassembly

import math

fn decode_one_binary_instruction(bytes []u8) !BinaryInstruction {
	mut decoder := Decoder{
		bytes: bytes
	}
	instruction := parse_binary_instruction(mut decoder)!
	if decoder.offset != bytes.len { return error('unconsumed test instruction bytes') }
	return instruction
}

fn test_instruction_decode_retains_control_operands_and_all_catch_forms() {
	for row in [[u8(2), 0x40], [u8(3), 0x7f], [u8(4), 0x80, 1],
		[u8(2), 0x64, 0x6f]] {
		instruction := decode_one_binary_instruction(row)!
		args := instruction.arguments as BinaryStructuredArguments
		if row[1] == 0x40 { assert args.block_type.kind == .empty_
		 }
		if row[1] == 0x7f { assert args.block_type.value_type.kind == .i32
		 }
		if row[1] == 0x80 { assert args.block_type.type_index == 128
		 }
		if row[1] == 0x64 { assert !args.block_type.value_type.nullable
		 }
		assert args.end_ip == 0 && args.else_ip == none
	}
	try_table := decode_one_binary_instruction([u8(0x1f), 0x40, 4, 0, 9, 1, 1, 10, 2, 2, 3, 3,
		4])!
	try_args := try_table.arguments as BinaryTryTableArguments
	assert try_args.catches == [BinaryCatch{ tag_index: 9, label_index: 1 },
		BinaryCatch{ capture_reference: true, tag_index: 10, label_index: 2 },
		BinaryCatch{ label_index: 3 }, BinaryCatch{ capture_reference: true, label_index: 4 }]
	branch_table := decode_one_binary_instruction([u8(0x0e), 2, 1, 0x80, 1, 3])!
	assert (branch_table.arguments as BinaryTableBranchArguments).labels == [u32(1), 128]
	assert (branch_table.arguments as BinaryTableBranchArguments).default_label == 3
	indirect := decode_one_binary_instruction([u8(0x13), 2, 0x80, 1])!
	assert (indirect.arguments as BinaryIndirectCallArguments) == BinaryIndirectCallArguments{
		type_index:  2
		table_index: 128
	}
	for opcode in [u8(0x20), 0x21, 0x22] {
		local := decode_one_binary_instruction([opcode, 0x80, 1])!
		assert local.local_index == 128 && local.arguments is BinaryNoArguments
	}
	typed_select := decode_one_binary_instruction([u8(0x1c), 2, 0x7f, 0x64, 0x6f])!
	assert (typed_select.arguments as BinaryValueTypeVector).types.len == 2
}

fn test_instruction_decode_preserves_integer_extremes_float_bits_and_source_leb_ranges() {
	min32 := decode_one_binary_instruction([u8(0x41), 0x80, 0x80, 0x80, 0x80, 0x78])!
	max32 := decode_one_binary_instruction([u8(0x41), 0xff, 0xff, 0xff, 0xff, 7])!
	assert (min32.arguments as BinaryI32Constant).value == i32(-2147483648)
	assert (max32.arguments as BinaryI32Constant).value == i32(2147483647)
	min64 := decode_one_binary_instruction([u8(0x42), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
		0x80, 0x80, 0x7f])!
	max64 := decode_one_binary_instruction([u8(0x42), 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		0xff, 0xff, 0])!
	assert (min64.arguments as BinaryI64Constant).value == i64(-9223372036854775807) - 1
	assert (max64.arguments as BinaryI64Constant).value == i64(9223372036854775807)
	negative_zero := decode_one_binary_instruction([u8(0x43), 0, 0, 0, 0x80])!
	assert math.f32_bits((negative_zero.arguments as BinaryF32Constant).value) == u32(0x80000000)
	nan := decode_one_binary_instruction([u8(0x44), 0x23, 1, 0, 0, 0, 0, 0xf8, 0x7f])!
	assert math.f64_bits((nan.arguments as BinaryF64Constant).value) == u64(0x7ff8000000000123)
	// Signed padded encodings remain accepted when their unused sign bits match.
	padded := decode_one_binary_instruction([u8(0x41), 0xff, 0x7f])!
	assert (padded.arguments as BinaryI32Constant).value == -1
}

fn test_instruction_decode_retains_multi_memory_bulk_and_gc_immediates() {
	load := decode_one_binary_instruction([u8(0x28), 0x42, 3, 0x80, 0x80, 0x80, 0x80, 0x10])!
	assert (load.arguments as BinaryMemoryArgument) == BinaryMemoryArgument{
		align:        2
		memory_index: 3
		offset:       u64(1) << 32
	}
	copy := decode_one_binary_instruction([u8(0xfc), 10, 2, 7])!
	assert (copy.arguments as BinaryMemoryCopyArguments) == BinaryMemoryCopyArguments{
		src_index: 7
		dst_index: 2
	}
	init := decode_one_binary_instruction([u8(0xfc), 8, 9, 4])!
	assert (init.arguments as BinaryMemoryInitArguments) == BinaryMemoryInitArguments{
		data_index:   9
		memory_index: 4
	}
	table := decode_one_binary_instruction([u8(0xfc), 12, 6, 8])!
	assert (table.arguments as BinaryTableElementArguments) == BinaryTableElementArguments{
		element_index: 6
		table_index:   8
	}
	field := decode_one_binary_instruction([u8(0xfb), 3, 2, 7])!
	assert (field.arguments as BinaryStructFieldArguments) == BinaryStructFieldArguments{
		type_index:  2
		field_index: 7
	}
	array := decode_one_binary_instruction([u8(0xfb), 17, 3, 9])!
	assert (array.arguments as BinaryArrayCopyArguments) == BinaryArrayCopyArguments{
		destination_type_index: 3
		source_type_index:      9
	}
	for selector in [u8(20), 21, 22, 23] {
		cast := decode_one_binary_instruction([u8(0xfb), selector, 0])!
		type_ := cast.arguments as BinaryValueType
		assert type_.kind == .type_use_reference && type_.type_index == 0
		assert type_.nullable == (selector in [u8(21), 23])
	}
	for flags in [u8(0), 1, 2, 3] {
		cast := decode_one_binary_instruction([u8(0xfb), 24, flags, 8, 0x6f, 0])!
		args := cast.arguments as BinaryBranchCastArguments
		assert args.branch.label == 8 && args.source_type.kind == .extern_reference
		assert args.source_type.nullable == (flags & 1 != 0)
		assert args.target_type.kind == .type_use_reference && args.target_type.type_index == 0
		assert args.target_type.nullable == (flags & 2 != 0)
	}
}

fn test_instruction_decode_preserves_simd_literals_and_leaves_lane_validation_to_validator() {
	mut vector_bytes := [u8(0xfd), 12]
	for i in 0 .. 16 {
		vector_bytes << u8(i * 17)
	}
	vector := decode_one_binary_instruction(vector_bytes)!
	assert (vector.arguments as BinaryVectorConstant).bytes[15] == 255
	vector_bytes[1] = 13
	shuffle := decode_one_binary_instruction(vector_bytes)!
	assert (shuffle.arguments as BinaryShuffleArgument).lanes[7] == 119
	lane := decode_one_binary_instruction([u8(0xfd), 84, 0x41, 7, 9, 255])!
	assert (lane.arguments as BinaryMemoryLaneArgument) == BinaryMemoryLaneArgument{
		memory: BinaryMemoryArgument{
			align:        1
			memory_index: 7
			offset:       9
		}
		lane:   255
	}
	for bytes in [[u8(0x6a)], [u8(0x7e)], [u8(0xfc), 0], [u8(0xfb), 15],
		[u8(0xfd), 0x80, 2]] {
		assert decode_one_binary_instruction(bytes)!.arguments is BinaryNoArguments
	}
}

fn test_instruction_decode_rejects_unknown_and_truncated_operands() {
	for bytes in [[]u8{}, [u8(6)], [u8(0xfe)], [u8(0xfc), 0xff, 0xff, 0xff, 8],
		[u8(0xfd), 0xff, 3], [u8(0x41), 0x80], [u8(0x41), 0x80, 0x80, 0x80, 0x80, 8],
		[u8(0x42), 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 1],
		[u8(0x44), 0], [u8(0x0e), 1, 0], [u8(0xfb), 24, 4], [u8(0x1f), 0x40, 1, 4],
		[u8(0xfd), 12, 0], [u8(0xfd), 84, 0, 0], [u8(2), 0x7f, 0]] {
		if _ := decode_one_binary_instruction(bytes) {
			assert false, 'accepted invalid instruction ${bytes}'
		} else {
			assert err.msg().len > 0
		}
	}
}
