module css

import dom

fn test_text_align_last_registers_an_inherited_discrete_keyword_longhand() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	assert property_id_from_string('text-align-last') or { panic('text-align-last') } == .text_align_last
	assert string_from_property_id(.text_align_last) == 'text-align-last'
	assert is_inherited_property(.text_align_last)
	assert property_initial_value_string(.text_align_last) == 'auto'
	assert animation_type_from_longhand_property(.text_align_last) == .discrete
	assert is_animatable_property(.text_align_last)
	assert PropertyID.text_align_last in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.text_align_last) == [PropertyID.all]
	for value in ['auto', 'start', 'end', 'left', 'right', 'center', 'justify', 'match-parent'] {
		assert parse_css_value_logic(.text_align_last, value) or { panic(value) }.serialize(.normal) == value
		assert parse_css_value_logic(.text_align_last, value.to_upper()) or { panic(value) }.serialize(.normal) == value
	}
	for value in ['', 'none', 'auto start', 'end left', 'right center', 'justify match-parent',
		'justify-all', '"auto"', '1'] {
		assert parse_css_value_logic(.text_align_last, value) == none, value
	}
}

fn text_align_last_document(style string) (&dom.Document, &dom.Element, &dom.Element) {
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
	return document, root, child
}

fn test_text_align_last_computes_the_specified_keyword_and_inherits_it() {
	// css-text-3: the computed value is the specified keyword; WPT expects
	// match-parent to remain match-parent in getComputedStyle.
	for value in ['auto', 'start', 'end', 'left', 'right', 'center', 'justify', 'match-parent'] {
		mut document, root, child := text_align_last_document('text-align-last:${value}')
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('text-align-last') == value
		assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value('text-align-last') == value
		document.finalize()
	}
	mut document, root, _ := text_align_last_document('')
	assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('text-align-last') == 'auto'
	document.finalize()
}
