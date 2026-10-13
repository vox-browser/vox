module css

fn test_large_component_text_preserves_values_original_source_and_eof() {
	text := 'token '.repeat(8192) + 'func([x] "+y")'
	mut parser := RuleSelectorParser.create(ParsingParams{}, text, 'utf-8')
	mut values := parser.parse_as_list_of_component_values()
	values << ComponentValue.from_token(Tokenizer.create_eof_token())
	assert parser_component_values_to_string(values) == text
	assert parser_component_values_original_text(values) == text
}

fn test_selector_component_text_preserves_nested_signs_and_decodes_escapes() {
	text := ':is(.a, [\\61=b]):nth-child(+2n+1)'
	mut parser := RuleSelectorParser.create(ParsingParams{}, text, 'utf-8')
	values := parser.parse_as_list_of_component_values()
	assert parser_selector_prelude_to_string(values) == ':is(.a, [a=b]):nth-child(+2n+1)'
	assert parser_component_values_original_text(values) == text
}
