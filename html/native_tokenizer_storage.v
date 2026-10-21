module html

// Tokens borrow immutable payloads from the tokenizer. Native closed-input
// documents copy strings published into the DOM and script models, then retire the
// tokenizer's input runes, token queue, builders, and source-position history.
fn (p &HTMLParser) own_tokenizer_string(value string) string {
	if p.tokenizer_storage != unsafe { nil } { return value.clone() }
	return value
}

fn (p &HTMLParser) own_tokenizer_optional_string(value ?string) ?string {
	if text := value { return p.own_tokenizer_string(text) }
	return none
}

fn (mut p HTMLParser) next_parser_token(stop StopAtInsertionPoint) ?HTMLToken {
	if p.tokenizer_storage != unsafe { nil } {
		mut storage := p.tokenizer_storage
		entry := storage.enter()
		defer { storage.leave(entry) }
		return p.tokenizer.next_token_impl(stop)
	}
	return p.tokenizer.next_token_impl(stop)
}

fn (mut p HTMLParser) parser_text_run(stop StopAtInsertionPoint) ?[]rune {
	if p.tokenizer_storage != unsafe { nil } {
		mut storage := p.tokenizer_storage
		entry := storage.enter()
		defer { storage.leave(entry) }
		return p.tokenizer.consume_parser_text_run(stop)
	}
	return p.tokenizer.consume_parser_text_run(stop)
}

fn (mut p HTMLParser) retire_tokenizer_storage() {
	if p.tokenizer_storage == unsafe { nil } { return }
	mut storage := p.tokenizer_storage
	position := p.tokenizer.nth_last_position(0)
	// Preserve the public source and EOF/insertion-point state, without leaving
	// any tokenizer fields pointing into retired storage.
	p.tokenizer = HTMLTokenizer{
		parser_:                     p
		source:                      p.tokenizer.source
		state:                       p.tokenizer.state
		return_state:                p.tokenizer.return_state
		last_emitted_start_tag_name: p.own_tokenizer_optional_string(p.tokenizer.last_emitted_start_tag_name)
		explicit_eof_inserted:       p.tokenizer.explicit_eof_inserted
		input_stream_closed:         p.tokenizer.input_stream_closed
		has_emitted_eof:             p.tokenizer.has_emitted_eof
		blocked:                     p.tokenizer.blocked
		aborted:                     p.tokenizer.aborted
		source_positions:            [position]
	}
	p.list_of_active_formatting_elements.entries = []ActiveFormattingElement{}
	p.list_of_active_formatting_elements.parser_storage = unsafe { nil }
	p.pending_table_character_tokens = []HTMLToken{}
	p.tokenizer_storage = unsafe { nil }
	storage.release()
}
