module html

import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn tokenizer_buffer_allocated_bytes() i64 {
	$if prealloc {
		return platform.thread_arena_usage().used
	}
	$if gcboehm ? {
		return i64(C.GC_get_total_bytes())
	}
	return 0
}

fn test_tokenizer_consumed_builder_reuses_storage_and_allocates_only_owned_output() {
	mut tokenizer := HTMLTokenizer.new('')
	values := '0123456789abcdef'.repeat(32).runes()
	tokenizer.current_builder << values
	first := tokenizer.consume_current_builder()
	storage := tokenizer.current_builder.data
	before := tokenizer_buffer_allocated_bytes()
	for _ in 0 .. 128 {
		tokenizer.current_builder << values
		assert tokenizer.consume_current_builder() == first
		assert tokenizer.current_builder.data == storage
	}
	allocated := tokenizer_buffer_allocated_bytes() - before
	// Boehm's size classes round this output up more than prealloc alignment.
	mut limit := 128 * (values.len + 256) + 1024
	$if prealloc {
		limit = 128 * (values.len + 32) + 1024
	}
	assert allocated <= limit, '${allocated} bytes'
	tokenizer.current_builder << 'replacement β😀'.runes()
	assert tokenizer.consume_current_builder() == 'replacement β😀'
	assert first == '0123456789abcdef'.repeat(32)
	assert unsafe { first.str[first.len] } == 0
}

fn reuse_tokenizer_tokens(input string, streamed bool) []HTMLToken {
	mut tokenizer := HTMLTokenizer.create()
	mut tokens := []HTMLToken{}
	if streamed {
		for code_point in input.runes() {
			tokenizer.feed(code_point.str())
			for {
				tokens << tokenizer.next_token() or { break }
			}
		}
	} else {
		tokenizer.feed(input)
	}
	tokenizer.close_input_stream()
	for {
		tokens << tokenizer.next_token() or { break }
	}
	return tokens
}

fn test_reused_tokenizer_buffers_preserve_emitted_names_attributes_comments_and_entities() {
	input := '<title>A&amp;β&#x1f600;&notit;</title><!--first--><div title="A&amp;β" data-note="&#65;">x</div>'
	continuous := reuse_tokenizer_tokens(input, false)
	streamed := reuse_tokenizer_tokens(input, true)
	assert streamed == continuous
	for _ in 0 .. 16 {
		later := reuse_tokenizer_tokens('<h1 a="longer value">&#x1f601;&NotEqualTilde;</h1><!--replacement-->', false)
		assert later.len > 4
	}
	gc_collect()
	assert streamed == continuous
	mut saw_comment := false
	mut saw_attributes := false
	for token in continuous {
		if token.is_comment() {
			assert token.comment_data == 'first'
			saw_comment = true
		}
		if token.is_start_tag() && token.tag_name == 'div' {
			assert token.attributes[0].local_name == 'title'
			assert token.attributes[0].value == 'A&β'
			assert token.attributes[1].value == 'A'
			saw_attributes = true
		}
	}
	assert saw_comment && saw_attributes
}
