module css

fn declaration_span_lookahead_oracle(input ParserTokenStream, nested ParserNested) int {
	mut stream := input
	for !stream.next_token().is(.end_of_file) && !stream.next_token().is(.semicolon)
		&& !(nested == .yes && stream.next_token().is(.close_curly)) {
		stream.discard_a_token()
	}
	return stream.index
}

fn test_declaration_span_scan_matches_lookahead_at_every_boundary() {
	for source in ['red;tail', '1px fn(2;3) [a;b]; tail', 'a } b; c',
		'var(--x, "日本語;}")', ''] {
		values := parse_component_values_for_value_logic(source)
		for index in 0 .. values.len + 2 {
			for nested in [ParserNested.no, .yes] {
				stream := ParserTokenStream{values: values, index: index}
				assert declaration_value_span_end(&stream, nested)
					== declaration_span_lookahead_oracle(stream, nested)
				assert stream.index == index
			}
		}
	}
}

fn test_declaration_span_scan_distinguishes_tokens_from_raw_text_and_nested_components() {
	values := [ComponentValue.new('; }'),
		ComponentValue.from_function(Function{name: 'f', value: [
			ComponentValue.from_token(Token.create(.semicolon, ';'))]}),
		ComponentValue.from_block(SimpleBlock{value: [
			ComponentValue.from_token(Token.create(.close_curly, '}'))]}),
		ComponentValue.from_token(Token.create(.close_curly, '}')),
		ComponentValue.from_token(Token.create(.semicolon, ';')),
		ComponentValue.from_token(Token{type_: .end_of_file}),
		ComponentValue.from_token(Token.create_ident('tail', 'tail'))]
	stream := ParserTokenStream{values: values}
	assert declaration_value_span_end(&stream, .yes) == 3
	assert declaration_value_span_end(&stream, .no) == 4
	assert declaration_value_span_end(&ParserTokenStream{values: values, index: 5}, .no) == 5
	assert stream.values == values
	assert stream.index == 0
}
