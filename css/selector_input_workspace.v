module css

$if prealloc {
	import platform
}

// A selector retains its serialized source and parsed graph, never the
// component vectors or escaping buffers used to construct that source.
fn (mut parser RuleSelectorParser) consume_selector_source(mut tokens ParserTokenStream) string {
	$if prealloc {
		scratch := platform.begin_thread_scratch('selector input')
		parts := parser.consume_a_list_of_component_values(mut tokens, TokenType.comma, .no)
		text := parser_selector_prelude_to_string(parts).trim_space()
		scratch.leave()
		owned := text.clone()
		scratch.finish()
		return owned
	}
	parts := parser.consume_a_list_of_component_values(mut tokens, TokenType.comma, .no)
	return parser_selector_prelude_to_string(parts).trim_space()
}
