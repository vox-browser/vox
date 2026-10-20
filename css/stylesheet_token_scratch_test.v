module css

import dom
import platform

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

fn test_owned_stylesheet_tokens_do_not_construct_unused_function_payloads() {
	$if prealloc {
		mut source := platform.new_arena('component copy source')
		source_entry := source.enter()
		values := ParserTokenStream.from_source('item '.repeat(4096), 'utf-8').values
		source.leave(source_entry)
		mut target := platform.new_arena('component copy target')
		target_entry := target.enter()
		owned := own_stylesheet_components(values)
		target.leave(target_entry)
		// A token leaf needs its component slot, Token payload, owned spelling
		// and allocator alignment. A default Function for every leaf exceeds
		// this bound even though it never becomes part of the result.
		assert target.usage().used < owned.len * (sizeof(ComponentValue) + sizeof(Token) + 64)
		source.release()
		assert owned.len == 8192
		assert owned[0].is_ident('item') && owned[8190].is_ident('item')
		target.release()
	}
}
