module css

// Ladybird 2ed16cb44ace: ! can be the first value token, leaving a valid
// empty custom property after its priority annotation is removed.
fn test_empty_important_custom_properties_keep_their_value_and_priority() {
	for source in ['--x:!important', '--x: !important', '--x:\t! \n IMPORTANT \t',
		'--x:/**/!/**/important/**/', r'--x:!\69mportant'] {
		rules := parse_css_stylesheet_contents_with_parser('a { ${source} }', map[string]bool{})
		assert rules.len == 1, source
		declaration := rules[0].style() or { panic('missing style') }
		assert declaration.custom_property_count() == 1, source
		assert declaration.get_property_value('--x') == '', source
		assert declaration.get_property_priority('--x') == 'important', source
	}
}
