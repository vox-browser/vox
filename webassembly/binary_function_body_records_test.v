module webassembly

fn test_source_function_constructor_caches_local_count_with_native_size_width() {
	function := BinaryFunctionBody.create(19, [
		BinaryLocals{ count: ~u32(0), type_: BinaryValueType{ kind: .i32 } },
		BinaryLocals{ count: 0, type_: BinaryValueType{ kind: .f64 } },
		BinaryLocals{ count: 2, type_: BinaryValueType{ kind: .i64 } },
	], BinaryExpression{})
	assert function.declared_size == 19
	assert function.total_local_count() == uint(~u32(0)) + 2
	assert function.locals.len == 3
	assert BinaryFunctionBody.create(0, [], BinaryExpression{}).total_local_count() == 0
}

fn test_source_parsed_function_retains_cached_total_and_actual_body() {
	mut decoder := Decoder{ bytes: [u8(1), 8, 3, 2, 0x7f, 0, 0x7c, 4, 0x7e, 0x0b] }
	functions := parse_code_section(mut decoder)!
	assert functions.len == 1
	assert functions[0].declared_size == 8
	assert functions[0].total_local_count() == 6
	assert functions[0].locals.len == 3
	assert functions[0].body.instructions.last().opcode == binary_op_synthetic_end_expression
}
