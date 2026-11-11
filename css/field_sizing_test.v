module css

import dom

fn test_field_sizing_registers_a_non_inherited_discrete_keyword_longhand() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	assert property_id_from_string('field-sizing') or { panic('field-sizing') } == .field_sizing
	assert string_from_property_id(.field_sizing) == 'field-sizing'
	assert !is_inherited_property(.field_sizing)
	assert property_initial_value_string(.field_sizing) == 'fixed'
	assert animation_type_from_longhand_property(.field_sizing) == .discrete
	assert is_animatable_property(.field_sizing)
	assert property_affects_layout(.field_sizing)
	assert PropertyID.field_sizing in generated_expanded_longhands_for_shorthand(.all)
	assert generated_shorthands_for_longhand(.field_sizing) == [PropertyID.all]
	for value in ['fixed', 'content'] {
		assert parse_css_value_logic(.field_sizing, value) or { panic(value) }.serialize(.normal) == value
		assert parse_css_value_logic(.field_sizing, value.to_upper()) or { panic(value) }.serialize(.normal) == value
	}
	for value in ['', 'none', 'legacy', 'auto', 'normal', 'normal auto', '100%', '10px',
		'fixed content', '"fixed"'] {
		assert parse_css_value_logic(.field_sizing, value) == none, value
	}
}

fn test_field_sizing_computes_the_keyword_without_inheriting_it() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut child := document.create_element_ns(dom.namespace_html_uri, 'textarea') or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root.set_attribute_value('style', 'field-sizing:content')
	_ = css_style_computer_for(document)
	document.update_style()
	assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(root, none)).get_property_value('field-sizing') == 'content'
	assert CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(child, none)).get_property_value('field-sizing') == 'fixed'
	document.finalize()
}
