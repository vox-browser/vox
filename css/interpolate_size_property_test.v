module css

import dom

fn test_interpolate_size_parses_its_keywords_case_insensitively() {
	allow := parse_css_value_logic(.interpolate_size, 'allow-keywords') or { panic('allow-keywords') }
	assert allow.to_keyword() == .allow_keywords
	numeric := parse_css_value_logic(.interpolate_size, 'NUMERIC-ONLY') or { panic('numeric-only') }
	assert numeric.to_keyword() == .numeric_only
	assert parse_css_value_logic(.interpolate_size, 'auto') == none
	assert parse_css_value_logic(.interpolate_size, 'allow-keywords numeric-only') == none
	assert property_id_from_string('interpolate-size')? == .interpolate_size
	assert property_initial_value_string(.interpolate_size) == 'numeric-only'
	assert is_inherited_property(.interpolate_size)
	assert !is_animatable_property(.interpolate_size)
	assert !property_affects_layout(.interpolate_size)
}

fn test_interpolate_size_inherits_into_descendants() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'interpolate-size: allow-keywords')
	mut child := document.create_element('div') or { panic(err) }
	mut sibling := document.create_element('div') or { panic(err) }
	sibling.set_attribute_value('style', 'interpolate-size: numeric-only')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root_node.append_child(sibling.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	child_style := up_to_date_computed_properties_for_element(child)
	assert (child_style.property(.interpolate_size, .yes) or { panic('child') }).css_text == 'allow-keywords'
	sibling_style := up_to_date_computed_properties_for_element(sibling)
	assert (sibling_style.property(.interpolate_size, .yes) or { panic('sibling') }).css_text == 'numeric-only'
}
