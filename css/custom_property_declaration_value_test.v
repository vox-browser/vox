module css

fn custom_property_declaration_for_test(css_text string) &CSSStyleProperties {
	rules := parse_css_stylesheet_contents_with_parser(css_text, map[string]bool{})
	if rules.len != 1 {
		panic('expected one style rule')
	}
	return rules[0].style() or { panic('missing style declaration') }
}

fn test_custom_property_declarations_reject_invalid_top_level_tokens() {
	declaration := custom_property_declaration_for_test('a { --valid: whee; --bang: whee!; --close: ); }')
	assert declaration.get_property_value('--valid') == 'whee'
	assert declaration.get_property_value('--bang') == ''
	assert declaration.get_property_value('--close') == ''
}

fn test_cssom_custom_property_write_rejects_invalid_declaration_value() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('--theme', 'green', '') or { panic('${err}') }
	assert declaration.get_property_value('--theme') == 'green'
	declaration.set_property('--theme', 'whee!', '') or { panic('${err}') }
	assert declaration.get_property_value('--theme') == 'green'
}

fn test_custom_property_declarations_validate_nested_contents() {
	declaration := custom_property_declaration_for_test('a {
		--valid: (;!);
		--bad-square: (]);
		--bad-paren: [)];
		--bad-curly: (});
	}')
	assert declaration.get_property_value('--valid') == '(;!)'
	assert declaration.get_property_value('--bad-square') == ''
	assert declaration.get_property_value('--bad-paren') == ''
	assert declaration.get_property_value('--bad-curly') == ''
}
