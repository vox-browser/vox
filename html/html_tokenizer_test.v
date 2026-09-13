module html

fn test_html_tokenizer_exact_transition_and_emit_hooks() {
	mut tokenizer := HTMLTokenizer.new('')
	tokenizer.will_switch_to(.tag_name)
	tokenizer.will_reconsume_in(.data)
	mut token := HTMLToken.make_start_tag('div')
	token.add_attribute(Attribute{ local_name: 'id', value: 'first' })
	token.add_attribute(Attribute{ local_name: 'id', value: 'second' })
	tokenizer.will_emit(mut token)
	assert tokenizer.last_emitted_start_tag_name? == 'div'
	assert token.attributes.len == 1
	assert token.attribute('id')? == 'first'
}

fn test_old_insertion_points_survive_reentrant_input_insertion() {
	mut tokenizer := HTMLTokenizer.new('abcdef')
	tokenizer.insertion_point = 4
	tokenizer.store_old_insertion_point()
	tokenizer.current_offset = 2
	tokenizer.update_insertion_point()
	tokenizer.store_old_insertion_point()

	tokenizer.insert_input_at_insertion_point('XY')
	assert tokenizer.insertion_point? == 4
	assert tokenizer.decoded_input.string() == 'abXYcdef'

	tokenizer.restore_old_insertion_point()
	assert tokenizer.insertion_point? == 4
	tokenizer.restore_old_insertion_point()
	assert tokenizer.insertion_point? == 6
}

fn test_tokenizer_keeps_consumed_input_while_an_old_insertion_point_is_saved() {
	mut tokenizer := HTMLTokenizer.new('done')
	tokenizer.current_offset = tokenizer.decoded_input.len
	tokenizer.insertion_point = none
	tokenizer.store_old_insertion_point()
	tokenizer.parser_did_run()
	assert tokenizer.decoded_input.string() == 'done'

	tokenizer.restore_old_insertion_point()
	tokenizer.parser_did_run()
	assert tokenizer.decoded_input.len == 0
}

fn test_tokenizer_waits_for_crlf_split_across_document_writes() {
	mut tokenizer := HTMLTokenizer.new('\r')
	tokenizer.current_offset = 0
	tokenizer.insertion_point = 1
	assert tokenizer.next_token_impl(.yes) == none
	assert tokenizer.current_offset == 0

	tokenizer.insert_input_at_insertion_point('\nX')
	line_feed := tokenizer.next_token_impl(.yes) or { panic('missing normalized line feed') }
	assert line_feed.is_character()
	assert line_feed.code_point == `\n`
	assert tokenizer.current_offset == 2
	next := tokenizer.next_token_impl(.yes) or { panic('missing character after CRLF') }
	assert next.is_character()
	assert next.code_point == `X`
	assert tokenizer.next_token_impl(.yes) == none
}

fn test_tokenizer_waits_for_open_stream_input_and_split_crlf() {
	mut tokenizer := HTMLTokenizer.create()
	assert !tokenizer.is_input_stream_closed()
	assert tokenizer.next_token() == none

	tokenizer.append_to_input_stream('A\r')
	first := tokenizer.next_token() or { panic('missing first streamed character') }
	assert first.is_character() && first.code_point == `A`
	assert tokenizer.next_token() == none
	assert tokenizer.current_offset == 1

	tokenizer.append_to_input_stream('\nB')
	line_feed := tokenizer.next_token() or { panic('missing streamed line feed') }
	assert line_feed.is_character() && line_feed.code_point == `\n`
	last := tokenizer.next_token() or { panic('missing last streamed character') }
	assert last.is_character() && last.code_point == `B`
	assert tokenizer.next_token() == none

	tokenizer.close_input_stream()
	assert tokenizer.is_input_stream_closed()
	eof := tokenizer.next_token() or { panic('missing streamed EOF') }
	assert eof.type_ == .end_of_file
}

fn test_insert_eof_closes_the_tokenizer_input_stream() {
	mut tokenizer := HTMLTokenizer.create()
	tokenizer.insert_eof()
	assert tokenizer.is_input_stream_closed()
	assert tokenizer.is_eof_inserted()
	assert tokenizer.next_token()?.type_ == .end_of_file
}

fn test_open_stream_can_pause_in_named_character_reference() {
	mut tokenizer := HTMLTokenizer.create()
	tokenizer.append_to_input_stream('&not')
	assert tokenizer.next_token() == none

	tokenizer.append_to_input_stream('in;X')
	token := tokenizer.next_token() or { panic('missing streamed character reference') }
	assert token.is_character()
	assert token.code_point == rune(0x2209)
	next := tokenizer.next_token() or { panic('missing character after streamed reference') }
	assert next.is_character() && next.code_point == `X`
	assert tokenizer.next_token() == none
	tokenizer.close_input_stream()
	assert tokenizer.next_token()?.type_ == .end_of_file
}

