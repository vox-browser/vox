module css

// Ladybird 89d063684587: a type or universal selector must be the first
// simple selector of its compound, in both DOM queries and style rules.
fn test_universal_selector_must_start_its_compound() {
	for source in ['div*', '.a*', '#id*', '[id]*', ':hover*', '**', '*div', '*|a*'] {
		assert parse_query_selector_list(source) == none, source
	}
	for source in ['*', '*.a', '*#id', '*[id]', '*:hover', '.a *', 'div > *', '*|*.a'] {
		assert parse_query_selector_list(source) != none, source
	}
}

fn test_stylesheets_discard_rules_with_misplaced_universal_selectors() {
	rules := parse_css_stylesheet_contents_with_parser('div* { color:red }
		.a* { color:green } div, .bad* { color:blue } *.good { color:purple }',
		map[string]bool{})
	assert rules.len == 1
	assert rules[0].selector_text() == '.good'
	style := rules[0].style() or { panic('missing surviving style') }
	assert style.get_property_value('color') == 'purple'
}
