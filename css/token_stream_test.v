module css

fn test_tokenizer_decodes_the_declared_input_encoding() {
	tokens := Tokenizer.tokenize([u8(0x80)].bytestr(), 'windows-1252')
	assert tokens[0].is(.ident)
	assert tokens[0].ident() == '€'
}

fn test_at_keyword_source_text_includes_the_consumed_name() {
	tokens := Tokenizer.tokenize('@media screen', 'utf-8')
	assert tokens[0].is(.at_keyword)
	assert tokens[0].at_keyword() == 'media'
	assert tokens[0].original_source_text() == '@media'
}

// Translation of Tests/LibWeb/TestCSSTokenStream.cpp.

fn ident_token(name string) Token {
	return Token.create_ident(name, name)
}

fn test_token_stream_basic() {
	tokens := [ident_token('hello')]
	mut stream := ParserTokenStream.from_tokens(tokens)

	assert !stream.is_empty()
	assert stream.has_next_token()
	assert stream.remaining_token_count() == 1

	// next_token() doesn't consume it.
	next := stream.next_token()
	assert !stream.is_empty()
	assert stream.has_next_token()
	assert stream.remaining_token_count() == 1
	assert next.is(.ident)
	assert next.token().ident() == 'hello'

	// consume_a_token() does consume it.
	consumed := stream.consume_a_token()
	assert stream.is_empty()
	assert !stream.has_next_token()
	assert stream.remaining_token_count() == 0
	assert consumed.is(.ident)
	assert consumed.token().ident() == 'hello'

	// Now, any further tokens should be EOF.
	assert stream.next_token().is(.end_of_file)
	assert stream.consume_a_token().is(.end_of_file)
}

fn test_token_stream_marks() {
	tokens := [ident_token('a'), ident_token('b'), ident_token('c'),
		ident_token('d'), ident_token('e'), ident_token('f'),
		ident_token('g')]
	mut stream := ParserTokenStream.from_tokens(tokens)

	stream.mark() // 0
	assert stream.remaining_token_count() == 7
	stream.discard_a_token()
	stream.discard_a_token()
	stream.discard_a_token()
	assert stream.remaining_token_count() == 4

	stream.mark() // 3
	stream.discard_a_token()
	assert stream.remaining_token_count() == 3
	stream.restore_a_mark() // Back to 3
	assert stream.remaining_token_count() == 4

	stream.discard_a_token()
	stream.discard_a_token()
	stream.discard_a_token()
	assert stream.remaining_token_count() == 1

	stream.mark() // 6
	stream.discard_a_mark()
	assert stream.remaining_token_count() == 1
	stream.restore_a_mark() // Back to 0
	assert stream.remaining_token_count() == 7
}
