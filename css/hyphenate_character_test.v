module css

import dom

fn test_hyphenate_character_registers_an_inherited_discrete_longhand() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	assert property_id_from_string('hyphenate-character') or { panic('hyphenate-character') } == .hyphenate_character
	assert string_from_property_id(.hyphenate_character) == 'hyphenate-character'
	assert is_inherited_property(.hyphenate_character)
	assert property_initial_value_string(.hyphenate_character) == 'auto'
	assert animation_type_from_longhand_property(.hyphenate_character) == .discrete
	assert is_animatable_property(.hyphenate_character)
	assert property_accepts_type(.hyphenate_character, .string)
	assert PropertyID.hyphenate_character in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.hyphenate_character) == [PropertyID.all]
}

fn test_hyphenate_character_parses_auto_or_a_single_string() {
	valid := {
		'auto':      'auto'
		'AUTO':      'auto'
		'"="':       '"="'
		'"/-/"':     '"/-/"'
		'"\\1400"':  '"᐀"'
		'""':        '""'
		"'-'":       '"-"'
	}
	for source, expected in valid {
		assert parse_css_value_logic(.hyphenate_character, source) or { panic(source) }.serialize(.normal) == expected, source
	}
	for source in ['', 'normal', 'manual', 'none', 'auto auto', '"-" "="', '1400', 'U+1400',
		'auto "-"', '"-" auto'] {
		assert parse_css_value_logic(.hyphenate_character, source) == none, source
	}
}

fn test_hyphenate_character_computes_as_specified_and_inherits() {
	for source, expected in {
		'auto':     'auto'
		'"="':      '"="'
		'"\\1400"': '"᐀"'
		'""':       '""'
	} {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_browsing_context(&dom.BrowsingContext{})
		mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
		mut node := document.as_node()
		node.append_child(root.as_node()) or { panic(err) }
		mut child := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
		mut root_node := root.as_node()
		root_node.append_child(child.as_node()) or { panic(err) }
		root.set_attribute_value('style', 'hyphenate-character:${source}')
		_ = css_style_computer_for(document)
		document.update_style()
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('hyphenate-character') == expected, source
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value('hyphenate-character') == expected, source
		document.finalize()
	}
}