fn test_open_stream_can_pause_during_fixed_lookahead() {
	mut tokenizer := HTMLTokenizer.create()
	tokenizer.append_to_input_stream('<!DOC')
	assert tokenizer.next_token() == none
	tokenizer.append_to_input_stream('TYPE html>')
	token := tokenizer.next_token() or { panic('missing streamed doctype') }
	assert token.type_ == .doctype
	assert token.doctype.name == 'html'
}

// Runtime tests for the HTML tokenizer, translated from Tests/LibWeb/TestHTMLTokenizer.cpp.
// (The file-based `regression` test case is omitted: it depends on an external fixture and a hash
// tied to HTMLToken::to_string()'s exact format.)

fn run_tokenizer(input string) []HTMLToken {
	mut tokens := []HTMLToken{}
	mut tokenizer := HTMLTokenizer.new(input)
	for {
		token := tokenizer.next_token() or { break }
		tokens << token
	}
	return tokens
}

fn test_empty() {
	tokens := run_tokenizer('')
	assert tokens.len == 1
	assert tokens[0].type_ == .end_of_file
}

fn test_basic() {
	tokens := run_tokenizer('<html><head></head><body></body></html>')
	// html start(1-5), head start(7-11), head end(14-18), body start(20-24), body end(27-31),
	// html end(34-38), EOF.
	assert tokens.len == 7
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'html'
	assert tokens[0].start_position.column == 1
	assert tokens[0].end_position.column == 5

	assert tokens[1].type_ == .start_tag && tokens[1].tag_name == 'head'
	assert tokens[1].start_position.column == 7
	assert tokens[1].end_position.column == 11

	assert tokens[2].type_ == .end_tag && tokens[2].tag_name == 'head'
	assert tokens[2].start_position.column == 14
	assert tokens[2].end_position.column == 18

	assert tokens[3].type_ == .start_tag && tokens[3].tag_name == 'body'
	assert tokens[3].start_position.column == 20
	assert tokens[3].end_position.column == 24

	assert tokens[4].type_ == .end_tag && tokens[4].tag_name == 'body'
	assert tokens[4].start_position.column == 27
	assert tokens[4].end_position.column == 31

	assert tokens[5].type_ == .end_tag && tokens[5].tag_name == 'html'
	assert tokens[5].start_position.column == 34
	assert tokens[5].end_position.column == 38

	assert tokens[6].type_ == .end_of_file
}

fn test_basic_with_text() {
	tokens := run_tokenizer('<p>This is some text.</p>')
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'p'
	assert tokens[0].start_position.column == 1
	assert tokens[0].end_position.column == 2

	text := 'This is some text.'
	mut i := 1
	for r in text.runes() {
		assert tokens[i].type_ == .character
		assert tokens[i].code_point == r
		i++
	}
	assert tokens[i].type_ == .end_tag && tokens[i].tag_name == 'p'
	assert tokens[i].start_position.column == 23
	assert tokens[i].end_position.column == 24
	i++
	assert tokens[i].type_ == .end_of_file
}

fn expect_single_attribute(tokens []HTMLToken, name string, value string, ns int, ne int, vs int, ve int) {
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'p'
	assert tokens[0].attribute_count() == 1
	attr := tokens[0].raw_attribute(name) or { panic('missing attribute ${name}') }
	assert attr.value == value
	assert attr.name_start_position.column == ns
	assert attr.name_end_position.column == ne
	assert attr.value_start_position.column == vs
	assert attr.value_end_position.column == ve
}

fn test_unquoted_attributes() {
	tokens := run_tokenizer('<p foo=bar>')
	assert tokens[0].start_position.column == 1
	assert tokens[0].end_position.column == 10
	expect_single_attribute(tokens, 'foo', 'bar', 3, 6, 7, 10)
}

fn test_single_quoted_attributes() {
	tokens := run_tokenizer("<p foo='bar'>")
	assert tokens[0].end_position.column == 12
	expect_single_attribute(tokens, 'foo', 'bar', 3, 6, 7, 12)
}

fn test_double_quoted_attributes() {
	tokens := run_tokenizer('<p foo="bar">')
	assert tokens[0].end_position.column == 12
	expect_single_attribute(tokens, 'foo', 'bar', 3, 6, 7, 12)
}

fn test_valueless_attribute() {
	tokens := run_tokenizer('<p foo>')
	assert tokens[0].start_position.column == 1
	assert tokens[0].end_position.column == 6
	expect_single_attribute(tokens, 'foo', '', 3, 6, 0, 0)
}

