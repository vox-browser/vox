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

fn test_expression_identifier_names_own_their_utf16_spelling() {
	mut parser := Parser.new(utf16(r'\u0063afé?.\u0061.𐐀; plain.\u0062; async;'), .script)
	program := parser.parse_program(false)
	parser.scope_collector.analyze(false)
	assert !parser.has_errors()
	assert !parser.scope_collector.has_errors()
	data := program.kind.program_data or { panic('Missing program') }
	assert data.scope.children.len == 3

	for index in 0 .. parser.source.len {
		parser.source[index] = 0
	}
	chain_expr := data.scope.children[0].kind.expression or { panic('Missing chain') }
	chain := chain_expr.kind.optional_chain_data() or { panic('Missing chain data') }
	base := chain.base.kind.identifier or { panic('Missing chain base') }
	assert base.name.str() == 'café'
	assert base.is_global
	assert chain.references.len == 2
	first := chain.references[0]
	last := chain.references[1]
	if first is OptionalChainMemberRef {
		assert first.identifier.name.str() == 'a'
	} else {
		panic('Missing optional member')
	}
	if last is OptionalChainMemberRef {
		assert last.identifier.name.str() == '𐐀'
	} else {
		panic('Missing regular member')
	}
	member := data.scope.children[1].kind.expression or { panic('Missing member expression') }
	property := member.kind.property or { panic('Missing member name') }
	name := property.kind.identifier or { panic('Missing property identifier') }
	assert name.name.str() == 'b'
	async_expr := data.scope.children[2].kind.expression or { panic('Missing async expression') }
	async_id := async_expr.kind.identifier or { panic('Missing async identifier') }
	assert async_id.name.str() == 'async'
}

fn test_literals_own_their_decoded_utf16() {
	source := r'"café𐐀"; "prefix\uD800\n";' + ' `first\r\nsecond`; ' +
		r'tag`raw\n𐐀`; tag`bad\u{no}`;'
	mut parser := Parser.new(utf16(source), .script)
	program := parser.parse_program(false)
	assert !parser.has_errors()
	data := program.kind.program_data or { panic('Missing program') }
	assert data.scope.children.len == 5
	for index in 0 .. parser.source.len {
		parser.source[index] = 0
	}

	plain := data.scope.children[0].kind.expression or { panic('Missing string') }
	assert plain.kind.literal_string().str() == 'café𐐀'
	escaped := data.scope.children[1].kind.expression or { panic('Missing escaped string') }
	assert escaped.kind.literal_string().data[..6] == utf16('prefix')
	assert escaped.kind.literal_string().data[6..] == [u16(0xD800), 10]

	template := data.scope.children[2].kind.expression or { panic('Missing template') }
	template_data := template.kind.template_data() or { panic('Missing template data') }
	assert template_data.expressions[0].kind.literal_string().str() == 'first\nsecond'

	tagged := data.scope.children[3].kind.expression or { panic('Missing tagged template') }
	tagged_template := tagged.kind.template_literal_expr() or { panic('Missing template') }
	tagged_data := tagged_template.kind.template_data() or { panic('Missing template data') }
	assert tagged_data.raw_strings[0].str() == r'raw\n𐐀'
	assert tagged_data.expressions[0].kind.literal_string().str() == 'raw\n𐐀'

	invalid := data.scope.children[4].kind.expression or { panic('Missing tagged template') }
	invalid_template := invalid.kind.template_literal_expr() or { panic('Missing template') }
	invalid_data := invalid_template.kind.template_data() or { panic('Missing template data') }
	assert invalid_data.raw_strings[0].str() == r'bad\u{no}'
	assert invalid_data.expressions[0].kind.tag == .null_literal
}
