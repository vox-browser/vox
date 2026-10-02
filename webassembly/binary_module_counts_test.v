module webassembly

import webidl

fn module_count_binary(sections []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0]
	bytes << sections
	return bytes
}

fn test_module_counts_defined_functions_match_bodies_without_counting_imports() {
	for sections in [[u8(3), 1, 0], [u8(10), 1, 0],
		[u8(1), 4, 1, 0x60, 0, 0, 3, 2, 1, 0, 10, 4, 1, 2, 0, 0x0b],
		[u8(1), 4, 1, 0x60, 0, 0, 2, 5, 1, 0, 0, 0, 0],
		[u8(1), 4, 1, 0x60, 0, 0, 2, 5, 1, 0, 0, 0, 0, 3, 2, 1, 0, 10, 4, 1, 2, 0, 0x0b]] {
		assert validate(webidl.BufferSource.array_buffer(module_count_binary(sections)))
	}
	for sections in [[u8(3), 2, 1, 0], [u8(10), 4, 1, 2, 0, 0x0b],
		[u8(3), 3, 2, 0, 0, 10, 4, 1, 2, 0, 0x0b]] {
		if _ := compile_module(module_count_binary(sections)) {
			assert false
		} else {
			assert err.msg() == 'CompileError: invalid FunctionSection'
		}
	}
}

fn test_module_data_count_matches_actual_segments_when_present() {
	for sections in [[u8(12), 1, 0], [u8(11), 5, 2, 1, 0, 1, 0], [u8(12), 1, 2, 11, 5, 2, 1, 0,
		1, 0]] {
		assert validate(webidl.BufferSource.array_buffer(module_count_binary(sections)))
	}
	for sections in [[u8(12), 1, 1], [u8(12), 1, 0, 11, 3, 1, 1, 0],
		[u8(12), 1, 1, 11, 5, 2, 1, 0, 1, 0]] {
		if _ := compile_module(module_count_binary(sections)) {
			assert false
		} else {
			assert err.msg() == 'CompileError: invalid data count does not match segment count'
		}
	}
}
