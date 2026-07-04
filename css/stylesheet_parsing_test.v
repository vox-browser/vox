module css

// Stylesheet rule parsing. This exercises the fix to the rule-consumption path: the port's token
// stream normalizes {}-blocks into SimpleBlock component values, so consume_a_qualified_rule /
// consume_an_at_rule / consume_a_block must detect a curly-block component value (not a raw
// <{-token>). Before the fix parse_css_stylesheet_contents_with_parser returned zero rules.

fn parse_rules(css_text string) []&CSSRule {
	return parse_css_stylesheet_contents_with_parser(css_text, map[string]bool{})
}

fn decl_of(rule &CSSRule) &CSSStyleProperties {
	return rule.style() or { panic('rule has no style declaration') }
}

fn test_single_style_rule() {
	rules := parse_rules('p { color: red; font-size: 14px }')
	assert rules.len == 1
	assert rules[0].selector_text() == 'p'
	d := decl_of(rules[0])
	assert d.length() == 2
	assert d.get_property_value('color') == 'red'
	assert d.get_property_value('font-size') == '14px'
}

fn test_multiple_rules_and_selector_groups() {
	rules := parse_rules('h1 { margin: 0 } .a, .b > i { color: blue }')
	assert rules.len == 2
	assert rules[0].selector_text() == 'h1'
	assert rules[1].selector_text() == '.a, .b > i'
	assert decl_of(rules[1]).get_property_value('color') == 'blue'
}

fn test_empty_rule_and_whitespace() {
	rules := parse_rules('   .empty {}   div{color:green}  ')
	assert rules.len == 2
	assert rules[0].selector_text() == '.empty'
	assert decl_of(rules[0]).length() == 0
	assert rules[1].selector_text() == 'div'
	assert decl_of(rules[1]).get_property_value('color') == 'green'
}

fn test_stylesheet_object() {
	sheet := parse_css_stylesheet_with_parser('a { color: red } b { color: blue }', ?string(none))
	assert sheet.css_rules().length() == 2
}
