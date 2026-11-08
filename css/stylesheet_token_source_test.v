module css

import dom

fn assert_stylesheet_components_equal(left ComponentValue, right ComponentValue) {
	assert left.attr_tainted == right.attr_tainted
	match left.value {
		&Token { assert left.token() == right.token() }
		&SimpleBlock {
			assert right.is_block()
			one := left.block()
			two := right.block()
			assert one.token == two.token
			assert one.end_token == two.end_token
			assert one.value.len == two.value.len
			for index, value in one.value { assert_stylesheet_components_equal(value, two.value[index]) }
		}
		&Function {
			assert right.is_function()
			one := left.function()
			two := right.function()
			assert one.name == two.name
			assert one.name_token == two.name_token
			assert one.end_token == two.end_token
			assert one.value.len == two.value.len
			for index, value in one.value { assert_stylesheet_components_equal(value, two.value[index]) }
		}
		else { assert false, 'unexpected tokenizer payload' }
	}
}

fn test_stylesheet_direct_token_source_matches_array_tokenization_recursively() {
	inputs := ['', 'a{color:red}', '/*before*/\r\nβ\\31 { --x: f(a,[b],{c});content:"中😀" }',
		'@namespace svg url("urn:svg"); @media (width > 1px) {svg|a { width: calc(1px + 2%) }}',
		'a{content:"unterminated', 'a{ x:f([', 'a{ x:f()', 'f([a]) ] } )',
		'<!--a{color:red!important}-->', 'a{ x:url(bad"url);y:url(a\\ b);z:1e+2px }',
		'/*comment*/', 'a\u0000{--x:\r\nb}']
	for input in inputs {
		for encoding in ['utf-8', 'windows-1252'] {
			expected := ParserTokenStream.from_tokens(Tokenizer.tokenize(input, encoding))
			actual := ParserTokenStream.from_source(input, encoding)
			assert actual.values.len == expected.values.len
			for index, value in expected.values { assert_stylesheet_components_equal(value, actual.values[index]) }
		}
	}
}

fn test_stylesheet_direct_source_preserves_context_deferred_declarations_and_cssom_ownership() {
	mut document := dom.Document.create(dom.URL{value: 'https://stylesheet-source.test/base/'})
	defer { document.finalize() }
	text := '@namespace s url("urn:s"); @layer base {s|a {--x:calc(1px + var(--y)); color:red!important; background:url(../image.png)}} @supports(display:grid){div{display:grid}}'
	for deferred in [false, true] {
		params := ParsingParams{document: document, mode: .svg_presentation_attribute}
		mut expected_parser := RuleSelectorParser.create(params, text, 'utf-8')
		expected_parser.defer_style_declarations = deferred
		mut actual_parser := RuleSelectorParser.create_for_stylesheet(params, text)
		actual_parser.defer_style_declarations = deferred
		assert actual_parser.tokens.len == 0
		expected := expected_parser.parse_as_css_stylesheet('https://stylesheet-source.test/style.css', none)
		mut actual := actual_parser.parse_as_css_stylesheet('https://stylesheet-source.test/style.css', none)
		assert actual.css_rules().length() == expected.css_rules().length()
		for index, rule in actual.css_rules().rules {
			assert rule.css_text() == expected.css_rules().rules[index].css_text()
			assert rule.parent_style_sheet? == actual
		}
		actual.insert_rule('p { color:blue }', u32(actual.rules.length()))!
		assert actual.rules.length() == expected.rules.length() + 1
	}
}

@[noinline]
fn stylesheet_owned_components() ParserTokenStream {
	return ParserTokenStream.from_source(('/*prefix*/'.repeat(1024)) + 'a{content:"β😀";--x:f([tail])}', 'utf-8')
}

fn test_stylesheet_component_spelling_outlives_released_tokenizer_storage() {
	stream := stylesheet_owned_components()
	gc_collect()
	assert stream.dump_string().trim_space() == 'a{content:"β😀";--x:f([tail])}'
	assert stream.values.any(it.is_ident('a'))
}
