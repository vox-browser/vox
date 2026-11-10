module css

import dom

fn test_text_emphasis_position_registers_an_inherited_discrete_longhand() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	assert property_id_from_string('text-emphasis-position') or { panic('text-emphasis-position') } == .text_emphasis_position
	assert string_from_property_id(.text_emphasis_position) == 'text-emphasis-position'
	assert is_inherited_property(.text_emphasis_position)
	assert property_initial_value_string(.text_emphasis_position) == 'auto'
	assert animation_type_from_longhand_property(.text_emphasis_position) == .discrete
	assert is_animatable_property(.text_emphasis_position)
	assert PropertyID.text_emphasis_position in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.text_emphasis_position) == [PropertyID.all]
	assert keyword_from_string('over') or { panic('over') } == .over
	assert string_from_keyword(.over) == 'over'
}

fn test_text_emphasis_position_omits_the_default_right_side() {
	valid := {
		'auto':       'auto'
		'over':       'over'
		'under':      'under'
		'over right': 'over'
		'right over': 'over'
		'right under': 'under'
		'over left':  'over left'
		'left over':  'over left'
		'under left': 'under left'
		'LEFT UNDER': 'under left'
	}
	for source, expected in valid {
		value := parse_css_value_logic(.text_emphasis_position, source) or { panic(source) }
		assert value.serialize(.normal) == expected, source
	}
	// A lone over/under keyword stays a keyword so Typed OM reifies it as one.
	lone := parse_css_value_logic(.text_emphasis_position, 'under right') or { panic('under') }
	assert lone is KeywordStyleValue
	for source in ['', 'auto auto', 'auto left', 'over auto', 'left over right', 'under right over',
		'left', 'right', 'over under', 'left right over', 'none', '"over"'] {
		assert parse_css_value_logic(.text_emphasis_position, source) == none, source
	}
}

fn test_text_emphasis_position_computes_and_inherits_the_canonical_value() {
	for source, expected in {
		'':            'auto'
		'auto':        'auto'
		'over right':  'over'
		'right under': 'under'
		'left over':   'over left'
		'under left':  'under left'
	} {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_browsing_context(&dom.BrowsingContext{})
		mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
		mut node := document.as_node()
		node.append_child(root.as_node()) or { panic(err) }
		mut child := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
		mut root_node := root.as_node()
		root_node.append_child(child.as_node()) or { panic(err) }
		if source != '' {
			root.set_attribute_value('style', 'text-emphasis-position:${source}')
		}
		_ = css_style_computer_for(document)
		document.update_style()
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('text-emphasis-position') == expected, source
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value('text-emphasis-position') == expected, source
		document.finalize()
	}
}
