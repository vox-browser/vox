module html

import dom

fn test_html_processing_instruction_targets_data_and_comment_fallback() {
	for markup, expected in {
		'<?something>': ['something', '']
		'<?hey   there?>': ['hey', 'there']
		'<?hey?there>': ['hey', '?there']
		'<?A_B-2\tvalue ?>': ['a_b-2', 'value ']
		'<?something ?\t   ??>': ['something', '?\t   ?']
		'<?target 日本語 &amp; <text>': ['target', '日本語 &amp; <text']
	} {
		mut document := parse_document('<!doctype html><body>${markup}')
		defer { document.finalize() }
		node := document.body()?.as_node().first_child()?
		pi := node.as_processing_instruction() or { panic(markup) }
		assert pi.target() == expected[0], markup
		assert pi.data() == expected[1], markup
	}
	for target in ['xml', 'XML-stylesheet', '1bad', '-bad', 'a$b', 'namespace:name', 'x.y', 'a<b', '🚀'] {
		mut document := parse_document('<!doctype html><body><?${target}>')
		defer { document.finalize() }
		node := document.body()?.as_node().first_child()?
		assert node.is_comment(), target
		assert unsafe { &dom.CharacterData(node) }.data() == '?${target}'
	}
	for markup in ['<?', '<?start', '<?start?', '<?start ', '<?start data', '<?start ? ?'] {
		mut document := parse_document('<!doctype html><body>${markup}')
		defer { document.finalize() }
		assert document.body()?.as_node().children_as_vector().len == 0, markup
	}
}

fn test_html_processing_instructions_use_their_insertion_mode_location() {
	mut document := parse_document('<?before?><!doctype html><html><head><?head x?></head><body><table><?table x?><tr><td>x</td></tr></table><svg><?foreign x?></svg></body></html><?after?>')
	defer { document.finalize() }
	assert document.as_node().first_child()?.as_processing_instruction()?.target() == 'before'
	assert document.head()?.as_node().first_child()?.as_processing_instruction()?.target() == 'head'
	table := document.body()?.as_node().children_as_vector()[0]
	assert table.first_child()?.as_processing_instruction()?.target() == 'table'
	svg := document.body()?.as_node().children_as_vector()[1]
	assert svg.first_child()?.as_processing_instruction()?.target() == 'foreign'
	assert document.as_node().last_child()?.as_processing_instruction()?.target() == 'after'
}

fn test_html_processing_instruction_tokenization_survives_stream_boundaries() {
	for split in 0 .. '<?target data??>'.len + 1 {
		input := '<?target data??>'
		mut tokenizer := HTMLTokenizer.create()
		tokenizer.append_to_input_stream(input[..split])
		mut result := []HTMLToken{}
		for {
			token := tokenizer.next_token() or { break }
			result << token
		}
		tokenizer.append_to_input_stream(input[split..])
		tokenizer.close_input_stream()
		for {
			token := tokenizer.next_token() or { break }
			result << token
		}
		assert result.len == 2
		assert result[0].is_processing_instruction()
		assert result[0].processing_instruction_target == 'target'
		assert result[0].comment() == 'data?'
		assert result[1].is_end_of_file()
	}
}

fn test_html_processing_instruction_payload_outlives_native_tokenizer_storage() {
	mut document := dom.Document.create(dom.URL{value: 'https://pi.test/'})
	document.set_scripting_enabled_by_embedder(false)
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	mut parser := HTMLParser.create(document, '<!doctype html><body><?retained key="value"?>')
	parser.run()
	assert parser.tokenizer_storage == unsafe { nil }
	pi := document.body()?.as_node().first_child()?.as_processing_instruction()?
	assert pi.target() == 'retained'
	assert pi.data() == 'key="value"'
	document.finalize()
	scope.finish()
	document.release_native_storage()
}
