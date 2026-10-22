module css

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_component_stream_boundary_probes_reuse_immutable_eof() {
	mut empty := ParserTokenStream{}
	// Initialize before counting; the shared value has process lifetime even
	// when the first caller belongs to a retiring parsing workspace.
	assert empty.next_token().is(.end_of_file)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		assert empty.consume_a_token().is(.end_of_file)
		assert empty.peek_token(-1).is(.end_of_file)
		assert empty.peek_token(1).is(.end_of_file)
	}
	assert empty.index == 0
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
	mut live := ParserTokenStream.from_values([ComponentValue.from_token(Token.create_ident('x', 'x'))])
	assert live.next_token().is_ident('x')
	assert live.peek_token(1).is(.end_of_file)
	live.discard_a_token()
	assert live.next_token().is(.end_of_file)
	live.reconsume_current_input_token()
	assert live.next_token().is_ident('x')
	assert empty.next_token().token().value == ''
}

fn test_virtual_eof_survives_a_retired_parser_workspace() {
	scratch := platform.begin_thread_scratch('component stream EOF test')
	stream := ParserTokenStream.from_source('a {}', 'utf-8')
	terminal := stream.peek_token(stream.values.len)
	scratch.finish()
	$if gcboehm ? { C.GC_gcollect() }
	assert terminal.is(.end_of_file)
	assert terminal.original_source_text() == ''
	assert terminal.token().start_position_.line == 0
	assert terminal.token().end_position_.column == 0
}
