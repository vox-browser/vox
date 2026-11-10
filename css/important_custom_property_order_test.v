module css

// Ladybird db70c91e8668: parsing resolves duplicate custom declarations by
// importance first, then source order. CSSOM mutation is a separate operation.
fn test_custom_property_parsing_preserves_important_declarations() {
	for source in ['--x:red!important;--x:blue', '--x:blue;--x:red!important',
		'--x:blue!important;--x:red!important', '--x:red!important;--x:blue;--x:green'] {
		rules := parse_css_stylesheet_contents_with_parser('a { ${source} }', map[string]bool{})
		assert rules.len == 1, source
		declaration := rules[0].style() or { panic('missing style') }
		assert declaration.custom_property_count() == 1, source
		assert declaration.get_property_value('--x') == 'red', source
		assert declaration.get_property_priority('--x') == 'important', source
	}
}

fn test_custom_property_parsing_uses_last_normal_declaration() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_declarations_from_text('--x:blue;--x:red')
	assert declaration.custom_property_count() == 1
	assert declaration.get_property_value('--x') == 'red'
	assert declaration.get_property_priority('--x') == ''
}

fn test_cssom_set_property_replaces_important_custom_property() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_declarations_from_text('--x:red!important;--x:blue')
	assert declaration.get_property_value('--x') == 'red'
	assert declaration.get_property_priority('--x') == 'important'
	declaration.set_property('--x', 'green', '') or { panic(err) }
	assert declaration.get_property_value('--x') == 'green'
	assert declaration.get_property_priority('--x') == ''
	declaration.set_property('--x', 'purple', 'important') or { panic(err) }
	assert declaration.get_property_value('--x') == 'purple'
	assert declaration.get_property_priority('--x') == 'important'
}
