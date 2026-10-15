module html

import strings

fn ascii_builder_tokenize_for_test(input string) []HTMLToken {
	mut tokens := []HTMLToken{}
	mut tokenizer := HTMLTokenizer.new(input)
	for {
		token := tokenizer.next_token() or { break }
		tokens << token
	}
	return tokens
}

fn token_runes_builder_oracle(values []rune) string {
	mut builder := strings.new_builder(values.len)
	for value in values { builder.write_rune(value) }
	return builder.str()
}

fn test_ascii_token_runes_preserve_controls_lengths_and_termination() {
	for length in [0, 1, 2, 15, 16, 127, 128, 1024] {
		mut values := []rune{}
		mut expected_bytes := []u8{}
		for index in 0 .. length {
			values << rune(index % 128)
			expected_bytes << u8(index % 128)
		}
		actual := runes_to_string(values)
		assert actual == token_runes_builder_oracle(values)
		assert actual.bytes() == expected_bytes
		assert actual.len == length
		assert unsafe { actual.str[actual.len] } == 0
	}
	for code_point in 0 .. 128 {
		actual := runes_to_string([rune(code_point)])
		assert actual.len == 1
		assert actual[0] == u8(code_point)
		assert actual == token_runes_builder_oracle([rune(code_point)])
		assert unsafe { actual.str[1] } == 0
	}
}

fn test_ascii_token_runes_keep_original_nonascii_and_invalid_encoder() {
	for code_point in [128, 0x7ff, 0x800, 0xd800, 0xdfff, 0xe000, 0xffff,
		0x10000, 0x10ffff, 0x110000, -1] {
		for prefix_length in [0, 1, 127] {
			mut values := 'a'.repeat(prefix_length).runes()
			values << rune(code_point)
			values << 'tail'.runes()
			before := values.clone()
			actual := runes_to_string(values)
			assert actual == token_runes_builder_oracle(values)
			assert unsafe { actual.str[actual.len] } == 0
			assert values == before
		}
	}
	assert runes_to_string('Aβ中😀\u0000'.runes()) == 'Aβ中😀\u0000'
}

fn test_ascii_token_runes_own_output_after_mutation_builder_reuse_and_gc() {
	mut values := 'owned ASCII'.runes()
	owned := runes_to_string(values)
	values[0] = `X`
	assert owned == 'owned ASCII'
	mut tokenizer := HTMLTokenizer.new('')
	tokenizer.current_builder = 'first ASCII'.runes()
	first := tokenizer.consume_current_builder()
	assert tokenizer.current_builder.len == 0
	tokenizer.current_builder = 'β😀 second'.runes()
	second := tokenizer.consume_current_builder()
	assert tokenizer.current_builder.len == 0
	tokenizer.current_builder = 'last ASCII'.runes()
	third := tokenizer.consume_current_builder()
	for _ in 0 .. 3 {
		gc_collect()
		assert owned == 'owned ASCII'
		assert first == 'first ASCII' && second == 'β😀 second' && third == 'last ASCII'
		for value in [owned, first, second, third] {
			assert unsafe { value.str[value.len] } == 0
		}
	}
}

fn test_ascii_token_runes_keep_streamed_names_attributes_comments_and_positions() {
	chunks := ['<!doctype html><DIV DaTa="A&am', 'p;B" title="β😀" data-empty="">', '<!--note--></DIV>']
	continuous := ascii_builder_tokenize_for_test(chunks.join(''))
	mut tokenizer := HTMLTokenizer.create()
	mut streamed := []HTMLToken{}
	for chunk in chunks {
		tokenizer.append_to_input_stream(chunk)
		for {
			token := tokenizer.next_token() or { break }
			streamed << token
		}
	}
	tokenizer.close_input_stream()
	for {
		token := tokenizer.next_token() or { break }
		streamed << token
	}
	assert streamed == continuous
	assert streamed.len == 5
	assert streamed[0].doctype.name == 'html'
	assert streamed[1].tag_name == 'div' && streamed[3].tag_name == 'div'
	assert streamed[1].attributes[0].local_name == 'data'
	assert streamed[1].attributes[0].value == 'A&B'
	assert streamed[1].attributes[1].value == 'β😀'
	assert streamed[1].attributes[2].value == ''
	assert streamed[2].comment_data == 'note'
	gc_collect()
	assert streamed == continuous
}
