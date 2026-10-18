module css

import strings

fn compare_ident_prefix_with_scalar(source string, prefix string) (string, bool) {
	mut actual := Tokenizer.new(prefix + source)
	defer { actual.input_arena.release() }
	mut expected := Tokenizer.new(prefix + source)
	defer { expected.input_arena.release() }
	for _ in prefix.runes_iterator() {
		assert actual.next_code_point() == expected.next_code_point()
	}
	name, escaped := actual.consume_an_ident_sequence_with_escape_flag()
	oracle, oracle_escaped := expected.consume_ident_prefix_scalar_oracle()
	assert name == oracle
	assert escaped == oracle_escaped
	assert actual.index == expected.index
	assert actual.prev_index == expected.prev_index
	assert actual.position == expected.position
	assert actual.prev_position == expected.prev_position
	assert actual.current_byte_offset() == expected.current_byte_offset()
	assert actual.peek_code_point(0) == expected.peek_code_point(0)
	actual.reconsume_current_input_code_point()
	expected.reconsume_current_input_code_point()
	for _ in 0 .. 3 {
		assert actual.next_code_point() == expected.next_code_point()
		assert actual.position == expected.position
		assert actual.prev_position == expected.prev_position
	}
	return name, escaped
}

fn test_ident_prefix_bulk_cursor_matches_scalar_at_ascii_and_unicode_boundaries() {
	for name in ['', 'a', '---', '0123', '--MixedCase', 'β中😀', 'á', 'x'.repeat(4096)] {
		for boundary in 0 .. 128 {
			for prefix in ['', 'β😀\n', 'x\n\t'] {
				_, _ = compare_ident_prefix_with_scalar(name + rune(boundary).str() + ';tail', prefix)
			}
		}
	}
	for name in ['a', '---', '0123', '--MixedCase', 'β中😀', 'á'] {
		value, escaped := compare_ident_prefix_with_scalar(name + ';tail', 'β😀\n')
		assert value == name
		assert !escaped
	}
}

fn test_ident_prefix_retains_escape_decoding_and_source_newline_positions() {
	for leading in ['', 'prefix-', '--β😀', 'long'.repeat(64)] {
		for escaped in ['\\61 ', '\\000061', '\\0 ', '\\110000 ', '\\D800 ',
			'\\a\n', '\\a\r\n', '\\β', '\\😀', '\\', '\\\n', '\\\r', '\\\x0c'] {
			for tail in ['', 'tail;', 'β😀;', '\nnext'] {
				_, _ = compare_ident_prefix_with_scalar(leading + escaped + tail, 'β😀\n')
			}
		}
	}
	name, escaped := compare_ident_prefix_with_scalar('foo\\62 ar;', '')
	assert name == 'foobar'
	assert escaped
}

fn test_ident_prefix_preserves_filtered_malformed_utf8_repairs() {
	for bytes in [[u8(0x80)], [u8(0xc0), 0xaf], [u8(0xed), 0xa0, 0x80],
		[u8(0xf4), 0x90, 0x80, 0x80], [u8(0xe2), 0x82]] {
		bad := bytes.bytestr()
		for source in ['prefix' + bad + ';', 'prefix' + bad + '\\61 tail;',
			'prefix\\61 ' + bad + 'β;', bad + '\\0 ' + bad] {
			_, _ = compare_ident_prefix_with_scalar(filter_code_points(source, 'utf-8'), 'β😀\n')
		}
	}
}

fn test_ident_prefix_public_tokens_keep_owned_spellings_and_dimension_units() {
	tokens := Tokenizer.tokenize('plain β😀 --custom foo\\62 ar +2p\\78  0', 'utf-8')
	identifiers := tokens.filter(it.is(.ident))
	dimensions := tokens.filter(it.is(.dimension))
	assert identifiers.map(it.ident()) == ['plain', 'β😀', '--custom', 'foobar']
	assert dimensions.len == 1
	assert dimensions[0].dimension_unit() == 'px'
	assert dimensions[0].number_value_.value() == 2
	for _ in 0 .. 3 {
		gc_collect()
		assert identifiers[3].original_source_text() == 'foo\\62 ar'
		for index, token in identifiers {
			assert unsafe { token.ident().str[token.ident().len] } == 0
			assert unsafe { token.original_source_text().str[token.original_source_text().len] } == 0
			if index < 3 { assert token.ident().str == token.original_source_text().str }
		}
		assert dimensions[0].dimension_unit() == 'px'
	}
}

// Frozen scalar implementation: compare cursor/escape semantics with the bulk prefix.
fn (mut tokenizer Tokenizer) consume_ident_prefix_scalar_oracle() (string, bool) {
	// This section describes how to consume an ident sequence from a stream of code points.
	// It returns a string containing the largest name that can be formed from adjacent
	// code points in the stream, starting from the first.
	//
	// Note: This algorithm does not do the verification of the first few code points that
	// are necessary to ensure the returned code points would constitute an <ident-token>.
	// If that is the intended use, ensure that the stream starts with an ident sequence before
	// calling this algorithm.

	// Unescaped names already occupy one contiguous span of the filtered
	// input. Allocate a builder only when escape decoding changes that span.
	start_byte_offset := tokenizer.current_byte_offset()
	mut result := unsafe { &TokenizerNameBuilder(nil) }

	// Repeatedly consume the next input code point from the stream:
	for {
		input := tokenizer.next_code_point()

		if is_eof(input) {
			break
		}

		// name code point
		if is_ident_code_point(input) {
			// Append the code point to result.
			if result != unsafe { nil } {
				append_code_point(mut result.text, input)
			}
			continue
		}

		// the stream starts with a valid escape
		if Tokenizer.is_valid_escape_sequence(tokenizer.start_of_input_stream_twin()) {
			// Consume an escaped code point. Append the returned code point to result.
			if result == unsafe { nil } {
				result = &TokenizerNameBuilder{ text: strings.new_builder(16) }
				result.text.write_string(tokenizer.decoded_input[start_byte_offset..unsafe { tokenizer.input_arena.byte_offsets[tokenizer.prev_index] }])
			}
			append_code_point(mut result.text, tokenizer.consume_escaped_code_point())
			continue
		}

		// anything else
		// Reconsume the current input code point. Return result.
		tokenizer.reconsume_current_input_code_point()
		break
	}

	if result != unsafe { nil } {
		return result.text.str(), true
	}
	return tokenizer.input_since(start_byte_offset), false
}
