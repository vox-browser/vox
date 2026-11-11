module css

import dom

fn test_hyphenate_limit_properties_register_inherited_longhands() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	for name, property in {
		'hyphenate-limit-chars': PropertyID.hyphenate_limit_chars
		'hyphenate-limit-lines': PropertyID.hyphenate_limit_lines
	} {
		assert property_id_from_string(name) or { panic(name) } == property
		assert string_from_property_id(property) == name
		assert is_inherited_property(property)
		assert animation_type_from_longhand_property(property) == .by_computed_value
		assert is_animatable_property(property)
		assert property_requires_computation_with_cascaded_value(property)
		assert property in generated_expanded_longhands_for_shorthand(.all)
		assert generated_shorthands_for_longhand(property) == [PropertyID.all]
	}
	assert property_initial_value_string(.hyphenate_limit_chars) == 'auto'
	assert property_initial_value_string(.hyphenate_limit_lines) == 'no-limit'
	assert keyword_from_string('no-limit') or { panic('no-limit') } == .no_limit
	assert string_from_keyword(.no_limit) == 'no-limit'
}

fn test_hyphenate_limit_chars_parses_up_to_three_values_in_shortest_form() {
	valid := {
		'auto':            'auto'
		'auto auto':       'auto'
		'auto auto auto':  'auto'
		'5':               '5'
		'5 auto':          '5'
		'5 auto auto':     '5'
		'5 2':             '5 2'
		'5 2 2':           '5 2'
		'5 2 3':           '5 2 3'
		'auto 2':          'auto 2'
		'auto 2 2':        'auto 2'
		'auto 2 auto':     'auto 2 auto'
		'auto auto 2':     'auto auto 2'
		'-1 -1 -2':        '-1 -1 -2'
		'5 2 calc(3.1)':   '5 2 calc(3.1)'
	}
	for source, expected in valid {
		assert parse_css_value_logic(.hyphenate_limit_chars, source) or { panic(source) }.serialize(.normal) == expected, source
	}
	for source in ['', 'normal', '1 normal', 'none', '1 none', '1.2', '1 1.2', '1 2 1.2',
		'1 2 3 4', 'auto auto auto auto', '1px', '"1"', '1, 2'] {
		assert parse_css_value_logic(.hyphenate_limit_chars, source) == none, source
	}
}

fn test_hyphenate_limit_lines_parses_no_limit_or_a_non_negative_integer() {
	for source, expected in {
		'no-limit':    'no-limit'
		'NO-LIMIT':    'no-limit'
		'0':           '0'
		'4':           '4'
		'calc(2 + 2)': 'calc(4)'
	} {
		assert parse_css_value_logic(.hyphenate_limit_lines, source) or { panic(source) }.serialize(.normal) == expected, source
	}
	for source in ['', 'auto', 'none', '-1', '1.2', '1px', '"1"', 'no-limit 2', '1 2'] {
		assert parse_css_value_logic(.hyphenate_limit_lines, source) == none, source
	}
}

fn hyphenate_limit_computed(style string, property string) string {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut child := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root.set_attribute_value('style', style)
	_ = css_style_computer_for(document)
	document.update_style()
	own := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value(property)
	inherited := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value(property)
	document.finalize()
	assert own == inherited, '${style}: ${own} != ${inherited}'
	return own
}

fn test_hyphenate_limit_properties_compute_integers_and_inherit() {
	assert hyphenate_limit_computed('', 'hyphenate-limit-chars') == 'auto'
	assert hyphenate_limit_computed('', 'hyphenate-limit-lines') == 'no-limit'
	for source, expected in {
		'auto auto':     'auto'
		'5':             '5'
		'5 2':           '5 2'
		'5 2 3':         '5 2 3'
		'5 2 calc(3.1)': '5 2 3'
		'auto 2 auto':   'auto 2 auto'
	} {
		assert hyphenate_limit_computed('hyphenate-limit-chars:${source}', 'hyphenate-limit-chars') == expected, source
	}
	for source, expected in {
		'no-limit':    'no-limit'
		'0':           '0'
		'4':           '4'
		'calc(2 + 2)': '4'
		'calc(4.1)':   '4'
	} {
		assert hyphenate_limit_computed('hyphenate-limit-lines:${source}', 'hyphenate-limit-lines') == expected, source
	}
}

fn test_hyphenate_limit_keywords_and_integers_interpolate_discretely() {
	context := InterpolationCalculationContext.for_property(.hyphenate_limit_lines)
	no_limit := parse_css_value_logic(.hyphenate_limit_lines, 'no-limit') or { panic('no-limit') }
	four := parse_css_value_logic(.hyphenate_limit_lines, '4') or { panic('4') }
	assert (interpolate_style_value(context, no_limit, four, 0.3, .yes) or { panic('0.3') }).serialize(.normal) == 'no-limit'
	assert (interpolate_style_value(context, no_limit, four, 0.6, .yes) or { panic('0.6') }).serialize(.normal) == '4'
	chars := InterpolationCalculationContext.for_property(.hyphenate_limit_chars)
	auto := parse_css_value_logic(.hyphenate_limit_chars, 'auto') or { panic('auto') }
	ten := parse_css_value_logic(.hyphenate_limit_chars, '10') or { panic('10') }
	assert (interpolate_style_value(chars, auto, ten, 0.3, .yes) or { panic('0.3') }).serialize(.normal) == 'auto'
	assert (interpolate_style_value(chars, auto, ten, 0.6, .yes) or { panic('0.6') }).serialize(.normal) == '10'
}
