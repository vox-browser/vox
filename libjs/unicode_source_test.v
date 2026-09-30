module libjs

fn test_utf16_source_conversion_preserves_non_ascii_and_supplementary_characters() {
	assert utf16('é𐐀\x00') == [u16(0xE9), 0xD801, 0xDC00, 0]
	assert Utf16String.from_slice([u16(0xE9), 0xD801, 0xDC00, 0]).str() == 'é𐐀\x00'
	assert string_from_utf16_lossy([u16(0xD800), 0x61, 0xDC00]) == '�a�'
	assert Utf16String.from_slice([u16(0xD800)]).str() != Utf16String.from_slice([u16(0xD801)]).str()
}

fn test_unicode_bindings_and_labels_keep_distinct_identity() {
	for source in ['let α = 1; let β = 2;', 'function f(α, β = 1) {}',
		'α: { β: ; }', 'const 𐐀 = 1;', 'const ゛ = 1;', 'let a\u0301 = 1;'] {
		mut parser := Parser.new(utf16(source), .script)
		parser.parse_program(false)
		parser.scope_collector.analyze(false)
		assert !parser.has_errors(), '${source}: ${parser.errors}'
		assert !parser.scope_collector.has_errors(), source
	}
	mut parser := Parser.new(utf16('function f(α, α = 1) {}'), .script)
	parser.parse_program(false)
	assert parser.errors.any(it.message.contains('Duplicate parameter'))
}

fn test_identifier_properties_reject_punctuation_inside_former_letter_ranges() {
	for code_point in [u32(0x037E), 0x060C, 0x0903, 0x1F600] {
		assert !is_identifier_start_cp(code_point)
	}
	for code_point in [u32(0x2118), 0x212E, 0x309B, 0x309C, 0x10400] {
		assert is_identifier_start_cp(code_point)
	}
	assert !is_identifier_start_cp(0x0301)
	assert is_identifier_continue_cp(0x0301)
	assert is_identifier_continue_cp(0x200C)
	assert is_identifier_continue_cp(0x200D)
}
