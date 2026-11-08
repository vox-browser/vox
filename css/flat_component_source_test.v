module css

import strings

fn test_flat_component_source_matches_recursive_original_spelling() {
	for source in ['', '/*before*/ .esc\\31 , [title="β😀"]',
		'var(--x,calc(1/**/px + 2%)) [nested{more(x)}]', 'f([unterminated',
		'url(bad"url) "unterminated', 'a\\,b, :is(.a,.b)'] {
		values := ParserTokenStream.from_source(source, 'utf-8').values
		mut expected := strings.new_builder(source.len)
		mut actual := strings.new_builder(source.len)
		for index in 0 .. values.len {
			expected.write_string(values[index].original_source_text())
			append_component_original_text(mut actual, &values[index])
		}
		assert actual.str() == expected.str()
	}
	values := [ComponentValue.new('raw'), ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
	mut actual := strings.new_builder(3)
	for index in 0 .. values.len { append_component_original_text(mut actual, &values[index]) }
	assert actual.str() == 'raw'
}

fn test_selector_component_span_matches_ordinary_component_consumption() {
	for source in ['.a,.b', '.a:is(.b,.c), [title="a,b"]', '.a\\,b, .c', '}.a, .b', 'f([', ''] {
		mut parser := RuleSelectorParser{}
		mut expected := ParserTokenStream.from_source(source, 'utf-8')
		mut actual := ParserTokenStream.from_values(expected.values)
		for {
			one := parser.consume_a_list_of_component_values(mut expected, .comma, .no)
			two := parser.consume_selector_component_span(mut actual)
			assert expected.index == actual.index
			assert parser_component_values_original_text(one) == parser_component_values_original_text(two)
			if !expected.has_next_token() { break }
			expected.discard_a_token()
			actual.discard_a_token()
		}
	}
}
