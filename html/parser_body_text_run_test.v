module html

import dom

fn body_text_tokens(input string, batched bool) ([]rune, []HTMLToken) {
	mut tokenizer := HTMLTokenizer.new(input)
	mut characters := []rune{}
	mut tokens := []HTMLToken{}
	for {
		if batched {
			if run := tokenizer.consume_parser_text_run(.no) {
				characters << run
				continue
			}
		}
		token := tokenizer.next_token() or { break }
		if token.is_character() { characters << token.code_point } else { tokens << token }
		if token.is_end_of_file() { break }
	}
	return characters, tokens
}

fn test_body_text_token_runs_preserve_references_normalization_and_following_positions() {
	for content in ['plain text'.repeat(1300), '日本語😀\ntext',
		'A\r\nB\rC\u0000D', 'one&amp;two&#x1f600;&#0;&notit;tail',
		'&am', '<!---->tail', '&x\r\nlast', '   \t\n\f'] {
		input := content + '<span data-after="yes">after</span>'
		expected_chars, expected_tokens := body_text_tokens(input, false)
		actual_chars, actual_tokens := body_text_tokens(input, true)
		assert actual_chars == expected_chars
		assert actual_tokens == expected_tokens
	}
}

fn test_body_text_runs_respect_stream_document_write_and_reference_boundaries() {
	mut tokenizer := HTMLTokenizer.create()
	tokenizer.append_to_input_stream('one&am')
	assert runes_to_string(tokenizer.consume_parser_text_run(.no)?) == 'one'
	assert tokenizer.consume_parser_text_run(.no) == none
	assert tokenizer.next_token() == none
	tokenizer.append_to_input_stream('p;two\r')
	assert tokenizer.next_token()?.code_point == `&`
	tokenizer.insertion_point = tokenizer.current_offset + 2
	assert runes_to_string(tokenizer.consume_parser_text_run(.yes)?) == 'tw'
	assert tokenizer.consume_parser_text_run(.yes) == none
	tokenizer.undefine_insertion_point()
	assert runes_to_string(tokenizer.consume_parser_text_run(.no)?) == 'o'
	assert tokenizer.next_token() == none
	tokenizer.append_to_input_stream('\nnext')
	assert tokenizer.next_token()?.code_point == `\n`
	assert runes_to_string(tokenizer.consume_parser_text_run(.no)?) == 'next'
	tokenizer.append_to_input_stream('blocked')
	tokenizer.set_blocked(true)
	assert tokenizer.consume_parser_text_run(.no) == none
}

// Compare complete trees against ordinary character-token dispatch.
fn body_text_run_dom(input string, batched bool) !(string, bool, int) {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parser := HTMLParser.create_with_scripting_mode(document, input, .inert)
	parser.resource_discovery_only = true
	mut runs := 0
	for {
		if batched && parser.insert_text_run_if_available(.no) { runs++; continue }
		mut token := parser.next_parser_token(.no) or { break }
		if parser.next_line_feed_can_be_ignored {
			parser.next_line_feed_can_be_ignored = false
			if token.is_character() && token.code_point == `\n` { continue }
		}
		if parser.should_process_using_html_rules(token) {
			parser.process_using_the_rules_for(parser.insertion_mode, mut token)
		} else {
			parser.process_using_the_rules_for_foreign_content(mut token)
		}
		if token.is_end_of_file() || parser.stop_parsing { break }
	}
	parser.flush_character_insertions()
	markup := document.as_node().serialize_fragment(.yes, .inner)!
	return markup, parser.frameset_ok, runs
}

fn test_body_text_runs_preserve_tree_in_cells_formatting_and_foreign_content() {
	for content in ['<p>ordinary 日本語😀 text&amp;tail\r\nmore</p>',
		'<table><caption>caption <b>bold</b> tail</caption><tr><td>cell <a href="/">link</a> tail</td></tr></table>',
		'<b><p>bold</b> reconstructed tail</p>after',
		'<table>fostered text<tr><td>cell</td></tr>tail</table>',
		'<template><p>template text</p></template>after',
		'<svg><text>foreign\u0000text</text><foreignObject><p>HTML text</p></foreignObject></svg>after',
		'<math><mtext>math <b>HTML</b> text</mtext></math>after',
		'<pre>\npreformatted text</pre><textarea>\ntextarea text</textarea>after',
		'   \t\n<frameset><frame></frameset>',
		'visible text<frameset><frame></frameset>',
		'<p>' + 'long text\n'.repeat(1300) + '</p>'] {
		input := '<!doctype html><html><head></head><body>' + content
		expected, expected_frameset, _ := body_text_run_dom(input, false)!
		actual, actual_frameset, runs := body_text_run_dom(input, true)!
		assert actual == expected
		assert actual_frameset == expected_frameset
		assert runs > 0
	}
}