fn test_multiple_attributes() {
	tokens := run_tokenizer('<p foo="bar" baz=foobar biz foo2="bar2">')
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'p'
	assert tokens[0].start_position.column == 1
	assert tokens[0].end_position.column == 39
	assert tokens[0].attribute_count() == 4

	foo := tokens[0].raw_attribute('foo') or { panic('foo') }
	assert foo.value == 'bar'
	assert foo.name_start_position.column == 3 && foo.name_end_position.column == 6
	assert foo.value_start_position.column == 7 && foo.value_end_position.column == 12

	baz := tokens[0].raw_attribute('baz') or { panic('baz') }
	assert baz.value == 'foobar'
	assert baz.name_start_position.column == 13 && baz.name_end_position.column == 16
	assert baz.value_start_position.column == 17 && baz.value_end_position.column == 23

	biz := tokens[0].raw_attribute('biz') or { panic('biz') }
	assert biz.value == ''
	assert biz.name_start_position.column == 24 && biz.name_end_position.column == 27

	foo2 := tokens[0].raw_attribute('foo2') or { panic('foo2') }
	assert foo2.value == 'bar2'
	assert foo2.name_start_position.column == 28 && foo2.name_end_position.column == 32
	assert foo2.value_start_position.column == 33 && foo2.value_end_position.column == 39
}

fn test_character_reference_in_attribute() {
	tokens := run_tokenizer('<p foo=a&amp;b bar=\'a&#38;b\' baz="a&#x26;b">')
	assert tokens[0].attribute_count() == 3
	assert (tokens[0].raw_attribute('foo') or { panic('foo') }).value == 'a&b'
	assert (tokens[0].raw_attribute('bar') or { panic('bar') }).value == 'a&b'
	assert (tokens[0].raw_attribute('baz') or { panic('baz') }).value == 'a&b'
}

fn test_named_character_reference() {
	tokens := run_tokenizer('&notinvc;&notit;&cz')
	mut i := 0
	assert tokens[i].type_ == .character && tokens[i].code_point == rune(0x22F6) // &notinvc;
	i++
	assert tokens[i].type_ == .character && tokens[i].code_point == rune(0xAC) // &not (backtracked)
	i++
	for r in 'it'.runes() {
		assert tokens[i].type_ == .character && tokens[i].code_point == r
		i++
	}
	assert tokens[i].type_ == .character && tokens[i].code_point == `;`
	i++
	for r in '&cz'.runes() {
		assert tokens[i].type_ == .character && tokens[i].code_point == r
		i++
	}
	assert tokens[i].type_ == .end_of_file
}

fn test_numeric_character_reference() {
	tokens := run_tokenizer('&#1111')
	assert tokens[0].type_ == .character && tokens[0].code_point == rune(1111)
	assert tokens[1].type_ == .end_of_file
}

fn test_hex_character_reference() {
	tokens := run_tokenizer('&#xA12bZ')
	assert tokens[0].type_ == .character && tokens[0].code_point == rune(0xA12B)
	assert tokens[1].type_ == .character && tokens[1].code_point == `Z`
	assert tokens[2].type_ == .end_of_file
}

fn test_comment() {
	tokens := run_tokenizer('<p><!-- This is a comment --></p>')
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'p'
	assert tokens[1].type_ == .comment
	assert tokens[1].comment() == ' This is a comment '
	assert tokens[2].type_ == .end_tag && tokens[2].tag_name == 'p'
	assert tokens[2].start_position.column == 31
	assert tokens[2].end_position.column == 32
	assert tokens[3].type_ == .end_of_file
}

fn test_doctype() {
	tokens := run_tokenizer('<!DOCTYPE html><html></html>')
	assert tokens[0].type_ == .doctype
	assert tokens[0].doctype_data().name == 'html'
	assert tokens[1].type_ == .start_tag && tokens[1].tag_name == 'html'
	assert tokens[1].start_position.column == 16
	assert tokens[1].end_position.column == 20
	assert tokens[2].type_ == .end_tag && tokens[2].tag_name == 'html'
	assert tokens[2].start_position.column == 23
	assert tokens[2].end_position.column == 27
}

fn test_ambiguous_ampersand_offset() {
	tokens := run_tokenizer('&a')
	assert tokens[0].type_ == .character
	assert tokens[0].code_point == `&`
	assert tokens[0].start_position.line == 0
	assert tokens[0].start_position.column == 1
}

fn test_self_closing_tag() {
	tokens := run_tokenizer('<br/>')
	assert tokens[0].type_ == .start_tag && tokens[0].tag_name == 'br'
	assert tokens[0].is_self_closing()
	assert tokens[1].type_ == .end_of_file
}

fn test_duplicate_attributes_are_normalized() {
	tokens := run_tokenizer('<p a="1" a="2">')
	assert tokens[0].type_ == .start_tag
	assert tokens[0].attribute_count() == 1
	assert (tokens[0].raw_attribute('a') or { panic('a') }).value == '1'
	assert tokens[0].had_duplicate_attribute
}
