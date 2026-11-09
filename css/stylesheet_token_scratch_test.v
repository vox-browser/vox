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

fn assert_owned_stylesheet_text(text string, source &platform.Arena) {
	if text.len == 0 { return }
	assert !source.contains(text.str)
	assert unsafe { text.str[text.len] } == 0
}

fn assert_owned_stylesheet_token_text(token Token, source &platform.Arena) {
	assert_owned_stylesheet_text(token.value, source)
	assert_owned_stylesheet_text(token.original_source_text_, source)
}

fn assert_owned_stylesheet_component_text(component ComponentValue, source &platform.Arena) {
	if component.value is &Token {
		assert_owned_stylesheet_token_text(*component.value, source)
	} else if component.value is &Function {
		assert_owned_stylesheet_text(component.value.name, source)
		assert_owned_stylesheet_token_text(component.value.name_token, source)
		assert_owned_stylesheet_token_text(component.value.end_token, source)
		for child in component.value.value { assert_owned_stylesheet_component_text(child, source) }
	} else if component.value is &SimpleBlock {
		assert_owned_stylesheet_token_text(component.value.token, source)
		assert_owned_stylesheet_token_text(component.value.end_token, source)
		for child in component.value.value { assert_owned_stylesheet_component_text(child, source) }
	} else if component.value is RawComponentValue {
		assert_owned_stylesheet_text(component.value.text, source)
	}
}

fn test_owned_stylesheet_components_preserve_shared_spellings_and_nested_ownership() {
	text := 'outer(plain [foo\\62 ar \\0\\1] inner(β))'
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	mut source := platform.new_arena('shared stylesheet spelling source')
	source_entry := source.enter()
	mut values := ParserTokenStream.from_transient_source(text.clone(), 'utf-8').values
	values[0].set_attr_tainted()
	values << ComponentValue{value: RawComponentValue{text: 'retained raw text'.clone()}, attr_tainted: true}
	values << ComponentValue{value: GuaranteedInvalidValue{}, attr_tainted: true}
	source.leave(source_entry)
	mut target := platform.new_arena('shared stylesheet spelling target')
	target_entry := target.enter()
	owned := own_stylesheet_components(values)
	target.leave(target_entry)
	for value in owned { assert_owned_stylesheet_component_text(value, source) }
	source.release()
	assert ParserTokenStream.from_values(owned[..1]).dump_string() == expected
	assert owned[0].attr_tainted
	outer := owned[0].function()
	assert outer.name == 'outer'
	assert outer.name.str == outer.name_token.value.str
	plain := outer.value[0].token()
	assert plain.value == 'plain'
	assert plain.value.str == plain.original_source_text_.str
	block := outer.value[2].block()
	escaped := block.value[0].token()
	assert escaped.value == 'foobar'
	assert escaped.original_source_text_ == 'foo\\62 ar'
	equal_length_escape := block.value[2].token()
	assert equal_length_escape.value == '�\x01'
	assert equal_length_escape.original_source_text_ == '\\0\\1'
	assert equal_length_escape.value.len == equal_length_escape.original_source_text_.len
	assert equal_length_escape.value.str != equal_length_escape.original_source_text_.str
	inner := outer.value[4].function()
	assert inner.name == 'inner'
	assert inner.name.str == inner.name_token.value.str
	assert inner.value[0].is_ident('β')
	assert owned[1].original_source_text() == 'retained raw text' && owned[1].attr_tainted
	assert owned[2].is_guaranteed_invalid() && owned[2].attr_tainted
	target.release()
}

fn test_stylesheet_spelling_sharing_requires_identical_spans() {
	spelling := 'long-name'.clone()
	prefix := unsafe { tos(spelling.str, 4) }
	assert prefix.str == spelling.str
	owned := own_stylesheet_token(Token.create_ident(prefix, spelling))
	assert owned.value == 'long'
	assert owned.original_source_text_ == 'long-name'
	assert owned.value.str != owned.original_source_text_.str
	assert unsafe { owned.value.str[owned.value.len] } == 0
	for name in [prefix, 'different'.clone()] {
		function := ComponentValue.from_function(Function{
			name: name
			name_token: Token.create_function(spelling, spelling + '(')
		})
		copied := own_stylesheet_component(&function).function()
		assert copied.name == name
		assert copied.name_token.value == spelling
		assert copied.name.str != copied.name_token.value.str
		assert unsafe { copied.name.str[copied.name.len] } == 0
	}
}

fn test_transient_stylesheet_spellings_are_exported_for_every_cache_admission_path() {
	text := '/*' + 'candidate padding '.repeat(300)
		+ '*/β\\31{--value:outer(plain [foo\\62 ar \\0\\1] inner(β));content:"中😀";width:calc(1px + 2%)}'
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	for mode in 0 .. 4 {
		// Exercise disabled caching, node-budget rejection, source-budget bypass,
		// and a published candidate. Each retains owned input after scratch and
		// caller-source retirement, regardless of the selected result owner.
		mut cache := &StylesheetSyntaxCache{
			max_entries: if mode == 0 { 0 } else { 16 }
			max_nodes: if mode == 1 { 1 } else { 131_072 }
			max_source_bytes: if mode == 2 { 4096 } else { 1_048_576 }
		}
		mut source := platform.new_arena('stylesheet cache input source')
		source_entry := source.enter()
		input := text.clone()
		source.leave(source_entry)
		mut target := platform.new_arena('stylesheet cache result owner')
		target_entry := target.enter()
		values := cache.parse(input)
		target.leave(target_entry)
		assert cache.entries.len == if mode == 3 { 1 } else { 0 }
		for value in values { assert_owned_stylesheet_component_text(value, source) }
		source.release()
		assert ParserTokenStream.from_values(values).dump_string() == expected
		if mode == 3 {
			assert cache.parse(text).data == values.data
			cache.release_unused()
			assert ParserTokenStream.from_values(values).dump_string() == expected
		}
		target.release()
	}
}
