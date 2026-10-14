module css

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn retained_component_stream() ComponentValueStream {
	return ComponentValueStream.new(parse_component_values_list(ParsingParams{}, 'calc(1px + var(--size, 2%)) red'))
}

fn test_component_stream_transactions_share_input_and_keep_independent_cursors() {
	values := parse_component_values_list(ParsingParams{}, 'one two three')
	mut original := ComponentValueStream.new(values)
	assert original.values.data == values.data
	assert (original.consume() or { panic('missing first token') }).is_ident('one')
	original.consume_whitespace()
	mut transaction := original.clone()
	assert transaction.values.data == original.values.data
	assert (transaction.consume() or { panic('missing second token') }).is_ident('two')
	transaction.consume_whitespace()
	assert (transaction.consume() or { panic('missing third token') }).is_ident('three')
	assert (original.peek() or { panic('original cursor advanced') }).is_ident('two')
	original = transaction
	assert original.is_empty()
	assert values[0].is_ident('one')
}

fn test_component_stream_retains_nested_input_after_parser_returns() {
	mut stream := retained_component_stream()
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		assert (stream.peek() or { panic('lost function') }).to_string() == 'calc(1px + var(--size, 2%))'
	}
	stream.consume() or { panic('missing function') }
	stream.consume_whitespace()
	assert (stream.consume() or { panic('missing color') }).is_ident('red')
	assert stream.is_empty()
}
