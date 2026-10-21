module dom

import platform

fn test_ascii_name_validation_preserves_element_attribute_and_prefix_rules() {
	for name in ['span', 'custom-element', 'a=b', 'a:b', 'a"b', 'a\u000b', 'a日本語'] {
		assert is_valid_element_local_name(name), name
	}
	for name in ['', '0name', '-name', 'a b', 'a\t', 'a\n', 'a\r', 'a\u000c', 'a/b', 'a>b'] {
		assert !is_valid_element_local_name(name), name
	}
	for name in ['_日本語-1', ':name', '日本語', '😀', '_a:b.1'] {
		assert is_valid_element_local_name(name), name
	}
	for name in ['data-name', '0name', '日本語', 'a:b', 'a"b', 'a\u000b'] {
		assert is_valid_attribute_local_name(name), name
		assert is_valid_namespace_prefix(name), name
	}
	assert is_valid_namespace_prefix('a=b')
	assert !is_valid_attribute_local_name('a=b')
	for name in ['', 'a b', 'a\t', 'a\n', 'a\r', 'a\u000c', 'a/b', 'a>b'] {
		assert !is_valid_attribute_local_name(name), name
		assert !is_valid_namespace_prefix(name), name
	}
	assert !is_valid_element_local_name([u8(`a`), 0].bytestr())
}

fn test_name_validation_keeps_the_existing_non_ascii_decoder_behavior() {
	for byte in 0 .. 256 {
		for suffix in [[u8(byte)], [u8(0xc2), u8(byte)], [u8(0xed), 0xa0, u8(byte)]] {
			name := 'a' + suffix.bytestr()
			prefix_invalid := contains_any_code_point(name, [u32(9), 10, 12, 13, 32, 0, 47, 62])
			attribute_invalid := contains_any_code_point(name, [u32(9), 10, 12, 13, 32, 0, 47, 61, 62])
			assert is_valid_element_local_name(name) == !prefix_invalid
			assert is_valid_namespace_prefix(name) == !prefix_invalid
			assert is_valid_attribute_local_name(name) == !attribute_invalid
		}
	}
}

fn test_parser_ascii_name_checks_do_not_allocate_rune_or_delimiter_vectors() {
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		assert is_valid_element_local_name('span')
		assert is_valid_attribute_local_name('data-memory-check')
		assert is_valid_namespace_prefix('svg')
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
}
