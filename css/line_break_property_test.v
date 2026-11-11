module css

import dom

fn test_line_break_parses_its_keywords_case_insensitively() {
	for text, keyword in {
		'auto':     Keyword.auto
		'LOOSE':    .loose
		'normal':   .normal
		'Strict':   .strict
		'anywhere': .anywhere
	} {
		value := parse_css_value_logic(.line_break, text) or { panic(text) }
		assert value.to_keyword() == keyword, text
	}
	assert parse_css_value_logic(.line_break, 'none') == none
	assert parse_css_value_logic(.line_break, 'loose strict') == none
	assert property_id_from_string('line-break')? == .line_break
	assert string_from_property_id(.line_break) == 'line-break'
	assert property_initial_value_string(.line_break) == 'auto'
	assert is_inherited_property(.line_break)
	assert is_animatable_property(.line_break)
	assert property_affects_layout(.line_break)
	assert PropertyID.line_break in generated_longhands_for_shorthand(.all)
}

fn test_line_break_inherits_into_descendants() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'line-break: loose')
	mut child := document.create_element('div') or { panic(err) }
	mut sibling := document.create_element('div') or { panic(err) }
	sibling.set_attribute_value('style', 'line-break: strict')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(child.as_node()) or { panic(err) }
	root_node.append_child(sibling.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	assert up_to_date_computed_properties_for_element(child).line_break() == .loose
	assert up_to_date_computed_properties_for_element(sibling).line_break() == .strict
	assert up_to_date_computed_properties_for_element(root).line_break() == .loose
}

fn test_line_break_computes_to_auto_initially() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	mut root := document.create_element('html') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	style := up_to_date_computed_properties_for_element(root)
	assert style.line_break() == .auto
	assert (style.property(.line_break, .yes) or { panic('line-break') }).css_text == 'auto'
}
