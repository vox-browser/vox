module webassembly

fn test_binary_expression_patches_nested_control_positions_and_outer_terminator() {
	mut decoder := Decoder{ bytes: [u8(4), 0x40, 1, 5, 2, 0x40, 1, 0x0b, 0x0b, 0x0b, 0x41, 42] }
	expression := parse_binary_expression(mut decoder)!
	assert decoder.offset == 10
	assert expression.instructions.len == 8
	if_args := expression.instructions[0].arguments as BinaryStructuredArguments
	assert if_args.else_ip? == 3 && if_args.end_ip == 7
	block_args := expression.instructions[3].arguments as BinaryStructuredArguments
	assert block_args.else_ip == none && block_args.end_ip == 5
	assert expression.instructions[5].opcode == binary_op_structured_end
	assert expression.instructions[6].opcode == binary_op_structured_end
	assert expression.instructions[7].opcode == binary_op_synthetic_end_expression
	assert expression.instructions[7].arguments is BinaryNoArguments
	remaining := parse_binary_instruction(mut decoder)!
	assert (remaining.arguments as BinaryI32Constant).value == 42
}

fn test_binary_expression_preserves_try_table_targets_and_parser_validation_boundary() {
	mut decoder := Decoder{ bytes: [u8(0x1f), 0x40, 1, 2, 0, 1, 0x0b, 0x0b] }
	expression := parse_binary_expression(mut decoder)!
	args := expression.instructions[0].arguments as BinaryTryTableArguments
	assert args.end_ip == 2 && args.catches == [BinaryCatch{ label_index: 0 }]
	assert expression.instructions.last().opcode == binary_op_synthetic_end_expression
	// The pinned parser patches any StructuredInstructionArgs on else. Only
	// the later Validator decides whether its owning opcode was an if.
	mut block_decoder := Decoder{ bytes: [u8(2), 0x40, 5, 0x0b, 0x0b] }
	block := parse_binary_expression(mut block_decoder)!
	block_args := block.instructions[0].arguments as BinaryStructuredArguments
	assert block_args.else_ip? == 2 && block_args.end_ip == 3
}

fn test_binary_expression_rejects_eof_and_else_without_a_structured_owner() {
	for bytes in [[]u8{}, [u8(0x41), 1], [u8(2), 0x40, 0x0b], [u8(5), 0x0b],
		[u8(0x1f), 0x40, 0, 5, 0x0b, 0x0b]] {
		mut decoder := Decoder{ bytes: bytes }
		if _ := parse_binary_expression(mut decoder) { assert false } else { assert err.msg().len > 0 }
	}
}
