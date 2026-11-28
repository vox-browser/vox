module css

// The direct copy either declines or produces exactly what the general
// serializer would, including signs, escapes, quotes and trimmed whitespace.
fn test_direct_selector_prelude_matches_the_general_serializer() {
	sources := [
		'.card > .child', '  #main .item:hover  ', 'a[href^="https"]', 'li:nth-child(2n+1)',
		':is(.a, .b):not([hidden])', 'div::before', '.btn.-primary', 'input[type=text i]',
		'.a\\:b', '#\\31 23', '.é', "a[title='x']", 'a[title="a\\"b"]', '.a /**/ .b', '.a\n\t.b',
		'[data-x="a b"]', ':nth-of-type(-n+3)', '.x:has(> .y + .z)', '*|*', 'svg|a',
		'.\\-foo', '.-1', ':--custom', '.a{', '[a=1.50]', '.w-1\\/2', '', '   ',
	]
	mut copied := 0
	for source in sources {
		mut stream := ParserTokenStream.from_source(source, 'utf-8')
		mut parser := RuleSelectorParser{}
		for {
			parts := parser.consume_selector_component_span(mut stream)
			expected := parser_selector_prelude_to_string(parts).trim_space()
			if direct := direct_selector_prelude_text(parts) {
				assert direct == expected, source
				copied++
			}
			assert owned_selector_prelude_text(parts) == expected, source
			if !stream.has_next_token() { break }
			stream.discard_a_token()
		}
	}
	assert copied >= 20
}

// Escaped identifiers and strings that need escaping stay on the general path.
fn test_direct_selector_prelude_declines_text_that_needs_escaping() {
	for source in ['.a\\:b', '#\\31 23', 'a[title="a\\"b"]'] {
		stream := ParserTokenStream.from_source(source, 'utf-8')
		assert direct_selector_prelude_text(stream.values) == none, source
	}
	stream := ParserTokenStream.from_source(' li:nth-child(2n+1) ', 'utf-8')
	assert direct_selector_prelude_text(stream.values) or { '' } == 'li:nth-child(2n+1)'
}

// Names spelled without an escape are recognized from their source span, and
// non-ASCII names need no escape either.
fn test_unescaped_selector_names_serialize_from_their_spelling() {
	for source, expected in {
		'.é > #main':        '.é > #main'
		'a:not(.b)':         'a:not(.b)'
		'.\\61 b':           '.ab'
	} {
		stream := ParserTokenStream.from_source(source, 'utf-8')
		assert direct_selector_prelude_text(stream.values) or { 'declined' } == expected, source
	}
	stream := ParserTokenStream.from_source('.card:is(.x)', 'utf-8')
	for value in stream.values {
		if value.value is &Token && value.value.type_ == .ident {
			assert value.value.original_source_text_ == value.value.value
		} else if value.value is &Function {
			assert value.value.name_token.original_source_text_ == '${value.value.name}('
		}
	}
}
