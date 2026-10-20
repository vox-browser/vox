module css

import dom
import platform

fn test_rule_syntax_retirement_preserves_deferred_eager_and_nested_rules() {
	source := '.filler{}'.repeat(80) + '@namespace s url("urn:test"); @layer base {a {--x: f([a;b],var(--other));color:red!important; & > b{width:2px} @media(width>1px){height:3px}}} @supports(display:grid){p{display:grid}} @container c (width>1px){div{color:blue}} @font-face{font-family:test;src:url(test.woff)} @keyframes k{from{opacity:0}to{opacity:1}} @property --num{syntax:"<number>";initial-value:1;inherits:false} @page{margin:2px;@top-left{content:"test"}}'
	for deferred in [false, true] {
		mut expected_parser := RuleSelectorParser.create(ParsingParams{}, source, 'utf-8')
		expected_parser.defer_style_declarations = deferred
		expected := expected_parser.parse_as_css_stylesheet('https://rules.test/style.css', none)
		mut document := dom.Document.create(dom.URL{value:'https://rules.test/'})
		document.enable_native_storage()
		mut scope := document.enter_native_storage()
		mut parser := RuleSelectorParser.create_for_stylesheet(ParsingParams{}, source)
		parser.defer_style_declarations = deferred
		actual := parser.parse_as_css_stylesheet('https://rules.test/style.css', none)
		assert parser.token_stream.index == expected_parser.token_stream.index
		assert !parser.raw_rules_transient
		assert actual.rules.length() == expected.rules.length()
		// Access only after the syntax arena has been released. This also forces
		// deferred property parsing after the final raw declaration reader retired.
		for index, rule in actual.rules.rules {
			assert rule.css_text() == expected.rules.rules[index].css_text()
		}
		scope.finish()
		document.release_native_storage()
	}
}

fn test_declaration_spans_preserve_shared_input_and_important_boundaries() {
	text := 'a{color:red !  important  ;--custom:calc(1px + var(--x)) !important; background:url("a b");width:3px }'
	values := ParserTokenStream.from_source(text, 'utf-8').values
	original := ParserTokenStream.from_values(values).dump_string()
	for deferred in [true, false, true] {
		mut parser := RuleSelectorParser{token_stream:ParserTokenStream.from_values(values), defer_style_declarations:deferred}
		sheet := parser.parse_as_css_stylesheet(none, none)
		declaration := sheet.rules.rules[0].style()?
		assert declaration.get_property_value('color') == 'red'
		assert declaration.get_property_priority('color') == 'important'
		assert declaration.get_property_value('--custom').contains('calc(1px + var(--x))')
		assert declaration.get_property_priority('--custom') == 'important'
		assert declaration.get_property_value('width') == '3px'
		assert declaration.get_property_value('background-image').contains('a b')
		assert ParserTokenStream.from_values(values).dump_string() == original
	}
}

fn test_declaration_spans_keep_recovery_and_nested_values() {
	mut parser := RuleSelectorParser.create(ParsingParams{}, 'a{broken;--x:f([a;b],{c;d});width:2px;bad: ! nope; height: 4px}', 'utf-8')
	sheet := parser.parse_as_css_stylesheet(none, none)
	style := sheet.rules.rules[0].style()?
	assert style.get_property_value('width') == '2px'
	assert style.get_property_value('height') == '4px'
	assert style.get_property_value('--x') == 'f([a;b],{c;d})'
}

fn test_long_declarations_do_not_allocate_another_component_vector() {
	$if prealloc {
		mut parser := RuleSelectorParser.create(ParsingParams{rule_context:[.style]}, 'background:' + 'none '.repeat(2048), 'utf-8')
		mut input := parser.token_stream
		mut scratch := platform.new_arena('declaration span check')
		entry := scratch.enter()
		declaration := parser.consume_a_declaration(mut input, .no, .no) or { panic('missing declaration') }
		scratch.leave(entry)
		assert declaration.value.len == 4095
		assert scratch.usage().used < 64 * 1024
		scratch.release()
		assert declaration.value[0].is_ident('none')
		assert declaration.value.last().is_ident('none')
	}
}

fn test_large_single_media_block_retires_discarded_rule_recovery() {
	mut document := dom.Document.create(dom.URL{value:'https://rule-recovery.test/'})
	document.enable_native_storage()
	mut baseline := i64(0)
	for count in [1, 1, 4096] {
		mut parser := RuleSelectorParser.create(ParsingParams{}, '@media(width>1px){' + 'invalid garbage;'.repeat(count) + '}', 'utf-8')
		mut scope := document.enter_native_storage()
		mut before := i64(0)
		$if prealloc { before = document.native_storage().arena.usage().used }
		sheet := parser.parse_as_css_stylesheet(none, none)
		assert sheet.rules.length() == 1
		$if prealloc {
			growth := document.native_storage().arena.usage().used - before
			if count == 1 { baseline = growth }
			else { assert growth < baseline + 128 * 1024, '${growth} bytes retained versus ${baseline} for an empty block' }
		}
		scope.finish()
	}
	document.release_native_storage()
}
