module css

import platform

fn assert_borrowed_spelling_components_equal(left ComponentValue, right ComponentValue) {
	assert left.attr_tainted == right.attr_tainted
	if left.is_token() {
		assert right.is_token() && left.token() == right.token()
	} else if left.is_block() {
		assert right.is_block()
		one := left.block()
		two := right.block()
		assert one.token == two.token && one.end_token == two.end_token
		assert one.value.len == two.value.len
		for index, child in one.value { assert_borrowed_spelling_components_equal(child, two.value[index]) }
	} else {
		assert left.is_function() && right.is_function()
		one := left.function()
		two := right.function()
		assert one.name == two.name && one.name_token == two.name_token && one.end_token == two.end_token
		assert one.value.len == two.value.len
		for index, child in one.value { assert_borrowed_spelling_components_equal(child, two.value[index]) }
	}
}

fn test_private_token_spans_preserve_decoding_positions_and_owned_exports() {
	source := '/*comment*/ .card { --size: calc(1rem + var(--gap, 2px)); content: "β😀"; width: 1/**/px; }'
	mut arena := platform.new_arena('borrowed spelling input')
	entry := arena.enter()
	borrowed := ParserTokenStream.from_transient_source(source.clone(), 'utf-8')
	arena.leave(entry)
	expected := ParserTokenStream.from_source(source, 'utf-8')
	assert borrowed.values.len == expected.values.len
	for index, value in borrowed.values {
		assert_borrowed_spelling_components_equal(value, expected.values[index])
	}
	owned := own_stylesheet_components(borrowed.values)
	arena.release()
	gc_collect()
	assert ParserTokenStream.from_values(owned).dump_string() == expected.dump_string()
	for value in owned {
		if value.is_token() {
			spelling := value.token().original_source_text()
			assert unsafe { spelling.str[spelling.len] } == 0
		}
	}
}

fn test_borrowed_stylesheet_preludes_and_spelling_keep_cssom_values_after_conversion() {
	for deferred in [false, true] {
		source := '@media (width > 1px) { .card, .other:hover { --size: calc(1rem + var(--gap, 2px)); content:"β😀"; width:1/**/px; } }'
		mut legacy := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
		legacy.defer_style_declarations = deferred
		expected := legacy.parse_as_css_stylesheet('https://spelling.test/style.css', none)
		actual := parse_css_stylesheet_in_workspace(ParsingParams{}, source,
			'https://spelling.test/style.css', none, deferred)
		gc_collect()
		assert actual.rules.length() == expected.rules.length()
		assert actual.rules.rules[0].css_text() == expected.rules.rules[0].css_text()
	}
}
