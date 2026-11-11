module css

import dom

fn test_text_emphasis_style_registers_an_inherited_discrete_longhand() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	assert property_id_from_string('text-emphasis-style') or { panic('text-emphasis-style') } == .text_emphasis_style
	assert string_from_property_id(.text_emphasis_style) == 'text-emphasis-style'
	assert is_inherited_property(.text_emphasis_style)
	assert property_initial_value_string(.text_emphasis_style) == 'none'
	assert animation_type_from_longhand_property(.text_emphasis_style) == .discrete
	assert is_animatable_property(.text_emphasis_style)
	assert property_requires_computation_with_cascaded_value(.text_emphasis_style)
	assert PropertyID.text_emphasis_style in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.text_emphasis_style) == [PropertyID.all]
	for keyword in ['filled', 'open', 'dot', 'double-circle', 'triangle', 'sesame'] {
		assert string_from_keyword(keyword_from_string(keyword) or { panic(keyword) }) == keyword
	}
}

fn test_text_emphasis_style_parses_fill_shape_or_string() {
	valid := {
		'none':               'none'
		'dot':                'dot'
		'filled':             'filled'
		'open':               'open'
		'filled circle':      'filled circle'
		'circle filled':      'filled circle'
		'open sesame':        'open sesame'
		'TRIANGLE OPEN':      'open triangle'
		'double-circle':      'double-circle'
		'"*"':                '"*"'
		"'\\25B2'":           '"▲"'
	}
	for source, expected in valid {
		value := parse_css_value_logic(.text_emphasis_style, source) or { panic(source) }
		assert value.serialize(.normal) == expected, source
	}
	for source in ['', 'none dot', 'filled open', 'dot circle', 'filled dot open', '"*" dot',
		'dot "*"', 'auto', '1', 'square'] {
		assert parse_css_value_logic(.text_emphasis_style, source) == none, source
	}
}

fn text_emphasis_style_computed(writing_mode string, source string) string {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut child := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root.set_attribute_value('style', 'writing-mode:${writing_mode};text-emphasis-style:${source}')
	_ = css_style_computer_for(document)
	document.update_style()
	own := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('text-emphasis-style')
	inherited := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value('text-emphasis-style')
	document.finalize()
	assert own == inherited, '${source}: ${own} != ${inherited}'
	return own
}

fn test_text_emphasis_style_computes_the_shape_for_the_writing_mode() {
	horizontal := {
		'none':          'none'
		'dot':           'dot'
		'filled circle': 'circle'
		'filled':        'circle'
		'open':          'open circle'
		'double-circle': 'double-circle'
		'triangle':      'triangle'
		'open sesame':   'open sesame'
		'"*"':           '"*"'
	}
	for source, expected in horizontal {
		assert text_emphasis_style_computed('horizontal-tb', source) == expected, source
	}
	vertical := {
		'none':          'none'
		'dot':           'dot'
		'filled circle': 'circle'
		'filled':        'sesame'
		'open':          'open sesame'
		'double-circle': 'double-circle'
		'triangle':      'triangle'
		'open sesame':   'open sesame'
		'"*"':           '"*"'
	}
	for source, expected in vertical {
		assert text_emphasis_style_computed('vertical-lr', source) == expected, source
	}
}
