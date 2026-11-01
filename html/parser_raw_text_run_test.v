module html

import dom

fn text_run_tokens(input string, state State, batched bool) ([]rune, []HTMLToken) {
	mut tokenizer := HTMLTokenizer.new(input)
	tokenizer.state = state
	tokenizer.last_emitted_start_tag_name = if state == .rawtext { 'style' } else { 'script' }
	mut characters := []rune{}
	mut other := []HTMLToken{}
	for {
		if batched {
			if run := tokenizer.consume_parser_text_run(.no) { characters << run; continue }
		}
		token := tokenizer.next_token() or { break }
		if token.is_character() { characters << token.code_point } else { other << token }
		if token.is_end_of_file() { break }
	}
	return characters, other
}

fn test_parser_text_runs_preserve_tokenizer_text_and_following_token_positions() {
	for state in [State.rawtext, .script_data] {
		end_tag := if state == .rawtext { 'style' } else { 'script' }
		for content in ['abc'.repeat(5000), 'A\r\nB\rC\n日本語😀\u0000D',
			'first</not-an-end-tag>tail', 'x<!--<script>escaped</script>-->y', 'unterminated<'] {
			input := content + '</${end_tag}><p data-after="yes">after</p>'
			expected_chars, expected_tokens := text_run_tokens(input, state, false)
			actual_chars, actual_tokens := text_run_tokens(input, state, true)
			assert actual_chars == expected_chars
			assert actual_tokens == expected_tokens
		}
	}
}

fn test_parser_text_runs_stop_at_document_write_and_stream_boundaries() {
	mut tokenizer := HTMLTokenizer.create()
	tokenizer.state = .rawtext
	tokenizer.append_to_input_stream('prefix\r')
	assert runes_to_string(tokenizer.consume_parser_text_run(.no)?) == 'prefix'
	assert tokenizer.consume_parser_text_run(.no) == none
	assert tokenizer.next_token() == none
	tokenizer.append_to_input_stream('\nsuffix')
	assert tokenizer.next_token()?.code_point == `\n`
	tokenizer.insertion_point = tokenizer.current_offset + 3
	assert runes_to_string(tokenizer.consume_parser_text_run(.yes)?) == 'suf'
	assert tokenizer.consume_parser_text_run(.yes) == none
	assert tokenizer.next_token_impl(.yes) == none
	tokenizer.undefine_insertion_point()
	assert runes_to_string(tokenizer.consume_parser_text_run(.no)?) == 'fix'
	tokenizer.set_blocked(true)
	tokenizer.append_to_input_stream('blocked')
	assert tokenizer.consume_parser_text_run(.no) == none
}

fn test_committed_text_runs_keep_cursor_and_final_position_across_bounded_chunks() {
	for state in [State.data, .rawtext, .script_data] {
		input := ('first\n日本語😀tail'.repeat(1000)) + '<b>after</b>'
		mut actual := HTMLTokenizer.new(input)
		mut expected := HTMLTokenizer.new(input)
		actual.state = state
		expected.state = state
		for {
			run := actual.consume_parser_text_run(.no) or { break }
			expected.skip(run.len)
			assert actual.current_offset == expected.current_offset
			assert actual.prev_offset == expected.prev_offset
			assert actual.nth_last_position(0) == expected.nth_last_position(0)
		}
		assert actual.next_token() == expected.next_token()
	}
}

fn test_large_raw_text_parsing_preserves_dom_normalization_and_end_tag_boundaries() {
	content := 'p{color:red}\n'.repeat(1000) + '</stylish>日本語\r\n\u0000tail'
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parser := HTMLParser.create_with_scripting_mode(document,
		'<!doctype html><style id="large">${content}</style><p id="after">after</p>', .inert)
	parser.resource_discovery_only = true
	parser.run()
	assert document.get_element_by_id('large')?.as_node().text_content()? == content.replace('\r\n', '\n').replace('\u0000', '�')
	assert document.get_element_by_id('after')?.as_node().text_content()? == 'after'
}
