module css

import dom

fn test_native_stylesheet_components_own_all_payloads_after_tokenizer_and_document_retirement() {
	text := '/*' + 'temporary tokenizer input '.repeat(300) + '*/\nβ\\31{--x:f([tail],url("a b"));content:"中😀";width:calc(1px + 2%)}'
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	mut document := dom.Document.create(dom.URL{value:'https://token-scratch.test/'})
	document.enable_native_storage()
	mut cache := &StylesheetSyntaxCache{}
	mut scope := document.enter_native_storage()
	values := cache.parse(text.clone())
	scope.finish()
	document.release_native_storage()
	assert ParserTokenStream.from_values(values).dump_string() == expected
	assert cache.parse(text).data == values.data
	assert cache.entries.len == 1
	for value in values { assert value.original_source_text().len > 0 }
}

fn test_native_tokenizer_scratch_preserves_eager_and_deferred_stylesheet_results() {
	text := '/*' + 'prefix'.repeat(1024) + '*/@media(width>1px){a{--x:calc(1px + var(--y));color:red!important;background:url("../image.png")}}'
	for deferred in [false, true] {
		mut document := dom.Document.create(dom.URL{value:'https://token-rules.test/'})
		document.enable_native_storage()
		mut expected_parser := RuleSelectorParser.create(ParsingParams{}, text, 'utf-8')
		expected_parser.defer_style_declarations = deferred
		expected := expected_parser.parse_as_css_stylesheet('https://token-rules.test/style.css', none)
		mut scope := document.enter_native_storage()
		mut parser := RuleSelectorParser.create_for_stylesheet(ParsingParams{}, text)
		parser.defer_style_declarations = deferred
		sheet := parser.parse_as_css_stylesheet('https://token-rules.test/style.css', none)
		for index, rule in sheet.css_rules().rules {
			assert rule.css_text() == expected.css_rules().rules[index].css_text()
		}
		scope.finish()
		document.release_native_storage()
	}
}
