module css

fn test_system_font_keywords_retain_cssom_identity_and_expand_resolved_longhands() {
	for name in system_font_keywords {
		mut declaration := CSSStyleProperties{}
		declaration.set_property('font', name, '')!
		assert declaration.get_property_value('font') == name
		assert declaration.css_text() == 'font: ${name};'
		assert declaration.properties.len == cssom_expanded_longhands_for_shorthand(.font).len
		for property in declaration.properties {
			assert declaration.get_property_value(property.name) == '', property.name
			assert property.value != ''
		}
		declaration.set_property('font-size', '13px', '')!
		assert declaration.get_property_value('font-size') == '13px'
		assert declaration.get_property_value('font') == ''
		assert declaration.get_property_value('font-family') == ''
	}
	assert parse_css_value_logic(.font, 'caption serif') == none
	assert parse_css_value_logic(.font, 'menu 12px') == none
	assert parse_css_value_logic(.font, '16px caption') != none
}
