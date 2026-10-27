module css

import strings

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn make_large_retained_token_stream() []Token {
	mut source := strings.new_builder(128_000)
	for i in 0 .. 4096 {
		source.write_string('.item-${i} { content: "value-${i}"; }\n')
	}
	return Tokenizer.tokenize(source.str(), 'utf-8')
}

// Exercise the browser's fully scanned heap with C optimization enabled. The
// returned aggregate must own the token strings after its producer has exited,
// without the compatibility compiler's production-only deep scope snapshots.
fn test_large_token_stream_retains_strings_across_collections() {
	tokens := make_large_retained_token_stream()
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
		mut identifiers := 0
		mut values := 0
		for token in tokens {
			if token.is(.ident) && token.ident().starts_with('item-') {
				assert token.ident() == 'item-${identifiers}'
				assert token.original_source_text() == 'item-${identifiers}'
				assert token.start_position().line == uint(identifiers)
				identifiers++
			} else if token.is(.string) {
				assert token.string_value() == 'value-${values}'
				assert token.original_source_text() == '"value-${values}"'
				values++
			}
		}
		assert identifiers == 4096
		assert values == 4096
		assert tokens.last().is(.end_of_file)
	}
}

fn retained_late_identifier() Token {
	tokens := Tokenizer.tokenize('ignored '.repeat(4096) + 'remembered', 'utf-8')
	return tokens[tokens.len - 2]
}

fn test_identifier_source_span_outlives_its_tokenizer_and_other_tokens() {
	token := retained_late_identifier()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		assert token.ident() == 'remembered'
		assert token.original_source_text() == 'remembered'
	}
}

fn test_identifier_source_spans_keep_unicode_and_escape_decoding() {
	tokens := Tokenizer.tokenize('alpha_22-β 中文 foo\\62 ar \\0 end', 'utf-8')
	identifiers := tokens.filter(it.is(.ident))
	assert identifiers.map(it.ident()) == ['alpha_22-β', '中文', 'foobar', '�end']
	assert identifiers[2].original_source_text() == 'foo\\62 ar'
	assert identifiers[3].original_source_text() == '\\0 end'
}
