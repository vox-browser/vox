module css

// Retain the previous eager comment entry as an oracle. The scanner and the
// remaining token algorithm are shared; independent expectations below pin
// comment spelling, boundaries, cursor movement, and non-comment slash tokens.
fn eager_comment_entry_tokens(source string) []Token {
	mut tokenizer := Tokenizer.new(filter_code_points(source, 'utf-8'))
	defer { tokenizer.input_arena.release() }
	mut result := []Token{}
	for {
		start := tokenizer.position
		offset := tokenizer.current_byte_offset()
		tokenizer.consume_comments()
		mut token := if tokenizer.current_byte_offset() != offset {
			Token.create_whitespace(tokenizer.input_since(offset))
		} else {
			tokenizer.consume_a_token()
		}
		token.set_position_range(start, tokenizer.position)
		result << token
		if token.is(.end_of_file) { break }
	}
	return result
}

fn assert_comment_entry_tokens(source string, types []TokenType, spellings []string) {
	tokens := Tokenizer.tokenize(source, 'utf-8')
	assert tokens.len == types.len
	assert tokens.len == spellings.len
	for index, token in tokens {
		assert token.token_type() == types[index]
		assert token.original_source_text() == spellings[index]
	}
}

fn test_comment_entry_keeps_comments_and_non_comment_slashes() {
	assert_comment_entry_tokens('', [.end_of_file], [''])
	assert_comment_entry_tokens('/', [.delim, .end_of_file], ['/', ''])
	assert_comment_entry_tokens('/x', [.delim, .ident, .end_of_file], ['/', 'x', ''])
	assert_comment_entry_tokens('/**/', [.whitespace, .end_of_file], ['/**/', ''])
	assert_comment_entry_tokens('/**//**/', [.whitespace, .end_of_file], ['/**//**/', ''])
	assert_comment_entry_tokens('/**/ /**/', [.whitespace, .whitespace, .whitespace, .end_of_file], ['/**/', ' ', '/**/', ''])
	assert_comment_entry_tokens('a/**/b', [.ident, .whitespace, .ident, .end_of_file], ['a', '/**/', 'b', ''])
	assert_comment_entry_tokens('1/**/px', [.number, .whitespace, .ident, .end_of_file], ['1', '/**/', 'px', ''])
	// Preserve the existing scanner's unterminated-comment boundary, including
	// the final unconsumed code point. Repairing that behavior is a separate fix.
	assert_comment_entry_tokens('/*', [.whitespace, .end_of_file], ['/*', ''])
	assert_comment_entry_tokens('/*x', [.whitespace, .ident, .end_of_file], ['/*', 'x', ''])
	assert_comment_entry_tokens('/*xy', [.whitespace, .ident, .end_of_file], ['/*x', 'y', ''])
}

fn test_comment_entry_keeps_filtered_unicode_source_positions() {
	tokens := Tokenizer.tokenize('β/*中\r\n😀*/x', 'utf-8')
	assert tokens.len == 4
	assert tokens[0].ident() == 'β'
	assert tokens[0].start_position() == TokenPosition{line: 0, column: 0}
	assert tokens[0].end_position() == TokenPosition{line: 0, column: 1}
	assert tokens[1].is(.whitespace)
	assert tokens[1].original_source_text() == '/*中\n😀*/'
	assert tokens[1].start_position() == TokenPosition{line: 0, column: 1}
	assert tokens[1].end_position() == TokenPosition{line: 1, column: 3}
	assert tokens[2].ident() == 'x'
	assert tokens[2].start_position() == TokenPosition{line: 1, column: 3}
	assert tokens[2].end_position() == TokenPosition{line: 1, column: 4}
	assert tokens[3].is(.end_of_file)
	assert tokens[3].start_position() == tokens[2].end_position()
	assert tokens[3].end_position() == tokens[2].end_position()
}

fn test_comment_entry_leaves_string_url_and_escape_contents_to_their_consumers() {
	tokens := Tokenizer.tokenize('"/*x*/" url(a/**/b) \\/**/x', 'utf-8')
	assert tokens.len == 10
	assert tokens[0].is(.string)
	assert tokens[0].string_value() == '/*x*/'
	assert tokens[2].is(.url)
	assert tokens[2].url() == 'a/**/b'
	assert tokens[4].is(.ident)
	assert tokens[4].ident() == '/'
	assert tokens[5].is(.delim) && tokens[5].delim() == `*`
	assert tokens[6].is(.delim) && tokens[6].delim() == `*`
	assert tokens[7].is(.delim) && tokens[7].delim() == `/`
	assert tokens[8].ident() == 'x'
	assert tokens[9].is(.end_of_file)
}

fn test_comment_entry_matches_eager_entry_across_boundaries_and_truncation() {
	for prefix in ['', '/', '*', '/**/', '/*x*/', '/**//**/', 'β', ' ', '\n'] {
		for suffix in ['', '/', '*', 'x', '/*', '/*x', '/**/', '/**/x', '\n😀', 'url(x)', '"/*x*/"', '1/**/px'] {
			source := prefix + suffix
			assert Tokenizer.tokenize(source, 'utf-8') == eager_comment_entry_tokens(source)
		}
	}
	for source in ['a{width:calc(100% / 3);--x:/**/var(--y,/*z*/2px)}', '/*α\nβ*/@media (width > 1px){#x{color:red}}', 'a\u0000/**/b\fc'] {
		for end in 0 .. source.len + 1 {
			prefix := source[..end]
			assert Tokenizer.tokenize(prefix, 'utf-8') == eager_comment_entry_tokens(prefix)
		}
	}
}
