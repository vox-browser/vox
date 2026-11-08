module css

import dom

fn test_single_var_reuse_keeps_element_font_resolution_and_live_custom_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut parent := document.create_element('div')!
	parent.set_attribute_value('style', '--edge:2em;--alias:var(--edge);font-size:16px')
	mut first := document.create_element('span')!
	first.set_attribute_value('style', 'font-size:10px;width:var(--alias)')
	mut second := document.create_element('span')!
	second.set_attribute_value('style', 'font-size:20px;width:var(--alias)')
	mut node := parent.as_node()
	node.append_child(first.as_node())!
	node.append_child(second.as_node())!
	mut computer := css_style_computer_for(document)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	parent_style := computer.compute_style(dom.AbstractElement.new(parent, none))
	parent.set_computed_properties(none, computed_properties_to_dom(parent_style))
	one := computer.compute_style(dom.AbstractElement.new(first, none))
	two := computer.compute_style(dom.AbstractElement.new(second, none))
	assert one.length_percentage_to_px(.width, 0)? == 20
	assert two.length_percentage_to_px(.width, 0)? == 40
	assert first.style_uses_var_css_function() && second.style_uses_var_css_function()
	if !disable_simple_var_property_reuse {
		assert computer.simple_var_properties_ != unsafe { nil }
		assert computer.simple_var_properties_.entries.len > 0
	}
	parent.set_attribute_value('style', '--edge:3em;--alias:var(--edge);font-size:16px')
	updated_parent := computer.compute_style(dom.AbstractElement.new(parent, none))
	parent.set_computed_properties(none, computed_properties_to_dom(updated_parent))
	updated := computer.compute_style(dom.AbstractElement.new(second, none))
	assert updated.length_percentage_to_px(.width, 0)? == 60
}

fn test_single_var_reuse_leaves_missing_fallback_and_nested_grammars_on_full_path() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	element.set_attribute_value('style', '--edge:2px;--cycle:var(--cycle)')
	mut computer := css_style_computer_for(document)
	_ = computer.compute_style(dom.AbstractElement.new(element, none))
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	for source in ['var(--missing)', 'var(--missing, 3px)', 'calc(var(--edge) + 1px)', 'var(--cycle)'] {
		value := parse_css_value_logic(.width, source)?
		if value is UnresolvedStyleValue {
			assert reuse_simple_var_property(dom.AbstractElement.new(element, none), .width, value) == none
		} else { panic(source) }
	}
}
