module css

fn test_validated_selector_graph_preserves_serialization_and_relative_combinators() {
	parsed := parse_selector_with_parser('div.card > a[href="/x"]:not(.hidden), svg|path', {
		'svg': true
	}) or { panic('valid selector rejected') }
	assert parsed.selectors.len == 2
	assert parsed.selectors[0].serialize() == 'div.card > a[href="/x"]:not(.hidden)'
	assert parsed.selectors[1].serialize() == 'svg|path'
	for text in ['.item', '> .item', '+ .item'] {
		selector := parser_parse_validated_selector(text, .relative, map[string]bool{}) or { panic('relative selector rejected') }
		assert selector.compound_selectors()[0].combinator == match text[0] {
			`>` { Combinator.immediate_child }
			`+` { Combinator.next_sibling }
			else { Combinator.descendant }
		}
	}
}

fn test_validated_selector_graph_keeps_syntax_and_nested_namespace_rejections() {
	for text in ['> .item', '.item >', '.item + ~ a', 'div:made-up', 'div::before::after'] {
		assert parse_selector_with_parser(text, map[string]bool{}) == none, text
	}
	assert parser_parse_validated_selector('div[title="x"', .standalone, map[string]bool{}) == none
	// CSS component normalization supplies the missing close bracket at EOF.
	assert parse_selector_with_parser('div[title="x"', map[string]bool{}) != none
	for text in ['svg|path', '[svg|href]', ':not(svg|path)', ':has(> svg|path)', '::slotted(svg|path)'] {
		assert parse_selector_with_parser(text, map[string]bool{}) == none, text
		assert parse_selector_with_parser(text, {
			'svg': true
		}) != none, text
	}
	mut parser := RuleSelectorParser.create(ParsingParams{}, '.valid, :made-up, .last', 'utf-8')
	forgiving := parser.parse_as_relative_selector(.forgiving) or { panic('forgiving list rejected') }
	assert forgiving.selectors.len == 3
}
