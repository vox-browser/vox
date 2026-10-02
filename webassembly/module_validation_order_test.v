module webassembly

fn validation_order_append_section(mut bytes []u8, id u8, payload []u8) {
	bytes << [id, u8(payload.len)]
	bytes << payload
}

fn validation_order_header() []u8 { return [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0] }

fn test_function_count_is_checked_after_import_context_but_before_import_type_validation() {
	mut bytes := validation_order_header()
	validation_order_append_section(mut bytes, 1, [u8(1), 0x60, 0, 0])
	validation_order_append_section(mut bytes, 2, [u8(1), 0, 0, 2, 0, 0x81, 0x80, 4])
	validation_order_append_section(mut bytes, 3, [u8(1), 0])
	if _ := compile_module(bytes) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid FunctionSection'
	}
	mut bad_index := validation_order_header()
	validation_order_append_section(mut bad_index, 2, [u8(1), 0, 0, 0, 0])
	validation_order_append_section(mut bad_index, 3, [u8(1), 0])
	if _ := compile_module(bad_index) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid TypeIndex'
	}
}

fn test_active_data_validation_precedes_defined_global_and_memory_checks() {
	mut bytes := validation_order_header()
	validation_order_append_section(mut bytes, 5, [u8(1), 0, 0x81, 0x80, 4])
	validation_order_append_section(mut bytes, 6, [u8(1), 0x63, 0, 0, 0xd0, 0x70, 0x0b])
	validation_order_append_section(mut bytes, 11, [u8(1), 2, 1, 0x41, 0, 0x0b, 0])
	if _ := compile_module(bytes) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid MemoryIndex'
	}
	mut bad_count := validation_order_header()
	validation_order_append_section(mut bad_count, 6, [u8(1), 0x63, 0, 0, 0xd0, 0x70, 0x0b])
	validation_order_append_section(mut bad_count, 12, [u8(1)])
	if _ := compile_module(bad_count) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid data count does not match segment count'
	}
}

fn test_function_expression_validation_precedes_defined_tag_type_checks() {
	mut bytes := validation_order_header()
	validation_order_append_section(mut bytes, 1, [u8(1), 0x60, 0, 1, 0x7f])
	validation_order_append_section(mut bytes, 3, [u8(1), 0])
	validation_order_append_section(mut bytes, 13, [u8(1), 0, 1])
	validation_order_append_section(mut bytes, 10, [u8(1), 2, 0, 0x0b])
	if _ := compile_module(bytes) {
		assert false
	} else {
		assert err.msg().contains('expected <any> but got <nothing>')
	}
}
