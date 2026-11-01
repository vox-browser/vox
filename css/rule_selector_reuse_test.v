module css

import platform

fn test_relative_selector_adaptation_preserves_the_source_graph() {
	for source in ['.card > .child', ':is(.card,.other):has(> .flag)', '.card::before'] {
		original := selector_from_text(source)
		text := original.serialize()
		combinator := original.compound_selectors()[0].combinator
		adapted := original.relative_to(SimpleSelector{type_:.nesting})
		assert adapted.serialize() == '& ' + text
		assert original.serialize() == text
		assert original.compound_selectors()[0].combinator == combinator
	}
}

fn test_parser_reuses_owned_selector_graphs_without_sharing_cssom_rule_mutations() {
	mut arena := platform.new_arena('temporary stylesheet source')
	entry := arena.enter()
	source := '.card:has(> .flag){color:red}.card:has(> .flag){width:20px}'.clone()
	arena.leave(entry)
	sheet := parse_css_stylesheet_with_parser(source, none)
	arena.release()
	mut first := sheet.css_rules().rules[0]
	second := sheet.css_rules().rules[1]
	assert voidptr(first.selectors.selectors[0].data_) == voidptr(second.selectors.selectors[0].data_)
	assert first.selector_text() == second.selector_text()
	first.set_selector_text('.replacement')
	assert first.selector_text() == '.replacement'
	assert second.selector_text() == '.card:has(> .flag)'
	mut declaration := first.style() or { panic('missing declaration') }
	declaration.set_property('color', 'blue', '') or { panic(err) }
	assert second.style()?.get_property_value('width') == '20px'
	assert second.style()?.get_property_value('color') == ''
}

fn test_selector_reuse_keeps_validation_modes_namespace_changes_and_failures_separate() {
	mut parser := RuleSelectorParser{}
	assert parser.parse_memoized_rule_selector('> .child', .standalone) == none
	relative := parser.parse_memoized_rule_selector('> .child', .relative) or { panic('missing relative selector') }
	assert relative.compound_selectors()[0].combinator == .immediate_child
	assert parser.parse_memoized_rule_selector('> .child', .standalone) == none
	assert parser.parse_memoized_rule_selector('s|path', .standalone) == none
	parser.declared_namespaces['s'] = true
	assert parser.parse_memoized_rule_selector('s|path', .standalone) != none
	parser.declared_namespaces.clear()
	assert parser.parse_memoized_rule_selector('s|path', .standalone) == none
	for source in ['.card:is(.one, [data-x="x"]):has(> .flag)', ':nth-child(2n+1 of .card)',
		r'.\63 ard[data-x="a\\b"]', '& > .child'] {
		actual := parser.parse_memoized_rule_selector(source, .relative) or { panic(source) }
		expected := parser_parse_validated_selector(source, .relative, map[string]bool{}) or { panic(source) }
		assert actual.serialize() == expected.serialize()
		assert actual.specificity() == expected.specificity()
	}
}

fn test_rule_selector_memo_stays_bounded_and_keeps_existing_borrowers_live() {
	mut parser := RuleSelectorParser{}
	first := parser.parse_memoized_rule_selector('.first', .standalone) or { panic('missing selector') }
	for index in 0 .. maximum_reused_rule_selectors + 2 {
		_ = parser.parse_memoized_rule_selector('.item${index}', .standalone)
	}
	assert parser.parsed_rule_selectors.len == maximum_reused_rule_selectors
	assert parser.parsed_rule_selector_bytes <= maximum_reused_rule_selector_bytes
	assert first.serialize() == '.first'
	assert voidptr(first.data_) == voidptr((parser.parse_memoized_rule_selector('.first', .standalone) or { panic('missing retained selector') }).data_)
}
