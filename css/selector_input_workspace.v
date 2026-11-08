module css

$if prealloc {
	import platform
}

// A selector retains its serialized source and parsed graph, never the
// component vectors or escaping buffers used to construct that source.
fn (mut parser RuleSelectorParser) consume_selector_source(mut tokens ParserTokenStream) string {
	$if prealloc {
		scratch := platform.begin_thread_scratch('selector input')
		parts := parser.consume_selector_component_span(mut tokens)
		text := parser_selector_prelude_to_string(parts).trim_space()
		scratch.leave()
		owned := text.clone()
		scratch.finish()
		return owned
	}
	parts := parser.consume_selector_component_span(mut tokens)
	return parser_selector_prelude_to_string(parts).trim_space()
}

fn (mut parser RuleSelectorParser) consume_selector_component_span(mut tokens ParserTokenStream) []ComponentValue {
	if disable_borrowed_selector_spans {
		return parser.consume_a_list_of_component_values(mut tokens, TokenType.comma, .no)
	}
	start := tokens.index
	for tokens.has_next_token() && !tokens.next_token().is(.comma) {
		tokens.discard_a_token()
	}
	if borrowed_selector_span_diagnostics && !borrowed_selector_span_reported {
		borrowed_selector_span_reported = true
		eprintln('Vox selector input: borrowed immutable component span')
	}
	return tokens.values[start..tokens.index]
}
