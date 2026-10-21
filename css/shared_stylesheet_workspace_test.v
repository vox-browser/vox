module css

import platform

fn test_shared_stylesheet_rule_recovery_retires_without_a_document_owner() {
	$if !prealloc { return }
	assert platform.current_retained_arena() == unsafe { nil }
	mut baseline := i64(0)
	for count in [1, 1, 8192] {
		mut parser := RuleSelectorParser.create(ParsingParams{}, '@media(width>1px){' + 'invalid garbage;'.repeat(count) + '}', 'utf-8')
		before := platform.thread_arena_usage().used
		sheet := parser.parse_as_css_stylesheet(none, none)
		growth := platform.thread_arena_usage().used - before
		assert sheet.rules.length() == 1
		if count == 1 { baseline = growth }
		else { assert growth < baseline + 128 * 1024, '${growth} retained versus ${baseline}' }
	}
}

fn test_shared_stylesheet_component_copy_survives_workspace_release_and_reuse() {
	assert platform.current_retained_arena() == unsafe { nil }
	text := '/*' + 'startup input '.repeat(400) + '*/β\\31{--x:f([tail],url("a b"));content:"中😀";width:calc(1px + 2%)}'
	expected := ParserTokenStream.from_source(text, 'utf-8').dump_string()
	values := stylesheet_components_from_source(text)
	for _ in 0 .. 4 {
		_ = stylesheet_components_from_source('a{color:red;background:url("other.svg")}'.repeat(200))
	}
	assert ParserTokenStream.from_values(values).dump_string() == expected
	for deferred in [false, true] {
		mut parser := RuleSelectorParser{token_stream:ParserTokenStream.from_values(values), defer_style_declarations:deferred}
		sheet := parser.parse_as_css_stylesheet('https://startup.test/style.css', none)
		assert sheet.rules.length() == 1
		style := sheet.rules.rules[0].style() or { panic('missing style') }
		assert style.get_property_value('--x') == 'f([tail],url("a b"))'
		assert style.get_property_value('content') == '"中😀"'
	}
}
